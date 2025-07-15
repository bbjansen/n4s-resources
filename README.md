# llama-rx480-setup

## Overview
This project sets up a local multi-GPU LLaMA inference system using 5× AMD RX 480 8GB GPUs on Ubuntu 20.04 LTS. It installs ROCm 4.5 or AMDGPU-Pro drivers, builds llama.cpp with HIP support, and runs one quantized LLM model per GPU. The NUC server orchestrates agent routing to specific GPUs using a FastAPI router.

---

## Hardware Requirements
- Mining rig with 5× RX 480 8GB GPUs
- NUC 10 Extreme (or equivalent) to act as orchestrator
- Minimum 8GB RAM per model (40GB system RAM recommended)

## Software Stack
- Ubuntu 20.04 LTS (kernel 5.4)
- ROCm 4.5 / amdgpu-pro with OpenCL legacy
- llama.cpp built with HIP support
- FastAPI router to distribute agent tasks
- Optional: systemd and tmux for managing workers

---

## Setup Instructions

### 1. Install Ubuntu 20.04 LTS
- Use the **standard GA kernel (5.4)**, **do NOT use HWE**
- Do **not enable LVM** unless absolutely required

### 2. Connect All GPUs
- Ensure all 5 RX 480 GPUs are plugged in **before installing drivers**
- Check detection:
  ```bash
  lspci | grep VGA
  ```

### 3. Run Setup Script
Clone this repo or create a `setup.sh` from the main script:
```bash
chmod +x setup.sh
./setup.sh
```
This script performs the following:
- Installs build tools, ROCm drivers, and dependencies
- Clones and builds `llama.cpp` with HIP support
- Creates `/opt/llama-models` for downloaded `.gguf` files
- Defines model/GPU mapping in `launch_llama_workers.sh`
- Sets up optional systemd services
- Generates a FastAPI router for agent → GPU inference routing

### 4. Download GGUF Models
Manually download and place quantized models in `/opt/llama-models`:
```bash
wget -O /opt/llama-models/mistral-7b.Q4_K_M.gguf https://huggingface.co/.../resolve/main/mistral-7b.Q4_K_M.gguf
```

### 5. Launch Model Workers
Either run manually:
```bash
~/launch_llama_workers.sh
```
Or use systemd:
```bash
sudo systemctl enable --now llama_worker_11434 llama_worker_11435 llama_worker_11436 llama_worker_11437 llama_worker_11438
```

### 6. Start Agent Router
On the NUC or host machine:
```bash
cd ~/llama-router
./start.sh
```
This exposes a single FastAPI endpoint at `http://localhost:8080/agent/{agent_type}`

---

## Example Usage
POST to the router:
```bash
curl http://localhost:8080/agent/refactor \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Refactor this code...", "n_predict": 200}'
```

---

## Agent Routing Map
| Agent       | Model (GPU) | Port   |
|-------------|-------------|--------|
| `refactor`  | CodeLLaMA   | 11434  |
| `planner`   | Mistral     | 11435  |
| `coder`     | WizardCoder | 11436  |
| `testgen`   | Mistral     | 11437  |
| `docwriter` | CodeLLaMA   | 11438  |

---

## Notes
- Model inference runs via `llama.cpp --server` mode
- FastAPI router provides centralized access
- You can expand this by adding agents, autoscaling, or a vector DB

---

## License
GNU General Public License v3.0
