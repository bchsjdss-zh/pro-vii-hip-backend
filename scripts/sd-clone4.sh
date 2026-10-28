#!/usr/bin/bash
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export GIT_FLAGS="-c http.version=HTTP/1.1 -c http.postBuffer=524288000 -c http.lowSpeedLimit=0 -c http.lowSpeedTime=999"

cd /data/opt
rm -rf sd-cpp

for i in 1 2 3 4; do
  echo "=== main repo try $i (HTTP/1.1) ==="
  timeout 240 git $GIT_FLAGS clone --depth 1 --single-branch https://github.com/leejet/stable-diffusion.cpp sd-cpp >/tmp/clone.log 2>&1
  if [ $? -eq 0 ]; then echo "main repo OK"; break; fi
  tail -2 /tmp/clone.log
  rm -rf sd-cpp
done

if [ -d /data/opt/sd-cpp/.git ]; then
  cd /data/opt/sd-cpp
  git submodule sync >/dev/null 2>&1
  for i in 1 2 3 4; do
    echo "=== submodules try $i (HTTP/1.1) ==="
    timeout 240 git $GIT_FLAGS submodule update --init --depth 1 >/tmp/sub.log 2>&1
    if [ $? -eq 0 ]; then echo "submodules OK"; break; fi
    tail -2 /tmp/sub.log
  done
  echo "=== repo files ==="
  ls | head -30
  echo "=== ggml ==="
  ls ggml/ 2>/dev/null | head -12
  echo "=== gitmodules ==="
  cat .gitmodules 2>/dev/null
else
  echo "=== MAIN CLONE FAILED ==="
fi