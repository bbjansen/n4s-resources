#!/bin/bash

set -e

echo "==> Cloning and building llama.cpp with HIP..."
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

export PATH=/opt/rocm/bin:$PATH
export CC=/opt/rocm/bin/hipcc
export CXX=/opt/rocm/bin/hipcc

cmake -B build -DLLAMA_HIPBLAS=ON
cmake --build build -j$(nproc)

echo "==> Creating model directory..."
sudo mkdir -p /opt/llama-models
sudo chown $USER:$USER /opt/llama-models

echo "==> Installing node_exporter (optional)..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.9.1.linux-amd64.tar.gz
sudo mv node_exporter-1.9.1.linux-amd64/node_exporter /usr/local/
nohup node_exporter &

echo "==> Done. Please place your .gguf models in /opt/llama-models"
