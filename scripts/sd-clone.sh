#!/usr/bin/bash
echo "=== proxy env ==="
env | grep -i proxy || echo "(no env proxy)"
echo "=== gitconfig ==="
cat ~/.gitconfig 2>/dev/null || echo none
echo "=== clone ==="
mkdir -p /data/opt && cd /data/opt
rm -rf sd-cpp
timeout 240 git clone --depth 1 --recurse-submodules https://github.com/leejet/stable-diffusion.cpp sd-cpp 2>&1 | tail -6
echo "=== result ==="
ls /data/opt/sd-cpp/ 2>/dev/null | head -25
echo "=== submodule ggml ==="
ls /data/opt/sd-cpp/ggml/ 2>/dev/null | head -10