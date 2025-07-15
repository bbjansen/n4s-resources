#!/bin/bash

MODEL_DIR="/opt/llama-models"
LLAMA_DIR="$HOME/llama.cpp"
PORTS=(11434 11435 11436 11437 11438)
MODELS=(
  "mistral-7b.Q4_K_M.gguf"
  "wizardcoder-7b.Q4_K_M.gguf"
  "codellama-7b.Q4_K_M.gguf"
  "mistral-7b.Q4_K_M.gguf"
  "codellama-7b.Q4_K_M.gguf"
)

for i in ${!PORTS[@]}; do
  PORT=${PORTS[$i]}
  MODEL=${MODELS[$i]}

  echo "Launching model $MODEL on port $PORT (GPU $i)..."
  tmux new-session -d -s llama_$PORT "
    cd $LLAMA_DIR &&
    ./server -m $MODEL_DIR/$MODEL --port $PORT --n-gpu-layers 35 --threads 6 --ctx-size 4096
  "
done
