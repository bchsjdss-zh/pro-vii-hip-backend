#!/usr/bin/bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890

cd /data/opt

# main repo, retry until gzip OK
for i in 1 2 3; do
  rm -f sd-cpp.tar.gz
  echo "=== main tarball try $i ==="
  timeout 240 curl -L --http1.1 -sS -o sd-cpp.tar.gz https://codeload.github.com/leejet/stable-diffusion.cpp/tar.gz/refs/heads/master
  if gzip -t sd-cpp.tar.gz 2>/dev/null; then echo "main gzip OK ($(stat -c%s sd-cpp.tar.gz) bytes)"; break; fi
  echo "gzip BROKEN ($(stat -c%s sd-cpp.tar.gz 2>/dev/null) bytes)"
done

# ggml fork, retry until gzip OK
for i in 1 2 3; do
  rm -f ggml-fork.tar.gz
  echo "=== ggml fork tarball try $i ==="
  timeout 240 curl -L --http1.1 -sS -o ggml-fork.tar.gz https://codeload.github.com/leejet/ggml/tar.gz/refs/heads/master
  if gzip -t ggml-fork.tar.gz 2>/dev/null; then echo "ggml gzip OK ($(stat -c%s ggml-fork.tar.gz) bytes)"; break; fi
  echo "ggml gzip BROKEN ($(stat -c%s ggml-fork.tar.gz 2>/dev/null) bytes)"
done

echo "=== sizes ==="
ls -la sd-cpp.tar.gz ggml-fork.tar.gz 2>/dev/null