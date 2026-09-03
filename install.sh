#!/bin/bash

if (( $# != 0 )); then
    printf 'Usage: ./install.sh\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPENDENCY_INSTALLER="$SCRIPT_DIR/01_install_dependencies.sh"
CUDA_INSTALLER="$SCRIPT_DIR/02_install_cuda.sh"
PYTHON_INSTALLER="$SCRIPT_DIR/03_install_python.sh"
CLI_INSTALLER="$SCRIPT_DIR/04_install_coding_clis.sh"
INSTALLERS=(
    "$DEPENDENCY_INSTALLER"
    "$CUDA_INSTALLER"
    "$PYTHON_INSTALLER"
    "$CLI_INSTALLER"
)

for installer in "${INSTALLERS[@]}"; do
    if [ ! -r "$installer" ]; then
        printf 'Error: required installer not readable: %s\n' "$installer" >&2
        exit 1
    fi
done

if [ "${TERM:-dumb}" = dumb ]; then
    printf 'Error: an interactive VT100-compatible terminal is required.\n' >&2
    exit 1
fi

TTY_FD=8
TTY_OPEN=0
TUI_ACTIVE=0
SAVED_STTY=""
WINCH_PENDING=0

if ! { exec 8<>/dev/tty; } 2>/dev/null; then
    printf 'Error: an interactive VT100-compatible terminal is required.\n' >&2
    exit 1
fi
TTY_OPEN=1
DEPENDENCY_LABELS=(
    "Tmux"
    "Node.js 24"
    "pnpm"
    "Bun"
    "Go"
    "Rust"
    "Zig"
    "Neovim"
    "Neovim Configs"
)
DEPENDENCY_FLAGS=(
    "--tmux"
    "--node"
    "--pnpm"
    "--bun"
    "--go"
    "--rust"
    "--zig"
    "--neovim"
    "--neovim-configs"
)
DEPENDENCY_SELECTED=(1 1 1 1 1 1 1 1 1)

CLI_LABELS=(
    "Arcee nac"
    "Claude Code"
    "DeepSeek Harness"
    "Gemini CLI"
    "Grok Build"
    "Meta Muse Code"
    "OMP Coding Agent"
    "OpenAI Codex"
    "OpenCode AI"
    "Pi"
    "Prime Intellect Agent"
)
CLI_FLAGS=(
    "--arcee"
    "--claude"
    "--deepseek"
    "--gemini"
    "--grok"
    "--muse"
    "--omp"
    "--codex"
    "--opencode"
    "--pi"
    "--prime"
)
CLI_SELECTED=(1 1 1 1 1 1 1 1 1 1 1)

all_dependencies_selected() {
    local selected

    for selected in "${DEPENDENCY_SELECTED[@]}"; do
        if (( ! selected )); then
            return 1
        fi
    done
    return 0
}

all_clis_selected() {
    local selected

    for selected in "${CLI_SELECTED[@]}"; do
        if (( ! selected )); then
            return 1
        fi
    done
    return 0
}

all_packages_selected() {
    all_dependencies_selected && all_clis_selected
}
CUDA_DEFAULT_VERSION="13.0"
PYTHON_DEFAULT_VERSION="3.11.16"
cuda_choice="default"
python_choice="default"
cuda_buffer=""
python_buffer=""
editing=""
status_message=""

PANEL_WIDTH=80
PANEL_HEIGHT=28
MIN_COLUMNS=80
MIN_ROWS=28
FIELD_WIDTH=47
terminal_rows=21
terminal_columns=80
panel_top=1
panel_left=1
terminal_too_small=0
focus_index=0
if [ -n "${NO_COLOR:-}" ]; then
    STYLE_RESET=""
    STYLE_BORDER=""
    STYLE_TITLE=""
    STYLE_FOCUS=""
    STYLE_SELECTED=""
    STYLE_MUTED=""
    STYLE_ALERT=""
else
    STYLE_RESET=$'\033[0m'
    STYLE_BORDER=$'\033[38;5;243m'
    STYLE_TITLE=$'\033[1;38;5;81m'
    STYLE_FOCUS=$'\033[1;38;5;81m'
    STYLE_SELECTED=$'\033[1;38;5;114m'
    STYLE_MUTED=$'\033[38;5;245m'
    STYLE_ALERT=$'\033[1;38;5;203m'
fi


FOCUS_CONTROLS=(
    "install"
    "cancel"
    "install_everything"
    "dependency:0"
    "dependency:1"
    "dependency:2"
    "dependency:3"
    "dependency:4"
    "dependency:5"
    "dependency:6"
    "dependency:7"
    "dependency:8"
    "cuda_default"
    "cuda_custom"
    "python_default"
    "python_custom"
    "cli:0"
    "cli:1"
    "cli:2"
    "cli:3"
    "cli:4"
    "cli:5"
    "cli:6"
    "cli:7"
    "cli:8"
    "cli:9"
    "cli:10"
)

terminal_size() {
    local size=""
    local rows=""
    local columns=""

    if (( TTY_OPEN )) && size="$(stty size <&"$TTY_FD" 2>/dev/null)"; then
        read -r rows columns <<<"$size"
        if [[ "$rows" =~ ^[1-9][0-9]*$ && "$columns" =~ ^[1-9][0-9]*$ ]]; then
            terminal_rows=$((10#$rows))
            terminal_columns=$((10#$columns))
            return
        fi
    fi

    if [[ "${LINES:-}" =~ ^[1-9][0-9]*$ && "${COLUMNS:-}" =~ ^[1-9][0-9]*$ ]]; then
        terminal_rows=$((10#$LINES))
        terminal_columns=$((10#$COLUMNS))
        return
    fi

    terminal_rows=21
    terminal_columns=80
}

center_content() {
    local text="$1"
    local width=$((PANEL_WIDTH - 2))
    local left
    local right

    if (( ${#text} > width )); then
        text="${text:0:width}"
    fi
    left=$(( (width - ${#text}) / 2 ))
    right=$((width - ${#text} - left))
    printf -v CENTERED_CONTENT '%*s%s%*s' "$left" "" "$text" "$right" ""
}

append_separator() {
    local title="$1"
    local dash_count=$((PANEL_WIDTH - ${#title} - 5))
    local dashes

    printf -v dashes '%*s' "$dash_count" ""
    PANEL_LINES+=("├─ $title ${dashes// /─}┤")
}

marker_for() {
    local control="$1"

    if [ "${FOCUS_CONTROLS[$focus_index]}" = "$control" ]; then
        FOCUS_MARKER=">"
    else
        FOCUS_MARKER=" "
    fi
}

checkbox_text() {
    local control="$1"
    local selected="$2"
    local label="$3"
    local mark=" "

    marker_for "$control"
    if (( selected )); then
        mark="X"
    fi
    CONTROL_TEXT="${FOCUS_MARKER} [${mark}] $label"
}

render_field() {
    local value="$1"
    local active="$2"
    local visible="$value"

    if (( ${#value} > FIELD_WIDTH )); then
        if (( active )); then
            visible="<${value: -46}"
        else
            visible="${value:0:46}>"
        fi
    fi
    printf -v RENDERED_FIELD '%-47.47s' "$visible"
}
append_blank_line() {
    local blank

    printf -v blank '%*s' "$((PANEL_WIDTH - 2))" ""
    PANEL_LINES+=("│${blank}│")
}


build_panel() {
    local all_selected=0
    local selected_mark=" "
    local install_text
    local cancel_text
    local content
    local custom_text
    local default_text
    local active
    local row
    local column
    local index
    local -a cells
    local border
    local title="YONIQ GPU Setup"

    PANEL_LINES=()
    printf -v border '%*s' "$((PANEL_WIDTH - ${#title} - 5))" ""
    PANEL_LINES+=("┌─ $title ${border// /─}┐")

    marker_for "install"
    install_text="${FOCUS_MARKER} [ Install ]"
    marker_for "cancel"
    cancel_text="${FOCUS_MARKER} [ Cancel ]"
    center_content "$install_text $cancel_text"
    PANEL_LINES+=("│${CENTERED_CONTENT}│")
    append_blank_line

    append_separator "Selection"
    if all_packages_selected; then
        all_selected=1
        selected_mark="X"
    fi
    marker_for "install_everything"
    center_content "${FOCUS_MARKER} [${selected_mark}] Install Everything"
    PANEL_LINES+=("│${CENTERED_CONTENT}│")
    if (( all_selected )); then
        center_content ""
    else
        center_content "[ ] Custom Installation"
    fi
    PANEL_LINES+=("│${CENTERED_CONTENT}│")

    append_separator "Dependencies"
    append_blank_line
    for ((row = 0; row < 3; row++)); do
        cells=("" "" "")
        for ((column = 0; column < 3; column++)); do
            index=$((row * 3 + column))
            checkbox_text "dependency:$index" "${DEPENDENCY_SELECTED[$index]}" "${DEPENDENCY_LABELS[$index]}"
            cells[column]="$CONTROL_TEXT"
        done
        printf -v content '%-25.25s%-25.25s%-26.26s' "${cells[0]}" "${cells[1]}" "${cells[2]}"
        PANEL_LINES+=("│ ${content} │")
    done
    append_blank_line

    append_separator "CUDA Version"
    marker_for "cuda_default"
    selected_mark=" "
    if [ "$cuda_choice" = "default" ]; then
        selected_mark="X"
    fi
    default_text="${FOCUS_MARKER} (${selected_mark}) $CUDA_DEFAULT_VERSION"
    marker_for "cuda_custom"
    selected_mark=" "
    if [ "$cuda_choice" = "custom" ]; then
        selected_mark="X"
    fi
    custom_text="${FOCUS_MARKER} (${selected_mark}) Custom "
    active=0
    if [ "$editing" = "cuda" ]; then
        active=1
    fi
    render_field "$cuda_buffer" "$active"
    printf -v content '%-11.11s%s[%s]   ' "$default_text" "$custom_text" "$RENDERED_FIELD"
    PANEL_LINES+=("│ ${content} │")
    append_blank_line

    append_separator "Python Version"
    marker_for "python_default"
    selected_mark=" "
    if [ "$python_choice" = "default" ]; then
        selected_mark="X"
    fi
    default_text="${FOCUS_MARKER} (${selected_mark}) $PYTHON_DEFAULT_VERSION"
    marker_for "python_custom"
    selected_mark=" "
    if [ "$python_choice" = "custom" ]; then
        selected_mark="X"
    fi
    custom_text="${FOCUS_MARKER} (${selected_mark}) Custom "
    active=0
    if [ "$editing" = "python" ]; then
        active=1
    fi
    render_field "$python_buffer" "$active"
    printf -v content '%-13.13s%s[%s] ' "$default_text" "$custom_text" "$RENDERED_FIELD"
    PANEL_LINES+=("│ ${content} │")
    append_blank_line

    append_separator "Coding CLIs"
    append_blank_line
    for ((row = 0; row < 4; row++)); do
        cells=("" "" "")
        for ((column = 0; column < 3; column++)); do
            index=$((row * 3 + column))
            if (( index < ${#CLI_LABELS[@]} )); then
                checkbox_text "cli:$index" "${CLI_SELECTED[$index]}" "${CLI_LABELS[$index]}"
                cells[column]="$CONTROL_TEXT"
            fi
        done
        if (( row == 3 )); then
            printf -v content '%-25.25s%-27.27s%-24.24s' "${cells[0]}" "${cells[1]}" "${cells[2]}"
        else
            printf -v content '%-25.25s%-25.25s%-26.26s' "${cells[0]}" "${cells[1]}" "${cells[2]}"
        fi
        PANEL_LINES+=("│ ${content} │")
    done
    append_blank_line

    append_separator "Controls"
    if [ -n "$status_message" ]; then
        center_content "$status_message"
    else
        center_content "Arrows/Tab move  Space select  Enter activate  i install  q cancel"
    fi
    PANEL_LINES+=("│${CENTERED_CONTENT}│")
    printf -v border '%*s' "$((PANEL_WIDTH - 2))" ""
    PANEL_LINES+=("└${border// /─}┘")
}
style_panel_line() {
    local line="$1"
    local line_index="$2"
    local title=""
    local body
    local before
    local after
    local is_border=0

    case "$line_index" in
        0)
            title="YONIQ GPU Setup"
            is_border=1
            ;;
        3)
            title="Selection"
            is_border=1
            ;;
        6)
            title="Dependencies"
            is_border=1
            ;;
        12)
            title="CUDA Version"
            is_border=1
            ;;
        15)
            title="Python Version"
            is_border=1
            ;;
        18)
            title="Coding CLIs"
            is_border=1
            ;;
        25)
            title="Controls"
            is_border=1
            ;;
        27)
            is_border=1
            ;;
    esac

    if (( is_border )); then
        if [ -n "$title" ]; then
            before="${line%%"$title"*}"
            after="${line#*"$title"}"
            STYLED_LINE="${STYLE_BORDER}${before}${STYLE_TITLE}${title}${STYLE_BORDER}${after}${STYLE_RESET}"
        else
            STYLED_LINE="${STYLE_BORDER}${line}${STYLE_RESET}"
        fi
        return
    fi

    body="${line#│}"
    body="${body%│}"
    if (( line_index == 26 )); then
        if [ -n "$status_message" ]; then
            body="${STYLE_ALERT}${body}${STYLE_RESET}"
        else
            body="${STYLE_MUTED}${body}${STYLE_RESET}"
        fi
    elif (( line_index == 5 )); then
        body="${STYLE_MUTED}${body}${STYLE_RESET}"
    else
        body="${body//"[X]"/${STYLE_SELECTED}[X]${STYLE_RESET}}"
        body="${body//"(X)"/${STYLE_SELECTED}(X)${STYLE_RESET}}"
        body="${body/>/${STYLE_FOCUS}›${STYLE_RESET}}"
    fi
    STYLED_LINE="${STYLE_BORDER}│${STYLE_RESET}${body}${STYLE_BORDER}│${STYLE_RESET}"
}


draw_screen() {
    local message
    local message_row
    local message_column
    local line_index
    local cursor_row
    local cursor_column
    local cursor_offset
    local buffer_length

    terminal_size
    printf '\033[0m\033[?25l\033[2J\033[H' >&"$TTY_FD"

    if (( terminal_columns < MIN_COLUMNS || terminal_rows < MIN_ROWS )); then
        terminal_too_small=1
        message="Terminal too small: need ${MIN_COLUMNS}x${MIN_ROWS}, have ${terminal_columns}x${terminal_rows}"
        message_row=$(( (terminal_rows + 1) / 2 ))
        message_column=$(( (terminal_columns - ${#message}) / 2 + 1 ))
        if (( message_row < 1 )); then
            message_row=1
        fi
        if (( message_column < 1 )); then
            message_column=1
        fi
        printf '\033[%d;%dH%s%s%s' \
            "$message_row" \
            "$message_column" \
            "$STYLE_ALERT" \
            "$message" \
            "$STYLE_RESET" >&"$TTY_FD"
        return
    fi

    terminal_too_small=0
    panel_top=$(( (terminal_rows - PANEL_HEIGHT) / 2 + 1 ))
    panel_left=$(( (terminal_columns - PANEL_WIDTH) / 2 + 1 ))
    build_panel
    for ((line_index = 0; line_index < ${#PANEL_LINES[@]}; line_index++)); do
        style_panel_line "${PANEL_LINES[$line_index]}" "$line_index"
        printf '\033[%d;%dH%s' \
            "$((panel_top + line_index))" \
            "$panel_left" \
            "$STYLED_LINE" >&"$TTY_FD"
    done

    if [ "$editing" = "cuda" ]; then
        buffer_length=${#cuda_buffer}
        cursor_offset=$buffer_length
        if (( cursor_offset > FIELD_WIDTH - 1 )); then
            cursor_offset=$((FIELD_WIDTH - 1))
        fi
        cursor_row=$((panel_top + 13))
        cursor_column=$((panel_left + 27 + cursor_offset))
        printf '\033[?25h\033[%d;%dH' "$cursor_row" "$cursor_column" >&"$TTY_FD"
    elif [ "$editing" = "python" ]; then
        buffer_length=${#python_buffer}
        cursor_offset=$buffer_length
        if (( cursor_offset > FIELD_WIDTH - 1 )); then
            cursor_offset=$((FIELD_WIDTH - 1))
        fi
        cursor_row=$((panel_top + 16))
        cursor_column=$((panel_left + 29 + cursor_offset))
        printf '\033[?25h\033[%d;%dH' "$cursor_row" "$cursor_column" >&"$TTY_FD"
    fi
}
version_at_least() {
    local major_value
    local minor_value
    local minimum_major_value
    local minimum_minor_value

    major_value=$((10#$1))
    minor_value=$((10#$2))
    minimum_major_value=$((10#$3))
    minimum_minor_value=$((10#$4))
    (( major_value > minimum_major_value ||
        (major_value == minimum_major_value && minor_value >= minimum_minor_value) ))
}

validate_cuda_versions() {
    local buffer="$1"
    local cuda_pattern='^(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))?(\.(0|[1-9][0-9]*))?$'
    local token
    local major
    local remainder
    local minor
    local stream
    local existing_stream
    local -a versions
    local -a streams=()

    CUDA_VERSION_ARGS=()
    if [ -z "$buffer" ] || [[ "$buffer" == ,* || "$buffer" == *, || "$buffer" == *,,* ]]; then
        status_message="Enter 1-10 comma-separated CUDA versions."
        return 1
    fi

    IFS=',' read -r -a versions <<<"$buffer"
    if (( ${#versions[@]} < 1 || ${#versions[@]} > 10 )); then
        status_message="Enter 1-10 comma-separated CUDA versions."
        return 1
    fi

    for token in "${versions[@]}"; do
        if (( ${#token} > 16 )); then
            status_message="CUDA version entries are limited to 16 characters."
            return 1
        fi
        if [[ ! "$token" =~ $cuda_pattern ]]; then
            status_message="Invalid CUDA version: $token."
            return 1
        fi

        major="${token%%.*}"
        remainder="${token#*.}"
        minor="0"
        if [ "$remainder" != "$token" ]; then
            minor="${remainder%%.*}"
        fi
        if ! version_at_least "$major" "$minor" 12 8; then
            status_message="CUDA versions must be 12.8 or newer: $token."
            return 1
        fi

        stream="$((10#$major)).$((10#$minor))"
        for existing_stream in "${streams[@]}"; do
            if [ "$existing_stream" = "$stream" ]; then
                status_message="CUDA major.minor streams must be unique: $stream."
                return 1
            fi
        done
        streams+=("$stream")
    done

    CUDA_VERSION_ARGS=("${versions[@]}")
    status_message=""
    return 0
}

validate_python_version() {
    local buffer="$1"
    local python_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
    local major
    local remainder
    local minor

    if [[ ! "$buffer" =~ $python_pattern ]]; then
        status_message="Python must be major.minor.patch, for example 3.11.16."
        return 1
    fi

    major="${buffer%%.*}"
    remainder="${buffer#*.}"
    minor="${remainder%%.*}"
    if ! version_at_least "$major" "$minor" 3 11; then
        status_message="Python version must be 3.11 or newer."
        return 1
    fi

    status_message=""
    return 0
}

read_key() {
    local byte=""
    local second=""
    local third=""
    local read_status=0

    KEY=""
    KEY_CHAR=""
    if (( WINCH_PENDING )); then
        KEY="resize"
        return 0
    fi

    while true; do
        read_status=0
        IFS= read -r -s -n 1 -t 0.1 -u "$TTY_FD" byte || read_status=$?
        if (( read_status == 0 )); then
            break
        fi
        if (( WINCH_PENDING )); then
            KEY="resize"
            return 0
        fi
        if (( read_status > 128 )); then
            continue
        fi
        return 1
    done

    case "$byte" in
        "")
            KEY="enter"
            ;;
        $'\r')
            KEY="enter"
            ;;
        $'\t')
            KEY="next"
            ;;
        " ")
            KEY="space"
            ;;
        $'\177'|$'\b')
            KEY="backspace"
            ;;
        $'\033')
            if ! IFS= read -r -s -n 1 -t 0.04 -u "$TTY_FD" second; then
                if (( WINCH_PENDING )); then
                    KEY="resize"
                else
                    KEY="escape"
                fi
                return 0
            fi
            if (( WINCH_PENDING )); then
                KEY="resize"
                return 0
            fi
            if [ "$second" != "[" ] && [ "$second" != "O" ]; then
                KEY="unknown"
                return 0
            fi
            if ! IFS= read -r -s -n 1 -t 0.01 -u "$TTY_FD" third; then
                if (( WINCH_PENDING )); then
                    KEY="resize"
                else
                    KEY="unknown"
                fi
                return 0
            fi
            case "$second$third" in
                "[A"|"OA") KEY="previous" ;;
                "[B"|"OB") KEY="next" ;;
                "[C"|"OC") KEY="next" ;;
                "[D"|"OD") KEY="previous" ;;
                "[Z") KEY="previous" ;;
                *) KEY="unknown" ;;
            esac
            ;;
        *)
            KEY="character"
            KEY_CHAR="$byte"
            ;;
    esac
    return 0
}

move_focus() {
    local direction="$1"
    local control_count=${#FOCUS_CONTROLS[@]}

    if [ "$direction" = "next" ]; then
        focus_index=$(( (focus_index + 1) % control_count ))
    else
        focus_index=$(( (focus_index - 1 + control_count) % control_count ))
    fi
    status_message=""
}

edit_version() {
    local kind="$1"
    local saved_choice="$2"
    local saved_buffer="$3"
    local buffer_length

    editing="$kind"
    if [ "$kind" = "cuda" ]; then
        cuda_choice="custom"
    else
        python_choice="custom"
    fi
    draw_screen

    while true; do
        if ! read_key; then
            editing=""
            return 2
        fi

        if [ "$KEY" = "resize" ]; then
            WINCH_PENDING=0
            draw_screen
            continue
        fi

        if (( terminal_too_small )); then
            if [ "$KEY" = "escape" ] || { [ "$KEY" = "character" ] && [ "$KEY_CHAR" = "q" ]; }; then
                editing=""
                return 3
            fi
            draw_screen
            continue
        fi

        case "$KEY" in
            escape)
                if [ "$kind" = "cuda" ]; then
                    cuda_choice="$saved_choice"
                    cuda_buffer="$saved_buffer"
                else
                    python_choice="$saved_choice"
                    python_buffer="$saved_buffer"
                fi
                editing=""
                status_message=""
                return 0
                ;;
            enter)
                if [ "$kind" = "cuda" ]; then
                    if validate_cuda_versions "$cuda_buffer"; then
                        editing=""
                        return 0
                    fi
                elif validate_python_version "$python_buffer"; then
                    editing=""
                    return 0
                fi
                ;;
            backspace)
                if [ "$kind" = "cuda" ]; then
                    cuda_buffer="${cuda_buffer%?}"
                else
                    python_buffer="${python_buffer%?}"
                fi
                status_message=""
                ;;
            character)
                if [ "$kind" = "cuda" ]; then
                    if [[ "$KEY_CHAR" != [0-9] && "$KEY_CHAR" != "." && "$KEY_CHAR" != "," ]]; then
                        status_message="Invalid CUDA character; use digits, dots, and commas only."
                    else
                        buffer_length=${#cuda_buffer}
                        if (( buffer_length >= 169 )); then
                            status_message="CUDA input is limited to 169 characters."
                        else
                            cuda_buffer+="$KEY_CHAR"
                            status_message=""
                        fi
                    fi
                elif [[ "$KEY_CHAR" != [0-9] && "$KEY_CHAR" != "." ]]; then
                    status_message="Invalid Python character; use digits and dots only."
                else
                    buffer_length=${#python_buffer}
                    if (( buffer_length >= 16 )); then
                        status_message="Python input is limited to 16 characters."
                    else
                        python_buffer+="$KEY_CHAR"
                        status_message=""
                    fi
                fi
                ;;
            *)
                if [ "$kind" = "cuda" ]; then
                    status_message="Invalid CUDA character; use digits, dots, and commas only."
                else
                    status_message="Invalid Python character; use digits and dots only."
                fi
                ;;
        esac
        draw_screen
    done
}

activate_custom_version() {
    local kind="$1"
    local activation_key="$2"
    local previous_choice
    local previous_buffer
    local is_valid=0

    if [ "$kind" = "cuda" ]; then
        previous_choice="$cuda_choice"
        previous_buffer="$cuda_buffer"
        if validate_cuda_versions "$cuda_buffer"; then
            is_valid=1
        fi
        cuda_choice="custom"
    else
        previous_choice="$python_choice"
        previous_buffer="$python_buffer"
        if validate_python_version "$python_buffer"; then
            is_valid=1
        fi
        python_choice="custom"
    fi

    if (( is_valid )) && [ "$activation_key" = "space" ]; then
        status_message=""
        return 0
    fi
    edit_version "$kind" "$previous_choice" "$previous_buffer"
}

select_every_package() {
    local index

    for ((index = 0; index < ${#DEPENDENCY_SELECTED[@]}; index++)); do
        DEPENDENCY_SELECTED[index]=1
    done
    for ((index = 0; index < ${#CLI_SELECTED[@]}; index++)); do
        CLI_SELECTED[index]=1
    done
}
refresh_runtime_paths() {
    local candidate
    local path_entry
    local path_contains_candidate
    local -a candidates=()
    local -a path_entries=()

    if [ -n "${PNPM_HOME:-}" ]; then
        candidates+=("$PNPM_HOME")
    fi
    if [ -n "${HOME:-}" ] && [ "${PNPM_HOME:-}" != "$HOME/.local/share/pnpm" ]; then
        candidates+=("$HOME/.local/share/pnpm")
    fi

    for candidate in "${candidates[@]}"; do
        if [ ! -d "$candidate" ] || [ ! -x "$candidate/pnpm" ]; then
            continue
        fi

        PNPM_HOME="$candidate"
        export PNPM_HOME
        path_contains_candidate=0
        IFS=':' read -r -a path_entries <<<"${PATH:-}"
        for path_entry in "${path_entries[@]}"; do
            if [ "$path_entry" = "$candidate" ]; then
                path_contains_candidate=1
                break
            fi
        done
        if (( ! path_contains_candidate )); then
            PATH="$candidate${PATH:+:$PATH}"
            export PATH
        fi
        return
    done
}

run_command() {
    local step_label="$1"
    local script_path="$2"
    local script_name="${2##*/}"
    local status

    shift 2
    printf '%s' "$step_label"
    printf ' %q' /bin/bash "$script_path" "$@"
    printf '\n'
    if /bin/bash "$script_path" "$@"; then
        return 0
    else
        status=$?
    fi

    printf 'Error: %s failed with status %d.\n' "$script_name" "$status" >&2
    return "$status"
}

perform_installation() {
    local edit_status
    local index
    local cli_selected_count=0
    local -a dependency_args=(-y)
    local -a cuda_args=(-y)
    local -a python_args=(-y)
    local -a cli_args=(-y)

    if [ "$cuda_choice" = "custom" ] && ! validate_cuda_versions "$cuda_buffer"; then
        focus_index=13
        edit_version "cuda" "$cuda_choice" "$cuda_buffer"
        edit_status=$?
        if (( edit_status == 2 )); then
            terminal_input_closed
            return 1
        fi
        if (( edit_status == 3 )); then
            cancel_installation
            return 0
        fi
        return 1
    fi
    if [ "$python_choice" = "custom" ] && ! validate_python_version "$python_buffer"; then
        focus_index=15
        edit_version "python" "$python_choice" "$python_buffer"
        edit_status=$?
        if (( edit_status == 2 )); then
            terminal_input_closed
            return 1
        fi
        if (( edit_status == 3 )); then
            cancel_installation
            return 0
        fi
        return 1
    fi

    if all_dependencies_selected; then
        dependency_args+=("--all")
    else
        for ((index = 0; index < ${#DEPENDENCY_SELECTED[@]}; index++)); do
            if (( DEPENDENCY_SELECTED[index] )); then
                dependency_args+=("${DEPENDENCY_FLAGS[$index]}")
            fi
        done
    fi

    if [ "$cuda_choice" = "default" ]; then
        cuda_args+=("$CUDA_DEFAULT_VERSION" "-d")
    else
        cuda_args+=("${CUDA_VERSION_ARGS[0]}" "-d")
        for ((index = 1; index < ${#CUDA_VERSION_ARGS[@]}; index++)); do
            cuda_args+=("${CUDA_VERSION_ARGS[$index]}")
        done
    fi

    if [ "$python_choice" = "default" ]; then
        python_args+=("$PYTHON_DEFAULT_VERSION")
    else
        python_args+=("$python_buffer")
    fi

    for ((index = 0; index < ${#CLI_SELECTED[@]}; index++)); do
        if (( CLI_SELECTED[index] )); then
            cli_selected_count=$((cli_selected_count + 1))
        fi
    done
    if (( cli_selected_count == ${#CLI_SELECTED[@]} )); then
        cli_args+=("--all")
    elif (( cli_selected_count > 0 )); then
        for ((index = 0; index < ${#CLI_SELECTED[@]}; index++)); do
            if (( CLI_SELECTED[index] )); then
                cli_args+=("${CLI_FLAGS[$index]}")
            fi
        done
    fi

    leave_tui
    run_command "[1/4]" "$DEPENDENCY_INSTALLER" "${dependency_args[@]}" || return $?
    run_command "[2/4]" "$CUDA_INSTALLER" "${cuda_args[@]}" || return $?
    run_command "[3/4]" "$PYTHON_INSTALLER" "${python_args[@]}" || return $?

    refresh_runtime_paths
    if (( cli_selected_count == 0 )); then
        printf '[4/4] Skipping coding CLIs (none selected)\n'
    else
        run_command "[4/4]" "$CLI_INSTALLER" "${cli_args[@]}" || return $?
    fi

    printf 'Installation complete.\n'
    return 0
}


activate_focused() {
    local activation_key="$1"
    local control="${FOCUS_CONTROLS[$focus_index]}"
    local index

    status_message=""
    case "$control" in
        install)
            perform_installation
            ;;
        cancel)
            return 3
            ;;
        install_everything)
            if ! all_packages_selected; then
                select_every_package
            fi
            ;;
        dependency:*)
            index="${control#dependency:}"
            DEPENDENCY_SELECTED[index]=$((1 - DEPENDENCY_SELECTED[index]))
            ;;
        cuda_default)
            cuda_choice="default"
            ;;
        cuda_custom)
            activate_custom_version "cuda" "$activation_key"
            ;;
        python_default)
            python_choice="default"
            ;;
        python_custom)
            activate_custom_version "python" "$activation_key"
            ;;
        cli:*)
            index="${control#cli:}"
            CLI_SELECTED[index]=$((1 - CLI_SELECTED[index]))
            ;;
    esac
}




leave_tui() {
    trap - EXIT
    trap '' INT TERM HUP WINCH
    if (( TUI_ACTIVE )); then
        if [ -n "$SAVED_STTY" ]; then
            stty "$SAVED_STTY" <&"$TTY_FD" 2>/dev/null || true
        fi
        printf '\033[0m\033[?25h\033[?1049l' >&"$TTY_FD"
        TUI_ACTIVE=0
    fi

    if (( TTY_OPEN )); then
        exec 8>&-
        TTY_OPEN=0
    fi

    trap - INT TERM HUP WINCH
}

# shellcheck disable=SC2317  # Invoked indirectly by the signal traps below.
handle_signal() {
    local status="$1"

    leave_tui
    exit "$status"
}

enter_tui() {
    if ! SAVED_STTY="$(stty -g <&"$TTY_FD" 2>/dev/null)" || [ -z "$SAVED_STTY" ]; then
        if (( TTY_OPEN )); then
            exec 8>&-
            TTY_OPEN=0
        fi
        printf 'Error: an interactive VT100-compatible terminal is required.\n' >&2
        return 1
    fi

    TUI_ACTIVE=1
    trap 'leave_tui' EXIT
    trap 'handle_signal 130' INT
    trap 'handle_signal 143' TERM
    trap 'handle_signal 129' HUP
    trap 'WINCH_PENDING=1' WINCH

    if ! stty -echo -icanon min 1 time 0 <&"$TTY_FD" 2>/dev/null; then
        leave_tui
        printf 'Error: an interactive VT100-compatible terminal is required.\n' >&2
        return 1
    fi

    printf '\033[?1049h\033[2J\033[H\033[?25l' >&"$TTY_FD"
}
cancel_installation() {
    leave_tui
    printf 'Installation cancelled.\n'
    return 0
}

terminal_input_closed() {
    leave_tui
    printf 'Error: terminal input closed.\n' >&2
    return 1
}

run_tui() {
    local activation_status

    draw_screen
    while true; do
        if ! read_key; then
            terminal_input_closed
            return 1
        fi

        if [ "$KEY" = "resize" ]; then
            WINCH_PENDING=0
            draw_screen
            continue
        fi

        if (( terminal_too_small )); then
            if [ "$KEY" = "escape" ] || { [ "$KEY" = "character" ] && [ "$KEY_CHAR" = "q" ]; }; then
                cancel_installation
                return 0
            fi
            draw_screen
            continue
        fi

        case "$KEY" in
            next)
                move_focus "next"
                ;;
            previous)
                move_focus "previous"
                ;;
            space|enter)
                activate_focused "$KEY"
                activation_status=$?
                if (( activation_status == 2 )); then
                    terminal_input_closed
                    return 1
                fi
                if (( activation_status == 3 )); then
                    cancel_installation
                    return 0
                fi
                if (( ! TUI_ACTIVE )); then
                    return "$activation_status"
                fi
                ;;
            escape)
                cancel_installation
                return 0
                ;;
            character)
                case "$KEY_CHAR" in
                    i)
                        perform_installation
                        activation_status=$?
                        if (( ! TUI_ACTIVE )); then
                            return "$activation_status"
                        fi
                        ;;
                    q)
                        cancel_installation
                        return 0
                        ;;
                esac
                ;;
        esac
        draw_screen
    done
}


if ! enter_tui; then
    exit 1
fi
run_tui
exit $?
