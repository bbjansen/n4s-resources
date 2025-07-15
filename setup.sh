#!/bin/bash
# Full Setup Script: RX 480 LLaMA Inference Node for AI Agents
# Target OS: Ubuntu 20.04 LTS

set -e

### 1. Update system and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake python3-pip wget tmux unzip curl gnupg lsb-release software-properties-common python3-venv

### 2. (Optional Fallback) Install ROCm 4.5 for legacy RX 480 support
# Warning: ROCm 5.x drops RX 480 support. This is legacy and community-maintained.
wget https://repo.radeon.com/amdgpu-install/22.20/ubuntu/focal/amdgpu-install_22.20.50200-1_all.deb
sudo dpkg -i amdgpu-install_22.20.50200-1_all.deb
sudo apt update
sudo amdgpu-install --opencl=legacy,rocm --headless -y

# Add ROCm and video groups to user
sudo usermod -a -G video $USER
sudo usermod -a -G render $USER
sudo usermod -a -G rocm $USER

### 3. Install llama.cpp with ROCm HIP support
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Configure ROCm toolchain if installed
export PATH=/opt/rocm/bin:$PATH
export CC=/opt/rocm/bin/hipcc
export CXX=/opt/rocm/bin/hipcc

make LLAMA_HIPBLAS=1 -j$(nproc)

### 4. Download GGUF models manually to /opt/llama-models (user-defined)
sudo mkdir -p /opt/llama-models
sudo chown $USER:$USER /opt/llama-models
# Example: wget -O /opt/llama-models/mistral.gguf "https://huggingface.co/..."

### 5. Create model launch script with GPU affinity and tmux
cat << 'EOF' > ~/launch_llama_workers.sh
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
    "cd $LLAMA_DIR && ./server -m $MODEL_DIR/$MODEL --port $PORT --n-gpu-layers 30 --threads 6"
done
EOF

chmod +x ~/launch_llama_workers.sh

### 6. Create systemd service files for each model server
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

[Install]
WantedBy=multi-user.target
EOF

done

sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "To enable all llama worker services:"
echo "sudo systemctl enable --now llama_worker_11434 llama_worker_11435 llama_worker_11436 llama_worker_11437 llama_worker_11438"

### 7. Create FastAPI router to map agent types to ports
mkdir -p ~/llama-router
cd ~/llama-router
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn httpx

cat << 'EOF' > main.py
from fastapi import FastAPI, Request
import httpx

app = FastAPI()

AGENT_TO_PORT = {
    "refactor": 11434,
    "planner": 11435,
    "coder": 11436,
    "testgen": 11437,
    "docwriter": 11438,
}

@app.post("/agent/{agent_type}")
async def route_prompt(agent_type: str, req: Request):
    if agent_type not in AGENT_TO_PORT:
        return {"error": "Invalid agent type"}
    port = AGENT_TO_PORT[agent_type]
    body = await req.body()
    async with httpx.AsyncClient() as client:
        response = await client.post(f"http://localhost:{port}/completion", content=body, headers={"Content-Type": "application/json"})
    return response.json()
EOF

cat << 'EOF' > start.sh
#!/bin/bash
cd ~/llama-router
source .venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8080
EOF

chmod +x start.sh

echo "Run '~/llama-router/start.sh' to start the FastAPI router on port 8080. It will forward agent calls to model ports."
