#!/usr/bin/env bash
# MES 运维巡检脚本（只读，不修改任何文件、不写入任何数据）
# 用法: bash health_check.sh [mes-api 运行目录]  默认当前目录
# 输出: 端口监听 / 进程 / 磁盘 / 最近错误日志摘要
set -uo pipefail

API_DIR="${1:-$(pwd)}"
echo "==== MES 巡检 $(date '+%Y-%m-%d %H:%M:%S') ===="
echo "检查目录: $API_DIR"
echo

# 1. 端口监听
echo "--- 端口监听 ---"
for port in 7070 50000; do
  if lsof -i :"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[OK]  端口 $port 监听中 ($(lsof -i :"$port" -sTCP:LISTEN | tail -n +2 | awk '{print $1}' | sort -u | tr '\n' ' '))"
  else
    echo "[WARN] 端口 $port 未监听（若服务不在此机器属正常）"
  fi
done
echo

# 2. 相关进程
echo "--- 相关进程 ---"
pgrep -fl "mes-api|mes-app" 2>/dev/null | head -10 || echo "[INFO] 未发现 mes-api/mes-app 进程"
echo

# 3. 磁盘空间
echo "--- 磁盘空间 ---"
df -h "$API_DIR" 2>/dev/null | tail -1 | awk '{print "可用: "$4" / 总量: "$2" (已用 "$5")"}'
echo

# 4. 最近错误日志摘要（只读 tail，不改动日志文件）
echo "--- 最近错误日志 ---"
if [ -d "$API_DIR/logs" ]; then
  latest=$(ls -t "$API_DIR"/logs/*.log 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    echo "最新日志: $latest"
    errors=$(tail -n 500 "$latest" | grep -icE "ERROR|Exception" || true)
    echo "最近 500 行中 ERROR/Exception 出现次数: $errors"
    if [ "$errors" -gt 0 ]; then
      echo "最近 5 条错误摘要:"
      tail -n 500 "$latest" | grep -iE "ERROR|Exception" | tail -5 | cut -c1-160
    fi
  else
    echo "[INFO] 未找到日志文件"
  fi
else
  echo "[INFO] 目录下无 logs/ 子目录（请确认 mes-api 运行目录）"
fi
echo
echo "==== 巡检完成（本脚本只读，未做任何修改）===="
