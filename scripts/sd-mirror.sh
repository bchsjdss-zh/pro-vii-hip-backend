#!/usr/bin/bash
# kill 旧的空转 curl
pkill -f "codeload.github.com" 2>/dev/null
sleep 1

cd /data/opt
rm -f sd-cpp.tar.gz ggml-fork.tar.gz

MIRRORS="https://ghfast.top https://ghproxy.net https://gh-proxy.com https://ghps.cc"

fetch_via_mirror() {
  local src="$1" out="$2"
  for m in $MIRRORS; do
    echo "--- mirror: $m"
    if timeout 120 curl -L --http1.1 -sS -o "$out" "$m/https://$src"; then
      if gzip -t "$out" 2>/dev/null; then
        echo "OK via $m ($(stat -c%s "$out") bytes)"
        return 0
      fi
    fi
    rm -f "$out"
  done
  return 1
}

echo "=== main repo ==="
fetch_via_mirror "codeload.github.com/leejet/stable-diffusion.cpp/tar.gz/refs/heads/master" sd-cpp.tar.gz

echo "=== ggml fork ==="
fetch_via_mirror "codeload.github.com/leejet/ggml/tar.gz/refs/heads/master" ggml-fork.tar.gz

echo "=== final ==="
ls -la sd-cpp.tar.gz ggml-fork.tar.gz 2>/dev/null
gzip -t sd-cpp.tar.gz 2>/dev/null && echo "main OK" || echo "main BROKEN"
gzip -t ggml-fork.tar.gz 2>/dev/null && echo "ggml OK" || echo "ggml BROKEN"