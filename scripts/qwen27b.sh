#!/usr/bin/env bash
# qwen27b.sh — 一键拉起 Qwen3.8-27B Q3_K_S llama-server HIP (office-gpu, mi50 容器)
#
# 形态二选一 (全部实测参数):
#   64k  (默认): Q3_K_S + MTP 头, -c 65536, q4_0 KV   -> 短ctx 30 t/s / 64K满ctx 23 t/s
#   128k        : Q3_K_S 裸(无MTP), -c 131072, q4_0 KV -> 短ctx 24 t/s / 128K满ctx 12 t/s (MTP在128K会OOM)
#
# 用法: qwen27b.sh [start|stop|status] [64k|128k]
# 端点: http://127.0.0.1:8080  (OpenAI 兼容: /v1/chat/completions)
# 接入: 请求体加 chat_template_kwargs {"reasoning_effort": "medium"}
# 日志: /tmp/qwen27b-<mode>.log

set -u
ACTION="${1:-start}"
MODE="${2:-64k}"

BINPARENT=/opt/llama.cpp-master/build-hip
BIN_DIR=$BINPARENT/bin
MODEL=/data/models/llm/Qwen3.8-27B.Q3_K_S.gguf
MTP=/data/models/llm/mtp-Qwen3.8-27B-Q4_0.gguf
PORT=8080
LOG=/tmp/qwen27b-${MODE}.log

cexec() { sg docker -c "docker exec mi50 bash -c \"$1\""; }

case "$MODE" in
  64k|mtp)
    CTX=65536
    EXTRA="--spec-draft-model $MTP --spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-n-min 2"
    ;;
  128k|big)
    CTX=131072
    EXTRA=""
    ;;
  *)
    echo "未知形态: $MODE (可用: 64k / 128k)"; exit 1 ;;
esac

case "$ACTION" in
  start)
    cexec "pkill -x llama-server 2>/dev/null; sleep 2; cd $BINPARENT && LD_LIBRARY_PATH=./bin nohup ./bin/llama-server -m $MODEL $EXTRA -ngl 99 -fa 1 -c $CTX -ctk q4_0 -ctv q4_0 -np 1 --port $PORT --host 0.0.0.0 --no-webui > $LOG 2>&1 &"
    echo "拉起中: mode=$MODE ctx=$CTX"
    for i in $(seq 1 75); do
      s=$(curl -s -m 2 -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null)
      [ "$s" = "200" ] && { echo "READY  http://127.0.0.1:$PORT  (mode=$MODE, ctx=$CTX, #$(cexec "pgrep -x llama-server | head -1"))"; exit 0; }
      sleep 2
    done
    echo "超时未就绪, 查日志: $LOG"; exit 1
    ;;
  stop)
    cexec "pkill -x llama-server 2>/dev/null"
    echo "STOPPED (显存已释放)"
    ;;
  status)
    if cexec "pgrep -x llama-server >/dev/null"; then
      echo "RUNNING  pid=$(cexec 'pgrep -x llama-server | head -1')"
      curl -s -m 3 -o /dev/null -w "health: %{http_code}\n" http://localhost:$PORT/health
    else
      echo "STOPPED"
    fi
    ;;
  *)
    echo "用法: $0 [start|stop|status] [64k|128k]"; exit 1 ;;
esac