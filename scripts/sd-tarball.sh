#!/usr/bin/bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890

echo "=== tools in container ==="
which ssh nc curl wget 2>/dev/null

cd /data/opt
rm -f sd-cpp.tar.gz

echo "=== tarball download (codeload, http1.1) ==="
timeout 200 curl -L --http1.1 -sS -o sd-cpp.tar.gz https://codeload.github.com/leejet/stable-diffusion.cpp/tar.gz/refs/heads/master
if [ -f sd-cpp.tar.gz ]; then
  ls -la sd-cpp.tar.gz
  echo "=== tarball content head ==="
  tar tzf sd-cpp.tar.gz 2>/dev/null | head -5
else
  echo "DOWNLOAD FAILED"
fi