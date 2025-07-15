#!/bin/bash

set -e

echo "==> Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential git cmake tmux wget unzip curl gnupg \
                    lsb-release software-properties-common python3-pip

echo "==> Installing AMDGPU drivers with ROCm legacy..."
curl -O -e http://support.amd.com https://drivers.amd.com/drivers/linux/amdgpu-pro-20.45-1188099-ubuntu-20.04.tar.xz

sudo dpkg -i amdgpu-install_22.20.50200-1_all.deb
sudo apt update
sudo amdgpu-install --opencl=legacy,rocm --headless -y
sudo usermod -aG video,render,rocm $USER

echo "==> Reboot required after driver install. Please reboot manually and rerun this script with '--continue' after reboot."
exit 0
