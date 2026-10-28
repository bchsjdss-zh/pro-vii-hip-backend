#!/usr/bin/bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
cd /data/opt
rm -rf sd-cpp
echo "=== clone ==="
timeout 300 git clone --depth 1 --recurse-submodules https://github.com/leejet/stable-diffusion.cpp sd-cpp 2>&1 | tail -6
echo "=== repo files ==="
ls /data/opt/sd-cpp/ 2>/dev/null | head -25
echo "=== ggml submodule ==="
ls /data/opt/sd-cpp/ggml/ 2>/dev/null | head -15