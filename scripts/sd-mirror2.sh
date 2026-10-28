#!/usr/bin/bash
cd /data/opt
rm -f sd-cpp.tar.gz

MIRRORS="https://gh-proxy.com https://ghfast.top https://ghproxy.net https://ghps.cc"
SRC="github.com/leejet/stable-diffusion.cpp/archive/refs/heads/master.tar.gz"

for m in $MIRRORS; do
  echo "--- mirror: $m"
  if timeout 150 curl -L --http1.1 -sS -o sd-cpp.tar.gz "$m/https://$SRC"; then
    if gzip -t sd-cpp.tar.gz 2>/dev/null; then
      echo "OK via $m ($(stat -c%s sd-cpp.tar.gz) bytes)"
      break
    fi
  fi
  echo "  failed, removing"
  rm -f sd-cpp.tar.gz
done

if gzip -t sd-cpp.tar.gz 2>/dev/null; then
  echo "=== unpack main ==="
  rm -rf sd-cpp
  tar xzf sd-cpp.tar.gz 2>&1 | head -3
  mv stable-diffusion.cpp-master sd-cpp
  echo "=== unpack ggml fork ==="
  mkdir -p sd-cpp/ggml
  tar xzf ggml-fork.tar.gz -C sd-cpp/ggml --strip-components=1 2>&1 | head -3
  echo "=== verify ==="
  ls sd-cpp/ | head -25
  echo "--- ggml head ---"
  ls sd-cpp/ggml/ | head -15
  echo "--- ggml CMakeLists hip bits ---"
  grep -iE "HIP" sd-cpp/ggml/CMakeLists.txt | head -10
else
  echo "MAIN STILL BROKEN"
fi