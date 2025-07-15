#!/bin/bash

set -e

echo "==> Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake tmux wget unzip curl gnupg \
                    lsb-release software-properties-common python3-pip

echo "==> Installing AMDGPU drivers with ROCm legacy..."
wget https://repo.radeon.com/amdgpu-install/22.20/ubuntu/focal/amdgpu-install_22.20.50200-1_all.deb
sudo dpkg -i amdgpu-install_22.20.50200-1_all.deb
sudo apt update
sudo amdgpu-install --opencl=legacy,rocm --headless -y
sudo usermod -aG video,render,rocm $USER

echo "==> Reboot required after driver install. Please reboot manually and rerun this script with '--continue' after reboot."
exit 0
