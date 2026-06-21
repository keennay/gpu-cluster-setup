# GPU Cluster Setup

### 1. Login your GPU compute provider.
For this, it's assumed your working directory is either `/` or `/workspace`. Edit as needed.

### 2. Run the below:
#### GPU Instance with Root user (For ex: Runpod, Verda):
`mkdir -p /workspace ; cd /workspace ; git clone https://github.com/keennay/gpu-cluster-setup.git ; mv gpu-cluster-setup scripts ; cd scripts`<br>
#### GPU Instance with Ubuntu user (For ex: Prime Intellect):
`sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace ; cd /workspace ; git clone https://github.com/keennay/gpu-cluster-setup.git ; mv gpu-cluster-setup scripts ; cd scripts`<br>
#### Remaining:
`./01_install_dependencies.sh`<br>
`./02_install_coding_clis.sh`<br>
`./03_install_cuda.sh`<br>
`./04_install_python.sh`<br>
`source ./05_setup_env.sh`<br>
`./06_install_packages.sh`<br>

### 3.1 Template for Running Inference for Models (Also Downloads if model doesn't exist in HuggingFace PATH):
`./recipes/***.sh`

### 3.2 Install any selection of open-weights models or input your desired repo:
`./install_model.sh`

### Change Between Python Environments
`source ./launch_env.sh`
