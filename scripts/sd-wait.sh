#!/usr/bin/bash
# 有界轮询：等主仓 clone 结束（最长 240s），然后立即验证
for i in $(seq 1 48); do
  if ! docker exec mi50 bash -c "pgrep -f 'git.*clone.*--depth' >/dev/null 2>&1"; then
    echo "=== clone proc finished at loop $i ==="
    break
  fi
  sleep 5
done
echo "=== state ==="
docker exec mi50 bash -c "
du -sh /data/opt/sd-cpp 2>/dev/null
ls /data/opt/sd-cpp/ 2>/dev/null | head -20
cd /data/opt/sd-cpp 2>/dev/null && git config --global --add safe.directory /data/opt/sd-cpp 2>/dev/null; git --no-pager log --oneline -1 2>&1
"