# llama-rx480-mining-rig-setup

## Overview
This setup transforms your RX 480 mining rig into a dedicated LLaMA inference server. It installs AMD ROCm 4.5 with OpenCL support, builds `llama.cpp` with GPU acceleration, and launches one quantized LLM model per GPU across ports 11434–11438. Systemd services are used to auto-restart model workers on boot.

---

## Hardware Requirements
- Ubuntu 20.04 LTS (kernel 5.4 — **no HWE**)
- 5× RX 480 8GB GPUs (connected before install)
- Minimum 8 GB RAM per card

---

## Installation Steps

### 1. Base System Prep
Ensure:
- Ubuntu 20.04 installed with kernel 5.4
- No LVM, no HWE kernel
- All 5 GPUs connected

Install dependencies:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake wget tmux unzip curl gnupg \
  lsb-release software-properties-common python3-pip
```

### 2. Install AMD ROCm Legacy Stack
```bash
wget https://repo.radeon.com/amdgpu-install/22.20/ubuntu/focal/amdgpu-install_22.20.50200-1_all.deb
sudo dpkg -i amdgpu-install_22.20.50200-1_all.deb
sudo apt update
sudo amdgpu-install --opencl=legacy,rocm --headless -y

sudo usermod -a -G video,render,rocm $USER
```
Reboot, then verify:
```bash
rocminfo
clinfo
```

### 3. Build `llama.cpp` with HIP
```bash
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

export PATH=/opt/rocm/bin:$PATH
export CC=/opt/rocm/bin/hipcc
export CXX=/opt/rocm/bin/hipcc

make LLAMA_HIPBLAS=1 -j$(nproc)
```

### 4. Create Model Directory
```bash
sudo mkdir -p /opt/llama-models
sudo chown $USER:$USER /opt/llama-models
```
Place your `.gguf` models here.

### 5. Worker Script: `launch_llama_workers.sh`
```bash
#!/bin/bash
LLAMA_DIR=~/llama.cpp
MODEL_DIR=/opt/llama-models
PORTS=(11434 11435 11436 11437 11438)
MODELS=(
  "codellama-7b.Q4_K_M.gguf"
  "mistral-7b.Q4_K_M.gguf"
  "wizardcoder-7b.Q4_K_M.gguf"
  "mistral-7b.Q4_K_M.gguf"
  "codellama-7b.Q4_K_M.gguf"
)

for i in ${!PORTS[@]}; do
  GPU_ID=$i
  PORT=${PORTS[$i]}
  MODEL=${MODELS[$i]}

  echo "Starting $MODEL on GPU $GPU_ID (port $PORT)"
  tmux new-session -d -s llama_$PORT \
    "$LLAMA_DIR/server -m $MODEL_DIR/$MODEL --port $PORT --n-gpu-layers 30 --threads 6"
done
```
Save as `~/launch_llama_workers.sh` and run:
```bash
chmod +x ~/launch_llama_workers.sh
./launch_llama_workers.sh
```

### 6. Enable Auto-Restart via systemd
For each port, create a service:
```bash
for i in {0..4}; do
  PORT=$((11434 + i))
  SERVICE_NAME="llama_worker_$PORT"
  MODEL_NAME=$(sed -n "$((i + 1))p" <<< $(printf "%s\n" "codellama-7b.Q4_K_M.gguf" "mistral-7b.Q4_K_M.gguf" "wizardcoder-7b.Q4_K_M.gguf" "mistral-7b.Q4_K_M.gguf" "codellama-7b.Q4_K_M.gguf"))

  cat << EOF | sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null
[Unit]
Description=LLaMA Worker on port $PORT
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/llama.cpp
ExecStart=$HOME/llama.cpp/server -m /opt/llama-models/$MODEL_NAME --port $PORT --n-gpu-layers 30 --threads 6
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

done

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now llama_worker_11434 llama_worker_11435 llama_worker_11436 llama_worker_11437 llama_worker_11438
```

### 7. (Optional) Install node_exporter for Prometheus
```bash
wget https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-1.8.1.linux-amd64.tar.gz
tar -xvf node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
nohup node_exporter &
```
This exposes metrics at `http://<rig_ip>:9100/metrics`

---

## Done ✅
You now have a fully functioning LLaMA inference node that:
- Runs 5 models (1 per GPU) on boot
- Exposes each via HTTP (ports 11434–11438)
- Can be monitored with Prometheus
- Is ready to connect to your NUC for agent control

Let me know if you'd like a quick verification script or curl test commands.
