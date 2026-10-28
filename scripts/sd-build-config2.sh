#!/usr/bin/bash
cd /data/opt/sd-cpp
rm -rf build-hip

cmake -S . -B build-hip \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/opt/rocm-5.7.1/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/rocm-5.7.1/llvm/bin/clang++ \
  -DSD_HIPBLAS=ON \
  -DSD_USE_UPSTREAM_GGML=ON \
  -DSD_GGML_SOURCE_DIR=/opt/llama.cpp-master/ggml \
  -DSD_WEBP=OFF \
  -DSD_WEBM=OFF \
  -DSD_BUILD_SHARED_LIBS=OFF \
  -DSD_BUILD_SERVER=OFF \
  -DGGML_HIP=ON \
  -DGGML_HIPBLAS=ON \
  -DAMDGPU_TARGETS=gfx906 \
  -DGPU_TARGETS=gfx906 \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  2>&1 | tail -25

echo "=== cache hip keys ==="
grep -E "GGML_HIP:|SD_HIPBLAS:|AMDGPU_TARGETS:|CMAKE_HIP_COMPILER:|SD_GGML_SOURCE_DIR:" build-hip/CMakeCache.txt 2>/dev/null