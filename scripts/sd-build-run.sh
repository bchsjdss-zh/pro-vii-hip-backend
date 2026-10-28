#!/usr/bin/bash
cd /data/opt/sd-cpp
rm -f /data/opt/build-hip.log
nohup cmake --build build-hip -j4 > /data/opt/build-hip.log 2>&1 &
echo "build pid: $!"
sleep 5
echo "=== process check ==="
pgrep -ax cmake | head -3
pgrep -ax ninja 2>/dev/null | head -3 || true
echo "=== log head ==="
head -5 /data/opt/build-hip.log