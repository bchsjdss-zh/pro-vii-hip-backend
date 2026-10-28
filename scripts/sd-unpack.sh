#!/usr/bin/bash
cd /data/opt
rm -rf sd-cpp
tar xzf sd-cpp.tar.gz
mv stable-diffusion.cpp-master sd-cpp
echo "=== .gitmodules ==="
cat sd-cpp/.gitmodules 2>/dev/null
echo "=== llama ggml? ==="
ls /opt/llama.cpp-master/ggml/CMakeLists.txt 2>/dev/null && echo "llama ggml OK" || echo "no llama ggml"
echo "=== build.md HIP section ==="
grep -A 20 "HIPBLAS" sd-cpp/docs/build.md 2>/dev/null | head -30
echo "=== repo top ==="
ls sd-cpp/ | head -25