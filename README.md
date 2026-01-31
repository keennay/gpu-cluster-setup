# GPU Cluster Setup

### 1. Login your GPU compute provider.
For this, it's assumed your working directory is either `/` or `/workspace`. Edit as needed.

### 2. Run the below:
#### Cluster with Root user:
`mkdir -p /workspace ; cd /workspace ; git clone https://github.com/keennay/gpu-cluster-setup.git ; mv gpu-cluster-setup scripts ; cd scripts`<br>
#### Cluster with Ubuntu user:
`sudo mkdir -p /workspace ; sudo chown -R ubuntu:ubuntu /workspace ; cd /workspace ; git clone https://github.com/keennay/gpu-cluster-setup.git ; mv gpu-cluster-setup scripts ; cd scripts`<br>
#### Remaining:
`./01_init.sh`<br>
`./02_install_dependencies.sh`<br>
`./03_install_python.sh`<br>
`source ./04_setup_env.sh`<br>
`./05_install_packages.sh`<br>

### 3. Install any selection of open-weights models (DeepSeek V3/V3.1/R1, GLM-4.5, gpt-oss, Kimi K2, Qwen3)
`./install_model.sh`

### Template for Running GLM-4.5:
`serve_models/vllm_***.sh`

### Change Between Python Environments
`source ./launch_env.sh`
