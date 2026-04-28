#!/bin/bash
# Script: 02_install_dependencies.sh
# Purpose: Check and install system dependencies for ML environment
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_command() { echo -e "${BLUE}[RUN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUDA_CACHE_DIR="/tmp/cuda-cache"
if ! mkdir -p "$CUDA_CACHE_DIR" 2>/dev/null; then
    print_warning "Could not create $CUDA_CACHE_DIR; falling back to /tmp"
    CUDA_CACHE_DIR="/tmp"
fi
CUDA_PACKAGE_DOWNLOADS=()
INSTALLED_CUDA_VERSIONS=()
INSTALLED_CUDA_VERSIONS_DISPLAY="None"
SUDO_PREFIX=""

# Detect the highest CUDA toolkit package stream available in the provided repositories
detect_latest_cuda_version() {
    local repo_list=("$@")
    local version_candidates=""

    if ! command -v curl &> /dev/null; then
        echo ""
        return 1
    fi

    for repo in "${repo_list[@]}"; do
        if [ -z "$repo" ]; then
            continue
        fi

        if [ "$OS_TYPE" = "ubuntu" ]; then
            local packages_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/Packages"
            version_candidates=$(curl -fsSL "$packages_url" 2>/dev/null | \
                grep -oP '^Package: cuda-toolkit-\K[0-9]+-[0-9]+$' | \
                tr '-' '.' | \
                sort -V | uniq)
        elif [ "$OS_TYPE" = "rhel" ]; then
            local primary_url
            primary_url=$(get_rhel_primary_url "$repo")
            if [ -z "$primary_url" ]; then
                continue
            fi
            version_candidates=$(curl -fsSL "$primary_url" 2>/dev/null | \
                gzip -dc 2>/dev/null | \
                grep -oP '<name>cuda-toolkit-\K[0-9]+-[0-9]+(?=</name>)' | \
                tr '-' '.' | \
                sort -V | uniq)
        fi

        if [ -n "$version_candidates" ]; then
            echo "$version_candidates" | tail -1
            return 0
        fi
    done

    echo ""
    return 1
}

get_rhel_primary_url() {
    local repo="$1"
    local repomd_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/repodata/repomd.xml"
    local primary_rel

    primary_rel=$(curl -fsSL "$repomd_url" 2>/dev/null | awk '
        BEGIN { RS="</data>" }
        /<data type="primary">/ {
            if (match($0, /location href="[^"]+"/)) {
                rel = substr($0, RSTART, RLENGTH)
                sub(/^.*href="/, "", rel)
                sub(/"$/, "", rel)
                print rel
                exit
            }
        }
    ')

    if [ -z "$primary_rel" ]; then
        echo ""
        return 1
    fi

    echo "https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/${primary_rel}"
    return 0
}

setup_ubuntu_cuda_repo() {
    local repo="$1"
    local packages_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/Packages"
    local keyring_filename
    local keyring_path
    local keyring_basename
    local keyring_file
    local keyring_url

    keyring_filename=$(curl -fsSL "$packages_url" 2>/dev/null | awk '
        $1 == "Package:" && $2 == "cuda-keyring" { pkgmatch=1; next }
        pkgmatch && $1 == "Filename:" { print $2; exit }
        pkgmatch && $0 == "" { pkgmatch=0 }
    ')

    if [ -z "$keyring_filename" ]; then
        print_warning "Could not determine cuda-keyring package for $repo"
        return 1
    fi

    keyring_path=${keyring_filename#./}
    keyring_basename=$(basename "$keyring_filename")
    keyring_file="${CUDA_CACHE_DIR}/${repo}-${keyring_basename}"
    keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/${keyring_path}"

    if [ ! -f "$keyring_file" ]; then
        print_info "Downloading CUDA repository keyring from NVIDIA..."
        if wget -O "$keyring_file" "$keyring_url"; then
            CUDA_PACKAGE_DOWNLOADS+=("$keyring_file")
        else
            print_warning "Failed to download $keyring_url"
            rm -f "$keyring_file"
            return 1
        fi
    else
        print_info "Using cached CUDA repository keyring: $keyring_file"
    fi

    print_info "Configuring NVIDIA CUDA APT repository for $repo..."
    if ! ${SUDO_PREFIX}dpkg -i "$keyring_file"; then
        print_warning "Failed to install CUDA repository keyring from $keyring_file"
        return 1
    fi

    print_info "Updating package index before CUDA installation..."
    if ! $PKG_UPDATE_CMD; then
        print_warning "Package index update failed after enabling NVIDIA CUDA repository"
        return 1
    fi

    return 0
}

resolve_ubuntu_driver_package() {
    local cuda_stream="$1"

    if ! command -v apt-cache &> /dev/null; then
        echo ""
        return 1
    fi

    local driver_branch=""
    if [ -n "$cuda_stream" ]; then
        local runtime_package="cuda-runtime-$(echo "$cuda_stream" | sed 's/\./-/g')"
        driver_branch=$(apt-cache depends "$runtime_package" 2>/dev/null | awk '
            $1 == "Depends:" {
                if ($2 == "libnvidia-compute") {
                    print "generic"
                    exit
                }
                if ($2 ~ /^libnvidia-compute-[0-9]+$/) {
                    sub(/^libnvidia-compute-/, "", $2)
                    print $2
                    exit
                }
            }
        ')
    fi

    local open_package
    for open_package in "nvidia-open" "nvidia-driver-open"; do
        local open_candidate
        open_candidate=$(apt-cache policy "$open_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -n "$open_candidate" ] && [ "$open_candidate" != "(none)" ]; then
            echo "$open_package"
            return 0
        fi
    done

    if [ -n "$driver_branch" ] && [ "$driver_branch" != "generic" ]; then
        local versioned_open_driver_package="nvidia-driver-${driver_branch}-open"
        local versioned_open_driver_candidate
        versioned_open_driver_candidate=$(apt-cache policy "$versioned_open_driver_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -n "$versioned_open_driver_candidate" ] && [ "$versioned_open_driver_candidate" != "(none)" ]; then
            echo "$versioned_open_driver_package"
            return 0
        fi
    fi

    print_warning "Open NVIDIA driver packages were not found in APT metadata; falling back to proprietary packages."

    if [ -n "$driver_branch" ] && [ "$driver_branch" != "generic" ]; then
        local versioned_cuda_driver_package="cuda-drivers-${driver_branch}"
        local versioned_cuda_driver_candidate
        versioned_cuda_driver_candidate=$(apt-cache policy "$versioned_cuda_driver_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -n "$versioned_cuda_driver_candidate" ] && [ "$versioned_cuda_driver_candidate" != "(none)" ]; then
            echo "$versioned_cuda_driver_package"
            return 0
        fi

        local versioned_nvidia_driver_package="nvidia-driver-${driver_branch}"
        local versioned_nvidia_driver_candidate
        versioned_nvidia_driver_candidate=$(apt-cache policy "$versioned_nvidia_driver_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -n "$versioned_nvidia_driver_candidate" ] && [ "$versioned_nvidia_driver_candidate" != "(none)" ]; then
            echo "$versioned_nvidia_driver_package"
            return 0
        fi
    fi

    local fallback_package
    for fallback_package in "cuda-drivers" "nvidia-driver"; do
        local fallback_candidate
        fallback_candidate=$(apt-cache policy "$fallback_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -n "$fallback_candidate" ] && [ "$fallback_candidate" != "(none)" ]; then
            echo "$fallback_package"
            return 0
        fi
    done

    echo ""
    return 1
}

resolve_rhel_driver_package() {
    local cuda_stream="$1"

    if [ -z "$cuda_stream" ]; then
        echo "nvidia-open"
        return 0
    fi

    local runtime_package="cuda-runtime-$(echo "$cuda_stream" | sed 's/\./-/g')"
    local version_major
    version_major=$(echo "$OS_VERSION_ID" | cut -d. -f1)
    version_major=${version_major:-9}

    local repo_candidates=("rhel${version_major}")
    if [ "$version_major" -gt 8 ]; then
        repo_candidates+=("rhel8")
    fi

    local repo
    for repo in "${repo_candidates[@]}"; do
        local primary_url
        primary_url=$(get_rhel_primary_url "$repo")
        if [ -z "$primary_url" ]; then
            continue
        fi

        local required_driver_version
        required_driver_version=$(curl -fsSL "$primary_url" 2>/dev/null | gzip -dc 2>/dev/null | awk -v pkg="$runtime_package" '
            BEGIN { RS="</package>" }
            $0 ~ "<name>" pkg "</name>" {
                if (match($0, /name="nvidia-driver-cuda"[^>]*ver="[^"]+"/)) {
                    dep = substr($0, RSTART, RLENGTH)
                    sub(/^.*ver="/, "", dep)
                    sub(/".*$/, "", dep)
                    print dep
                    exit
                }
            }
        ')

        if [ -z "$required_driver_version" ]; then
            continue
        fi

        local candidate_lines
        candidate_lines=$(curl -fsSL "$primary_url" 2>/dev/null | gzip -dc 2>/dev/null | awk -v pkg="nvidia-open" '
            BEGIN { RS="</package>" }
            $0 ~ "<name>" pkg "</name>" {
                version = ""
                release = ""
                location = ""
                if (match($0, /<version [^>]*ver="[^"]+"/)) {
                    tmp = substr($0, RSTART, RLENGTH)
                    sub(/^.*ver="/, "", tmp)
                    sub(/".*$/, "", tmp)
                    version = tmp
                }
                if (match($0, /<version [^>]*rel="[^"]+"/)) {
                    tmp = substr($0, RSTART, RLENGTH)
                    sub(/^.*rel="/, "", tmp)
                    sub(/".*$/, "", tmp)
                    release = tmp
                }
                if (match($0, /<location href="[^"]+"/)) {
                    tmp = substr($0, RSTART, RLENGTH)
                    sub(/^.*href="/, "", tmp)
                    sub(/".*$/, "", tmp)
                    location = tmp
                }
                if (version != "" && location != "") {
                    if (release != "") {
                        version = version "-" release
                    }
                    print version "\t" location
                }
            }
        ')

        local selected_line=""
        local candidate_version
        local candidate_path
        while IFS=$'\t' read -r candidate_version candidate_path; do
            if [ -z "$candidate_version" ] || [ -z "$candidate_path" ]; then
                continue
            fi

            if [ "$(printf "%s\n%s\n" "$required_driver_version" "$candidate_version" | sort -V | head -1)" = "$required_driver_version" ]; then
                selected_line=$(printf "%s\t%s\n%s" "$candidate_version" "$candidate_path" "$selected_line")
            fi
        done <<< "$candidate_lines"

        if [ -z "$selected_line" ]; then
            continue
        fi

        local selected_driver_path
        selected_driver_path=$(printf "%s" "$selected_line" | sort -V -k1,1 | tail -1 | cut -f2)
        if [ -z "$selected_driver_path" ]; then
            continue
        fi

        local driver_rpm_basename
        driver_rpm_basename=$(basename "$selected_driver_path")
        local driver_rpm_file="${CUDA_CACHE_DIR}/${driver_rpm_basename}"
        local driver_rpm_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/${selected_driver_path}"

        if [ ! -f "$driver_rpm_file" ]; then
            print_info "Downloading matching NVIDIA open driver package from NVIDIA repository..."
            if wget -O "$driver_rpm_file" "$driver_rpm_url"; then
                CUDA_PACKAGE_DOWNLOADS+=("$driver_rpm_file")
            else
                print_warning "Failed to download $driver_rpm_url"
                rm -f "$driver_rpm_file"
                continue
            fi
        else
            print_info "Using cached NVIDIA driver package: $driver_rpm_file"
        fi

        echo "$driver_rpm_file"
        return 0
    done

    echo "nvidia-open"
    return 0
}

has_nvidia_pci_devices() {
    if command -v lspci &> /dev/null && lspci 2>/dev/null | grep -qi 'NVIDIA'; then
        return 0
    fi

    return 1
}

has_nvidia_kernel_driver() {
    if command -v lsmod &> /dev/null && lsmod 2>/dev/null | grep -q '^nvidia'; then
        return 0
    fi

    if [ -e /proc/driver/nvidia/version ] || [ -e /sys/module/nvidia/version ]; then
        return 0
    fi

    return 1
}

ensure_nvidia_driver_build_prereqs() {
    if [ "$OS_TYPE" = "ubuntu" ]; then
        local headers_pkg="linux-headers-$(uname -r)"
        local headers_candidate
        if dpkg -s "$headers_pkg" &> /dev/null; then
            print_info "  ✓ Kernel headers already installed: $headers_pkg"
            return 0
        fi

        headers_candidate=$(apt-cache policy "$headers_pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
        if [ -z "$headers_candidate" ] || [ "$headers_candidate" = "(none)" ]; then
            print_warning "Could not find $headers_pkg in APT metadata."
            print_warning "DKMS may fail without matching kernel headers."
            return 0
        fi

        print_info "Installing kernel headers required for NVIDIA DKMS: $headers_pkg"
        if ! $PKG_INSTALL_CMD "$headers_pkg"; then
            print_warning "Failed to install $headers_pkg."
            return 1
        fi

        return 0
    fi

    if [ "$OS_TYPE" = "rhel" ]; then
        local kernel_devel_pkg="kernel-devel-$(uname -r)"
        local kernel_headers_pkg="kernel-headers-$(uname -r)"
        local missing_prereqs=()

        if ! rpm -q "$kernel_devel_pkg" &> /dev/null; then
            missing_prereqs+=("$kernel_devel_pkg")
        fi
        if ! rpm -q "$kernel_headers_pkg" &> /dev/null; then
            missing_prereqs+=("$kernel_headers_pkg")
        fi

        if [ ${#missing_prereqs[@]} -eq 0 ]; then
            print_info "  ✓ Kernel headers already installed for $(uname -r)"
            return 0
        fi

        print_info "Installing kernel development packages required for NVIDIA DKMS: ${missing_prereqs[*]}"
        if ! $PKG_INSTALL_CMD "${missing_prereqs[@]}"; then
            print_warning "Failed to install kernel development prerequisites: ${missing_prereqs[*]}"
            return 1
        fi
    fi

    return 0
}

install_nvidia_driver_for_gpu_support() {
    local cuda_stream="$1"
    local driver_package=""
    local driver_package_display=""
    local driver_package_installed_version=""
    local driver_package_candidate_version=""
    local driver_package_needs_update=false
    local driver_install_reason=""
    local driver_ready=false
    local kernel_driver_loaded=false
    local kernel_driver_was_loaded=false

    if ! command -v nvcc &> /dev/null; then
        return 0
    fi

    if ! has_nvidia_pci_devices; then
        print_info "No NVIDIA GPU detected via PCI enumeration; skipping driver installation."
        return 0
    fi

    if command -v nvidia-smi &> /dev/null && nvidia-smi >/dev/null 2>&1; then
        driver_ready=true
    fi

    if has_nvidia_kernel_driver; then
        kernel_driver_loaded=true
        kernel_driver_was_loaded=true
    fi

    case "$OS_TYPE" in
        ubuntu)
            driver_package=$(resolve_ubuntu_driver_package "$cuda_stream")
            ;;
        rhel)
            driver_package=$(resolve_rhel_driver_package "$cuda_stream")
            ;;
    esac

    if [ -z "$driver_package" ]; then
        print_warning "Could not resolve an NVIDIA driver package automatically."
        print_warning "Install the full NVIDIA driver stack manually before using CUDA workloads."
        return 0
    fi

    driver_package_display="$driver_package"
    if [ -f "$driver_package" ]; then
        driver_package_display=$(basename "$driver_package")
    fi

    case "$OS_TYPE" in
        ubuntu)
            if command -v dpkg-query &> /dev/null; then
                driver_package_installed_version=$(dpkg-query -W -f='${Status} ${Version}\n' "$driver_package" 2>/dev/null | awk '
                    $1 == "install" && $2 == "ok" && $3 == "installed" {
                        print $4
                        exit
                    }
                ')
            fi

            if command -v apt-cache &> /dev/null; then
                driver_package_candidate_version=$(apt-cache policy "$driver_package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
            fi

            if [ -z "$driver_package_installed_version" ]; then
                driver_package_needs_update=true
                driver_install_reason="required driver package is not installed"
            elif [ -n "$driver_package_candidate_version" ] && [ "$driver_package_candidate_version" != "(none)" ] && [ "$driver_package_candidate_version" != "$driver_package_installed_version" ]; then
                driver_package_needs_update=true
                driver_install_reason="newer candidate $driver_package_candidate_version is available (installed: $driver_package_installed_version)"
            fi
            ;;
        rhel)
            if command -v rpm &> /dev/null; then
                if [ -f "$driver_package" ]; then
                    local rpm_name=""
                    local rpm_version=""
                    rpm_name=$(rpm -qp --qf '%{NAME}\n' "$driver_package" 2>/dev/null)
                    rpm_version=$(rpm -qp --qf '%{VERSION}-%{RELEASE}\n' "$driver_package" 2>/dev/null)
                    if [ -n "$rpm_name" ]; then
                        driver_package_installed_version=$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' "$rpm_name" 2>/dev/null | head -1)
                    fi
                    if [ -z "$driver_package_installed_version" ]; then
                        driver_package_needs_update=true
                        driver_install_reason="required driver package is not installed"
                    elif [ -n "$rpm_version" ] && [ "$driver_package_installed_version" != "$rpm_version" ]; then
                        driver_package_needs_update=true
                        driver_install_reason="newer candidate $rpm_version is available (installed: $driver_package_installed_version)"
                    fi
                elif ! rpm -q "$driver_package" &> /dev/null; then
                    driver_package_needs_update=true
                    driver_install_reason="required driver package is not installed"
                fi
            fi
            ;;
    esac

    if [ "$driver_package_needs_update" = true ]; then
        local install_driver="y"
        if [ "$AUTO_YES" = true ]; then
            print_info "Automatic mode enabled (-y): installing/upgrading $driver_package_display"
        else
            read -p "Install or upgrade $driver_package_display ($driver_install_reason)? (y/n): " install_driver
        fi

        if [[ ! "$install_driver" =~ ^[Yy]$ ]]; then
            print_warning "Skipped NVIDIA driver installation/upgrade. CUDA apps may not work until the driver is installed."
            return 0
        fi

        if ! ensure_nvidia_driver_build_prereqs; then
            INSTALL_SUCCESS=false
            return 0
        fi

        print_info "Installing/upgrading NVIDIA driver package: $driver_package_display"
        if ! $PKG_INSTALL_CMD "$driver_package"; then
            print_warning "Failed to install $driver_package_display."
            INSTALL_SUCCESS=false
            return 0
        fi
    elif [ "$driver_ready" = true ]; then
        print_info "NVIDIA driver package is already active and up to date: $driver_package_display"
        return 0
    else
        if [ "$kernel_driver_loaded" = true ]; then
            print_warning "NVIDIA kernel driver appears to be loaded, but nvidia-smi is not ready."
        else
            print_warning "NVIDIA GPU detected, but the NVIDIA kernel driver is not loaded."
            print_info "CUDA packages do not install the running kernel driver by themselves."
        fi
        print_info "Desired NVIDIA driver package is already installed: $driver_package_display"
    fi

    if command -v modprobe &> /dev/null; then
        print_info "Attempting to load NVIDIA kernel modules..."
        ${SUDO_PREFIX}modprobe nvidia >/dev/null 2>&1 || true
        ${SUDO_PREFIX}modprobe nvidia_uvm >/dev/null 2>&1 || true
    fi

    if command -v nvidia-smi &> /dev/null && nvidia-smi >/dev/null 2>&1; then
        if [ "$driver_package_needs_update" = true ] && [ "$kernel_driver_was_loaded" = true ]; then
            print_warning "NVIDIA driver packages were upgraded while a kernel driver was already loaded."
            print_warning "A reboot is recommended before relying on the upgraded NVIDIA driver."
        else
            print_info "✓ NVIDIA driver is active and responding to nvidia-smi"
        fi
        return 0
    fi

    if has_nvidia_kernel_driver; then
        if [ "$driver_package_needs_update" = true ]; then
            print_warning "NVIDIA driver packages were installed or upgraded, but nvidia-smi is still not ready."
        else
            print_warning "NVIDIA driver packages are installed, but nvidia-smi is still not ready."
        fi
    else
        if [ "$driver_package_needs_update" = true ]; then
            print_warning "NVIDIA driver packages were installed or upgraded, but the kernel module is still not loaded."
        else
            print_warning "NVIDIA kernel driver is still not loaded."
        fi
    fi
    print_warning "A reboot may be required before the NVIDIA driver becomes active."
    return 0
}

collect_installed_cuda_versions() {
    INSTALLED_CUDA_VERSIONS=()
    local packages=()

    if [ "$OS_TYPE" = "ubuntu" ]; then
        if command -v dpkg &> /dev/null; then
            mapfile -t packages < <(dpkg -l 'cuda' 'cuda-[0-9]*' 'cuda-toolkit*' 2>/dev/null | awk '/^ii/ {print $2}')
        fi
    elif [ "$OS_TYPE" = "rhel" ]; then
        if command -v rpm &> /dev/null; then
            mapfile -t packages < <(rpm -qa 'cuda' 'cuda-[0-9]*' 'cuda-toolkit*' 2>/dev/null)
        fi
    fi

    for pkg in "${packages[@]}"; do
        if [[ $pkg =~ ^cuda-([0-9]+(-[0-9]+){1,3})$ ]]; then
            local version_suffix=${pkg#cuda-}
            version_suffix=${version_suffix%%.*}
            if [[ $version_suffix =~ ^[0-9]+(-[0-9]+){1,3}$ ]]; then
                local version=${version_suffix//-/.}
                INSTALLED_CUDA_VERSIONS+=("$version")
            fi
        elif [[ $pkg =~ ^cuda-toolkit- ]]; then
            local version_suffix=${pkg#cuda-toolkit-}
            version_suffix=${version_suffix%%.*}
            if [[ $version_suffix =~ ^[0-9]+(-[0-9]+){1,3}$ ]]; then
                local version=${version_suffix//-/.}
                INSTALLED_CUDA_VERSIONS+=("$version")
            fi
        elif [[ $pkg == cuda || $pkg == cuda-toolkit ]]; then
            if [ -n "$CURRENT_CUDA_VERSION_NORMALIZED" ]; then
                INSTALLED_CUDA_VERSIONS+=("$CURRENT_CUDA_VERSION_NORMALIZED")
            fi
        fi
    done

    if [ ${#INSTALLED_CUDA_VERSIONS[@]} -gt 0 ]; then
        mapfile -t INSTALLED_CUDA_VERSIONS < <(printf "%s
" "${INSTALLED_CUDA_VERSIONS[@]}" | awk '!seen[$0]++' | sort -V)
        INSTALLED_CUDA_VERSIONS_DISPLAY=$(printf "%s" "${INSTALLED_CUDA_VERSIONS[0]}")
        for version in "${INSTALLED_CUDA_VERSIONS[@]:1}"; do
            INSTALLED_CUDA_VERSIONS_DISPLAY+=", $version"
        done
    else
        INSTALLED_CUDA_VERSIONS_DISPLAY="None"
    fi
}

# Track overall success
INSTALL_SUCCESS=true
CURRENT_CUDA_VERSION_NORMALIZED=""
# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi

# OS/package manager detection
OS_TYPE=""
PKG_INSTALL_CMD=""
PKG_UPDATE_CMD=""
PKG_QUERY_CMD=""
PKG_CLEAN_CMD=""
OS_ID=""
OS_NAME=""
OS_VERSION_ID=""

detect_os_package_manager() {
    if [ ! -f /etc/os-release ]; then
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="$ID"
    OS_NAME="$NAME"
    OS_VERSION_ID="$VERSION_ID"
    local version_major
    version_major=$(echo "$VERSION_ID" | cut -d. -f1)

    SUDO_PREFIX="sudo "
    if [ "$(id -u)" -eq 0 ]; then
        SUDO_PREFIX=""
    fi

    if [ "$ID" = "ubuntu" ]; then
        if [ "$version_major" -lt 22 ]; then
            return 1
        fi
        OS_TYPE="ubuntu"
        PKG_INSTALL_CMD="${SUDO_PREFIX}apt install -y"
        PKG_UPDATE_CMD="${SUDO_PREFIX}apt update"
        PKG_QUERY_CMD="dpkg -l"
        PKG_CLEAN_CMD="${SUDO_PREFIX}apt clean"
        return 0
    fi

    if [[ "$ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
        if [ "$version_major" -lt 9 ]; then
            return 1
        fi
        OS_TYPE="rhel"
        if command -v dnf &> /dev/null; then
            PKG_INSTALL_CMD="${SUDO_PREFIX}dnf install -y"
            PKG_UPDATE_CMD="${SUDO_PREFIX}dnf makecache"
            PKG_CLEAN_CMD="${SUDO_PREFIX}dnf clean all"
        else
            PKG_INSTALL_CMD="${SUDO_PREFIX}yum install -y"
            PKG_UPDATE_CMD="${SUDO_PREFIX}yum makecache"
            PKG_CLEAN_CMD="${SUDO_PREFIX}yum clean all"
        fi
        PKG_QUERY_CMD="rpm -qa"
        return 0
    fi

    return 1
}

print_info "Checking OS version..."
if ! detect_os_package_manager; then
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine OS version. /etc/os-release not found."
    elif [ "$OS_ID" = "ubuntu" ]; then
        print_error "This script requires Ubuntu 22.04 or newer. Detected: $OS_ID $OS_VERSION_ID"
    elif [[ "$OS_ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
        print_error "This script requires RHEL/Rocky/AlmaLinux 9 or newer. Detected: $OS_ID $OS_VERSION_ID"
    else
        print_error "Unsupported OS. This script supports Ubuntu 22.04+ and RHEL/Rocky/AlmaLinux 9+. Detected: $OS_ID $OS_VERSION_ID"
    fi
    exit 1
fi

if [ "$OS_TYPE" = "ubuntu" ]; then
    print_info "✓ Ubuntu $OS_VERSION_ID detected"
else
    print_info "✓ $OS_NAME $OS_VERSION_ID detected"
fi
echo ""
# Check disk space
print_info "Checking disk space..."
AVAILABLE_SPACE=$(df -BG /var | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 5 ]; then
    print_error "Low disk space: ${AVAILABLE_SPACE}GB available on /var"
    print_error "At least 5GB recommended for package installation"
    if [ -n "$PKG_CLEAN_CMD" ]; then
        print_info "Free up space with: $PKG_CLEAN_CMD"
    fi
    exit 1
else
    print_info "✓ Disk space: ${AVAILABLE_SPACE}GB available"
fi
echo ""
# System packages - define based on OS type
if [ "$OS_TYPE" = "ubuntu" ]; then
    SYSTEM_PACKAGES=(
        # Essential build tools
        "build-essential"
        "gcc"
        "g++"
        "make"
        "cmake"
        "pkg-config"

        # NUMA optimization
        "numactl"
        "libnuma-dev"
        
        # Essential Python dependencies
        "libssl-dev"
        "libffi-dev"
        "liblzma-dev"
        "libbz2-dev"
        "libreadline-dev"
        "libsqlite3-dev"
        "libncurses-dev"
        "zlib1g-dev"
    )
elif [ "$OS_TYPE" = "rhel" ]; then
    SYSTEM_PACKAGES=(
        # Essential build tools
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        "pkgconf-pkg-config"

        # NUMA optimization
        "numactl"
        "numactl-devel"
        
        # Essential Python dependencies
        "openssl-devel"
        "libffi-devel"
        "zlib-devel"
        "xz-devel"
        "bzip2-devel"
        "readline-devel"
        "ncurses-devel"
        "sqlite-devel"
    )
fi
# Check packages
print_info "Checking system dependencies..."
MISSING_PACKAGES=()
for pkg in "${SYSTEM_PACKAGES[@]}"; do
    if [ "$OS_TYPE" = "ubuntu" ]; then
        if dpkg -l 2>/dev/null | grep -q "^ii  $pkg"; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_PACKAGES+=($pkg)
        fi
    elif [ "$OS_TYPE" = "rhel" ]; then
        if rpm -qa | grep -q "^$pkg"; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_PACKAGES+=($pkg)
        fi
    fi
done
# Check CUDA driver and toolkit
echo ""
print_info "Checking CUDA driver and toolkit..."

# Check for NVIDIA driver and get supported CUDA version
DRIVER_CUDA_VERSION=""
if command -v nvidia-smi &> /dev/null; then
    # Extract CUDA version supported by driver from nvidia-smi output
    DRIVER_CUDA_VERSION=$(nvidia-smi | grep -oP 'CUDA Version:\s*\K[0-9]+\.[0-9]+' | head -1)
    if [ -n "$DRIVER_CUDA_VERSION" ]; then
        print_info "  ✓ NVIDIA driver detected - supports CUDA up to version $DRIVER_CUDA_VERSION"
    else
        print_warning "  ⚠ NVIDIA driver detected but couldn't determine CUDA version support"
    fi
else
    print_warning "  ⚠ No NVIDIA driver detected (nvidia-smi not found)"
    print_info "  Will default to CUDA 12.9 for modern NVIDIA GPU compatibility"
fi

# Check for CUDA toolkit (nvcc)
CUDA_MISSING=false
CUDA_VERSION_OK=false
if command -v nvcc &> /dev/null; then
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
    print_info "  ✓ CUDA toolkit (nvcc) - version $CUDA_VERSION"
    
    # Check if installed CUDA version needs upgrade to 12.9
    CUDA_VERSION_MAJOR=$(echo $CUDA_VERSION | cut -d. -f1 | sed 's/V//')
    CUDA_VERSION_MINOR=$(echo $CUDA_VERSION | cut -d. -f2)
    CUDA_VERSION_MINOR=${CUDA_VERSION_MINOR:-0}
    CURRENT_CUDA_VERSION_NORMALIZED="${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}"
    
    if [ "$CUDA_VERSION_MAJOR" -gt 12 ] || ([ "$CUDA_VERSION_MAJOR" -eq 12 ] && [ "$CUDA_VERSION_MINOR" -ge 9 ]); then
        CUDA_VERSION_OK=true
        print_info "  ✓ CUDA version $CUDA_VERSION meets the recommended baseline"
    else
        print_info "  CUDA version $CUDA_VERSION detected; upgrade options will be offered"
        CUDA_MISSING=true  # Treat as missing to trigger upgrade menu
    fi
else
    print_error "  ✗ CUDA toolkit (nvcc)"
    CUDA_MISSING=true
fi

collect_installed_cuda_versions

echo ""
# Report and install
SYSTEM_PACKAGES_MISSING_COUNT=${#MISSING_PACKAGES[@]}
if [ $SYSTEM_PACKAGES_MISSING_COUNT -gt 0 ]; then
    print_warning "Missing ${SYSTEM_PACKAGES_MISSING_COUNT} packages: ${MISSING_PACKAGES[*]}"
else
    print_info "All core system packages already installed."
fi

if command -v nvcc &> /dev/null; then
    print_info "CUDA toolkit detected - reinstall, upgrade, or downgrade options available."
else
    print_warning "CUDA toolkit (nvcc) not found - required for GPU-optimized packages"
    CUDA_MISSING=true
fi
echo ""

INSTALL_SYSTEM_PACKAGES="n"
if [ $SYSTEM_PACKAGES_MISSING_COUNT -gt 0 ]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_SYSTEM_PACKAGES="y"
    else
        read -p "Do you want to install missing packages? (y/n): " INSTALL_SYSTEM_PACKAGES
    fi
fi

if [[ "$INSTALL_SYSTEM_PACKAGES" =~ ^[Yy]$ ]]; then
    # Install system packages first
    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        print_info "Installing missing packages..."
        echo ""
        
        # Clean package cache first if low on space
        if [ "$AVAILABLE_SPACE" -lt 10 ]; then
            if [ "$AUTO_YES" = true ]; then
                CLEAN_CACHE="y"
            else
                print_warning "Low disk space (${AVAILABLE_SPACE}GB). Clean package cache to free space?"
                read -p "Clean package cache? (y/n): " CLEAN_CACHE
            fi
            
            if [[ "$CLEAN_CACHE" =~ ^[Yy]$ ]]; then
                print_info "Cleaning package cache to free space..."
                if [ -n "$PKG_CLEAN_CMD" ]; then
                    $PKG_CLEAN_CMD
                else
                    print_warning "No package cache clean command available for this OS"
                fi
            else
                print_warning "Proceeding without cleaning package cache - installation may fail if space runs out"
            fi
        fi
        
        # Update package lists
        if [ "$OS_TYPE" = "ubuntu" ]; then
            $PKG_UPDATE_CMD
        elif [ "$OS_TYPE" = "rhel" ]; then
            $PKG_UPDATE_CMD
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Package update failed - check your internet connection and disk space"
            INSTALL_SUCCESS=false
        else
            if [ -n "$PKG_INSTALL_CMD" ]; then
                $PKG_INSTALL_CMD ${MISSING_PACKAGES[*]}
            fi
            
            if [ $? -ne 0 ]; then
                print_error "Failed to install some packages"
                INSTALL_SUCCESS=false
            fi
        fi
    fi
    
    # Check and fix gcc/g++ version mismatch after package installation
    if [ "$INSTALL_SUCCESS" = true ]; then
        print_info "Checking gcc/g++ version compatibility..."
        
        # Get installed gcc version
        if command -v gcc &> /dev/null; then
            GCC_VERSION=$(gcc --version | head -1 | grep -oE '[0-9]+' | head -1)
            print_info "Detected gcc-$GCC_VERSION"
            
            # Check if matching g++ version exists
            if command -v g++-$GCC_VERSION &> /dev/null; then
                print_info "✓ g++-$GCC_VERSION already available"
            else
                if [ "$AUTO_YES" = true ]; then
                    INSTALL_GPP="y"
                else
                    read -p "Install g++-$GCC_VERSION to match gcc-$GCC_VERSION? (y/n): " INSTALL_GPP
                fi
                
                if [[ "$INSTALL_GPP" =~ ^[Yy]$ ]]; then
                    print_info "Installing g++-$GCC_VERSION to match gcc-$GCC_VERSION..."
                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        if $PKG_INSTALL_CMD g++-$GCC_VERSION; then
                            print_info "✓ g++-$GCC_VERSION installed"
                            
                            # Ask about setting as default
                            if [ "$AUTO_YES" = true ]; then
                                SET_DEFAULT="y"
                            else
                                read -p "Set g++-$GCC_VERSION as default g++ compiler? (y/n): " SET_DEFAULT
                            fi
                            
                            if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
                                if sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100; then
                                    print_info "✓ Set g++-$GCC_VERSION as default g++ compiler"
                                else
                                    print_warning "Could not set g++-$GCC_VERSION as default"
                                fi
                            else
                                print_info "Skipped setting g++-$GCC_VERSION as default"
                            fi
                        else
                            print_warning "Could not install g++-$GCC_VERSION - CUDA compilation may fail"
                        fi
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        # RHEL variants typically have matching gcc/g++ versions in the gcc-c++ package
                        print_info "✓ gcc-c++ package provides matching g++ version"
                    fi
                else
                    print_warning "Skipped g++-$GCC_VERSION installation - CUDA compilation may fail"
                fi
            fi
        fi
    fi
fi

if [ "$INSTALL_SUCCESS" != true ]; then
    print_error "❌ Installation had errors - check messages above"
    exit 1
fi

# Install/Upgrade CUDA toolkit
echo ""

            TARGET_CUDA_VERSION_DEFAULT="12.9"
            TARGET_CUDA_VERSION=""
            CUDA_INSTALL_REQUESTED=false

            CURRENT_CUDA_DISPLAY="None"
            if command -v nvcc &> /dev/null; then
                CURRENT_CUDA_DISPLAY="$CUDA_VERSION"
            fi

            if [ -n "$DRIVER_CUDA_VERSION" ]; then
                print_info "Driver reports CUDA compatibility up to version $DRIVER_CUDA_VERSION"
            else
                print_info "No NVIDIA driver version detected; proceeding without driver compatibility data"
            fi

            if [ "$OS_TYPE" = "ubuntu" ]; then
                VERSION_YEAR=$(echo $VERSION_ID | cut -d. -f1)
                VERSION_MONTH=$(echo $VERSION_ID | cut -d. -f2)
                CUDA_REPO_VERSIONS=("ubuntu${VERSION_YEAR}${VERSION_MONTH}")
                for year in $(seq $VERSION_YEAR -2 22); do
                    if [ $year -eq $VERSION_YEAR ]; then
                        for month in $(seq $VERSION_MONTH -2 4); do
                            [ $month -lt 10 ] && month="0$month"
                            CUDA_REPO_VERSIONS+=("ubuntu${year}${month}")
                        done
                    else
                        CUDA_REPO_VERSIONS+=("ubuntu${year}10")
                        CUDA_REPO_VERSIONS+=("ubuntu${year}04")
                    fi
                done
            elif [ "$OS_TYPE" = "rhel" ]; then
                CUDA_REPO_VERSIONS=("rhel9" "rhel8")
            else
                CUDA_REPO_VERSIONS=()
            fi

            if [ ${#CUDA_REPO_VERSIONS[@]} -gt 0 ]; then
                CUDA_REPO_VERSIONS=($(printf "%s\n" "${CUDA_REPO_VERSIONS[@]}" | awk '!seen[$0]++'))
                print_info "Will try CUDA repositories in order: ${CUDA_REPO_VERSIONS[*]}"
            fi

            LATEST_CUDA_VERSION=$(detect_latest_cuda_version "${CUDA_REPO_VERSIONS[@]}")
            if [ -z "$LATEST_CUDA_VERSION" ]; then
                print_warning "Unable to determine the latest CUDA version automatically; defaulting to $TARGET_CUDA_VERSION_DEFAULT."
                LATEST_CUDA_VERSION="$TARGET_CUDA_VERSION_DEFAULT"
            else
                print_info "Latest CUDA version detected from repositories: $LATEST_CUDA_VERSION"
            fi

            print_info "Installed CUDA versions detected: $INSTALLED_CUDA_VERSIONS_DISPLAY"
            print_info "Current CUDA version: $CURRENT_CUDA_DISPLAY"
            echo "Choose CUDA installation option:"
            echo "  1) Keep current version"
            echo "  2) Install latest version ($LATEST_CUDA_VERSION)"
            echo "  3) Install custom version"
            echo "  4) Skip CUDA installation"
            CUDA_SELECTION=""
            CUDA_SKIP_REASON=""
            read -p "Enter choice (1/2/3/4): " CUDA_CHOICE
            while [[ ! "$CUDA_CHOICE" =~ ^[1234]$ ]]; do
                read -p "Please enter 1, 2, 3, or 4: " CUDA_CHOICE
            done
            case $CUDA_CHOICE in
                1)
                    CUDA_SELECTION="keep"
                    CUDA_INSTALL_REQUESTED=false
                    if [ "$CURRENT_CUDA_DISPLAY" = "None" ]; then
                        print_warning "CUDA toolkit remains uninstalled. GPU-accelerated workflows will not be available."
                    else
                        print_info "Keeping existing CUDA toolkit ($CURRENT_CUDA_DISPLAY)."
                    fi
                    ;;
                2)
                    CUDA_SELECTION="latest"
                    CUDA_INSTALL_REQUESTED=true
                    TARGET_CUDA_VERSION="$LATEST_CUDA_VERSION"
                    ;;
                3)
                    CUDA_SELECTION="custom"
                    while true; do
                        read -p "Enter desired CUDA version (e.g. 13, 13.0, 13.0.1, or 13.0.2-1): " CUSTOM_VERSION
                        if [[ "$CUSTOM_VERSION" =~ ^[0-9]+$ || "$CUSTOM_VERSION" =~ ^[0-9]+\.[0-9]+$ || "$CUSTOM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$ ]]; then
                            if [[ "$CUSTOM_VERSION" =~ ^[0-9]+$ ]]; then
                                CUSTOM_VERSION="${CUSTOM_VERSION}.0"
                            fi
                            TARGET_CUDA_VERSION="$CUSTOM_VERSION"
                            CUDA_INSTALL_REQUESTED=true
                            break
                        else
                            print_error "Invalid version number. Use major, major.minor, major.minor.patch, or major.minor.patch-release (e.g. 13, 13.0, 13.0.1, or 13.0.2-1)."
                        fi
                    done
                    ;;
                4)
                    CUDA_SELECTION="skip"
                    CUDA_INSTALL_REQUESTED=false
                    CUDA_SKIP_REASON="user_skip"
                    print_info "Skipping CUDA toolkit installation per user selection (option 4)."
                    ;;
            esac

            TARGET_CUDA_VERSION_MAJOR=""
            TARGET_CUDA_VERSION_MINOR=""
            TARGET_CUDA_VERSION_NORMALIZED=""
            TARGET_CUDA_EXACT_VERSION=""
            if [ -n "$TARGET_CUDA_VERSION" ]; then
                TARGET_CUDA_VERSION_MAJOR=$(echo "$TARGET_CUDA_VERSION" | cut -d. -f1)
                TARGET_CUDA_VERSION_MINOR=$(echo "$TARGET_CUDA_VERSION" | cut -d. -f2)
                TARGET_CUDA_VERSION_MINOR=${TARGET_CUDA_VERSION_MINOR:-0}
                TARGET_CUDA_VERSION_NORMALIZED="${TARGET_CUDA_VERSION_MAJOR}.${TARGET_CUDA_VERSION_MINOR}"
                if [[ "$TARGET_CUDA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$ ]]; then
                    TARGET_CUDA_EXACT_VERSION="$TARGET_CUDA_VERSION"
                fi
            fi

            if [ "$CUDA_SELECTION" = "latest" ] && [ -n "$TARGET_CUDA_VERSION_NORMALIZED" ]; then
                LATEST_ALREADY_PRESENT=false
                for installed_version in "${INSTALLED_CUDA_VERSIONS[@]}"; do
                    if [ "$installed_version" = "$TARGET_CUDA_VERSION_NORMALIZED" ]; then
                        LATEST_ALREADY_PRESENT=true
                        break
                    fi
                done
                if [ "$LATEST_ALREADY_PRESENT" = true ]; then
                    print_info "Latest CUDA version $TARGET_CUDA_VERSION is already installed; no action needed."
                    CUDA_INSTALL_REQUESTED=false
                    CUDA_SKIP_REASON="already_up_to_date"
                    CUDA_MISSING=false
                fi
            fi

            if [ "$CUDA_INSTALL_REQUESTED" = true ]; then
                if [ -z "$TARGET_CUDA_VERSION" ]; then
                    TARGET_CUDA_VERSION="$TARGET_CUDA_VERSION_DEFAULT"
                    TARGET_CUDA_VERSION_MAJOR=$(echo "$TARGET_CUDA_VERSION" | cut -d. -f1)
                    TARGET_CUDA_VERSION_MINOR=$(echo "$TARGET_CUDA_VERSION" | cut -d. -f2)
                    TARGET_CUDA_EXACT_VERSION=""
                    TARGET_CUDA_VERSION_MINOR=${TARGET_CUDA_VERSION_MINOR:-0}
                    TARGET_CUDA_VERSION_NORMALIZED="${TARGET_CUDA_VERSION_MAJOR}.${TARGET_CUDA_VERSION_MINOR}"
                fi

                TARGET_CUDA_MAJOR=$TARGET_CUDA_VERSION_MAJOR
                TARGET_CUDA_MINOR=$TARGET_CUDA_VERSION_MINOR

                if [ -n "$DRIVER_CUDA_VERSION" ]; then
                    DRIVER_CUDA_MAJOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f1)
                    DRIVER_CUDA_MINOR=$(echo $DRIVER_CUDA_VERSION | cut -d. -f2)
                    if [ "$TARGET_CUDA_MAJOR" -gt "$DRIVER_CUDA_MAJOR" ] || { [ "$TARGET_CUDA_MAJOR" -eq "$DRIVER_CUDA_MAJOR" ] && [ "$TARGET_CUDA_MINOR" -gt "$DRIVER_CUDA_MINOR" ]; }; then
                        print_warning "Selected CUDA version $TARGET_CUDA_VERSION may exceed driver support ($DRIVER_CUDA_VERSION). Installation may fail unless the driver is updated."
                    else
                        print_info "Driver support check passed for CUDA $TARGET_CUDA_VERSION."
                    fi
                else
                    print_warning "Driver capabilities unknown; proceeding with CUDA $TARGET_CUDA_VERSION."
                fi

                CUDA_PKG_VERSION=$(echo "$TARGET_CUDA_VERSION_NORMALIZED" | sed 's/\./-/g')
                DNF_REFRESHED=false
                CUDA_INSTALLED=false
                for REPO_VERSION in "${CUDA_REPO_VERSIONS[@]}"; do
                    [ -z "$REPO_VERSION" ] && continue
                    print_info "Attempting CUDA installation from NVIDIA repository: $REPO_VERSION"

                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        PACKAGES_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/Packages"
                        PACKAGE_VERSION=$(curl -fsSL "$PACKAGES_URL" 2>/dev/null | awk -v pkg="cuda-toolkit-${CUDA_PKG_VERSION}" -v requested_version="$TARGET_CUDA_EXACT_VERSION" '
                            function matches_requested(version, requested, len, next_char) {
                                if (requested == "") {
                                    return 1
                                }
                                len = length(requested)
                                if (substr(version, 1, len) != requested) {
                                    return 0
                                }
                                next_char = substr(version, len + 1, 1)
                                return (next_char == "" || next_char !~ /[0-9]/)
                            }
                            $1 == "Package:" && $2 == pkg { pkgmatch=1; next }
                            pkgmatch && $1 == "Version:" {
                                if (matches_requested($2, requested_version)) {
                                    print $2
                                }
                            }
                            pkgmatch && $0 == "" { pkgmatch=0 }
                        ' | sort -V | tail -1)
                        if [ -z "$PACKAGE_VERSION" ]; then
                            if [ -n "$TARGET_CUDA_EXACT_VERSION" ]; then
                                print_warning "Could not determine package version for cuda-toolkit-${CUDA_PKG_VERSION} matching $TARGET_CUDA_EXACT_VERSION from $REPO_VERSION"
                            else
                                print_warning "Could not determine package version for cuda-toolkit-${CUDA_PKG_VERSION} from $REPO_VERSION"
                            fi
                            continue
                        fi

                        if ! setup_ubuntu_cuda_repo "$REPO_VERSION"; then
                            continue
                        fi

                        CUDA_APT_PACKAGE="cuda-toolkit-${CUDA_PKG_VERSION}"
                        CUDA_APT_PACKAGE_SPEC="$CUDA_APT_PACKAGE"
                        if [ -n "$TARGET_CUDA_EXACT_VERSION" ]; then
                            CUDA_APT_PACKAGE_SPEC="${CUDA_APT_PACKAGE}=${PACKAGE_VERSION}"
                            print_info "Resolved CUDA toolkit package version: $PACKAGE_VERSION"
                        else
                            print_info "Resolved CUDA toolkit package stream: ${CUDA_APT_PACKAGE} (latest matching package version: $PACKAGE_VERSION)"
                        fi

                        print_info "Installing CUDA toolkit package from NVIDIA repository..."
                        if [ -n "$TARGET_CUDA_EXACT_VERSION" ]; then
                            if ${SUDO_PREFIX}apt install -y --allow-downgrades "$CUDA_APT_PACKAGE_SPEC"; then
                                print_info "✓ CUDA $TARGET_CUDA_VERSION installed successfully"
                                CUDA_INSTALLED=true
                            else
                                print_warning "Failed to install CUDA toolkit package $CUDA_APT_PACKAGE_SPEC"
                            fi
                        elif $PKG_INSTALL_CMD "$CUDA_APT_PACKAGE_SPEC"; then
                            print_info "✓ CUDA $TARGET_CUDA_VERSION installed successfully"
                            CUDA_INSTALLED=true
                        else
                            print_warning "Failed to install CUDA toolkit package $CUDA_APT_PACKAGE_SPEC"
                        fi

                    elif [ "$OS_TYPE" = "rhel" ]; then
                        PRIMARY_URL=$(get_rhel_primary_url "$REPO_VERSION")
                        if [ -z "$PRIMARY_URL" ]; then
                            print_warning "Could not locate repository metadata for $REPO_VERSION"
                            continue
                        fi
                        RPM_RELATIVE_PATH=$(curl -fsSL "$PRIMARY_URL" 2>/dev/null | gzip -dc 2>/dev/null | awk -v pkg="cuda-toolkit-${CUDA_PKG_VERSION}" -v requested_version="$TARGET_CUDA_EXACT_VERSION" '
                            function matches_requested(version, requested, len, next_char) {
                                if (requested == "") {
                                    return 1
                                }
                                len = length(requested)
                                if (substr(version, 1, len) != requested) {
                                    return 0
                                }
                                next_char = substr(version, len + 1, 1)
                                return (next_char == "" || next_char !~ /[0-9]/)
                            }
                            /<package/ { pkgmatch=0; version_ok=0 }
                            $0 ~ "<name>" pkg "</name>" {
                                pkgmatch=1
                                version_ok=0
                                if (requested_version == "") {
                                    version_ok=1
                                }
                            }
                            pkgmatch && /<version / {
                                version=""
                                release=""
                                version_ok=0
                                if (match($0, /ver="([^"]+)"/, arr)) {
                                    version=arr[1]
                                }
                                if (match($0, /rel="([^"]+)"/, arr)) {
                                    release=arr[1]
                                }
                                if (release != "") {
                                    version=version "-" release
                                }
                                if (matches_requested(version, requested_version)) {
                                    version_ok=1
                                }
                            }
                            pkgmatch && /<location href=/ {
                                if (version_ok == 1) {
                                    match($0, /href="([^"]+)"/, arr)
                                    if (arr[1] != "") { print arr[1]; exit }
                                }
                            }
                        ')
                        if [ -z "$RPM_RELATIVE_PATH" ]; then
                            if [ -n "$TARGET_CUDA_EXACT_VERSION" ]; then
                                print_warning "Could not locate CUDA toolkit package metadata for $REPO_VERSION matching $TARGET_CUDA_EXACT_VERSION"
                            else
                                print_warning "Could not locate CUDA toolkit package metadata for $REPO_VERSION"
                            fi
                            continue
                        fi

                        RPM_FILE_BASENAME=$(basename "$RPM_RELATIVE_PATH")
                        CUDA_RPM_FILE="${CUDA_CACHE_DIR}/$RPM_FILE_BASENAME"
                        CUDA_RPM_URL="https://developer.download.nvidia.com/compute/cuda/repos/${REPO_VERSION}/x86_64/$RPM_RELATIVE_PATH"

                        if [ ! -f "$CUDA_RPM_FILE" ]; then
                            print_info "Downloading CUDA toolkit package from NVIDIA..."
                            if wget -O "$CUDA_RPM_FILE" "$CUDA_RPM_URL"; then
                                CUDA_PACKAGE_DOWNLOADS+=("$CUDA_RPM_FILE")
                            else
                                print_warning "Failed to download $CUDA_RPM_URL"
                                rm -f "$CUDA_RPM_FILE"
                                continue
                            fi
                        else
                            print_info "Using cached CUDA toolkit package: $CUDA_RPM_FILE"
                        fi

                        if [ "$DNF_REFRESHED" = false ]; then
                            print_info "Refreshing package metadata before CUDA installation..."
                            if ! $PKG_UPDATE_CMD; then
                                print_warning "Package metadata refresh failed; CUDA installation may require manual dependency resolution"
                            fi
                            DNF_REFRESHED=true
                        fi

                        print_info "Installing CUDA toolkit package..."
                        if $PKG_INSTALL_CMD "$CUDA_RPM_FILE"; then
                            print_info "✓ CUDA $TARGET_CUDA_VERSION installed successfully"
                            CUDA_INSTALLED=true
                        else
                            print_warning "Failed to install CUDA toolkit from $CUDA_RPM_FILE"
                        fi
                    else
                        print_warning "Unsupported OS type $OS_TYPE for CUDA installation attempt"
                    fi

                    if [ "$CUDA_INSTALLED" = true ]; then
                        break
                    fi
                done
                if [ "$CUDA_INSTALLED" = true ]; then
                    CUDA_HOME_IN_BASHRC=false
                    CUDA_PATH_IN_BASHRC=false
                    CUDA_LD_LIBRARY_PATH_IN_BASHRC=false

                    if grep -q 'CUDA_HOME="/usr/local/cuda"' ~/.bashrc; then
                        CUDA_HOME_IN_BASHRC=true
                    fi
                    if grep -q "/usr/local/cuda/bin" ~/.bashrc; then
                        CUDA_PATH_IN_BASHRC=true
                    fi
                    if grep -q "/usr/local/cuda/lib64" ~/.bashrc; then
                        CUDA_LD_LIBRARY_PATH_IN_BASHRC=true
                    fi

                    if [ "$CUDA_HOME_IN_BASHRC" = false ] || [ "$CUDA_PATH_IN_BASHRC" = false ] || [ "$CUDA_LD_LIBRARY_PATH_IN_BASHRC" = false ]; then
                        if [ "$AUTO_YES" = true ]; then
                            ADD_CUDA_ENV="y"
                        else
                            read -p "Add CUDA environment variables to ~/.bashrc? (y/n): " ADD_CUDA_ENV
                        fi

                        if [[ "$ADD_CUDA_ENV" =~ ^[Yy]$ ]]; then
                            echo '' >> ~/.bashrc
                            if ! grep -q '^# CUDA toolkit$' ~/.bashrc; then
                                echo '# CUDA toolkit' >> ~/.bashrc
                            fi
                            if [ "$CUDA_HOME_IN_BASHRC" = false ]; then
                                echo 'export CUDA_HOME="/usr/local/cuda"' >> ~/.bashrc
                            fi
                            if [ "$CUDA_PATH_IN_BASHRC" = false ]; then
                                echo 'export PATH="/usr/local/cuda/bin:$PATH"' >> ~/.bashrc
                            fi
                            if [ "$CUDA_LD_LIBRARY_PATH_IN_BASHRC" = false ]; then
                                echo 'export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc
                            fi
                            print_info "Added CUDA environment variables to ~/.bashrc"
                            print_info "Run 'source ~/.bashrc' or start a new terminal to use nvcc"
                        else
                            print_info "Skipped adding CUDA environment variables"
                            print_info "You can manually add CUDA_HOME=/usr/local/cuda and /usr/local/cuda/bin to your PATH later"
                        fi
                    fi
                    CUDA_MISSING=false
                else
                    print_error "Failed to install CUDA automatically"
                    print_info "You may need to install it manually from:"
                    print_info "https://developer.nvidia.com/cuda-downloads"
                    print_info ""
                    if [ "$OS_TYPE" = "ubuntu" ]; then
                        print_info "Select: Linux > x86_64 > Ubuntu > $OS_VERSION_ID > deb (network)"
                    elif [ "$OS_TYPE" = "rhel" ]; then
                        print_info "Select: Linux > x86_64 > RHEL > $OS_VERSION_ID > rpm (network)"
                    fi
                    INSTALL_SUCCESS=false
                fi
            else
                CUDA_MISSING=false
            fi

            if [ "$INSTALL_SUCCESS" = true ]; then
                DRIVER_CUDA_STREAM="$CURRENT_CUDA_VERSION_NORMALIZED"
                if [ -n "$TARGET_CUDA_VERSION_NORMALIZED" ]; then
                    DRIVER_CUDA_STREAM="$TARGET_CUDA_VERSION_NORMALIZED"
                fi
                install_nvidia_driver_for_gpu_support "$DRIVER_CUDA_STREAM"
            fi
        
        echo ""
        if [ "$INSTALL_SUCCESS" = true ]; then
            if [ ${#CUDA_PACKAGE_DOWNLOADS[@]} -gt 0 ]; then
                echo ""
                print_info "CUDA support package(s) downloaded: ${CUDA_PACKAGE_DOWNLOADS[*]}"
                read -p "Delete downloaded package(s)? (y/n): " DELETE_CUDA_PKG
                if [[ "$DELETE_CUDA_PKG" =~ ^[Yy]$ ]]; then
                    for pkg_file in "${CUDA_PACKAGE_DOWNLOADS[@]}"; do
                        rm -f "$pkg_file"
                    done
                    print_info "Deleted cached CUDA package(s) from $CUDA_CACHE_DIR"
                else
                    print_info "Retained cached CUDA package(s) at $CUDA_CACHE_DIR"
                fi
            fi
            print_info "✅ Installation complete!"
        else
            print_error "❌ Installation had errors - check messages above"
            exit 1
        fi
