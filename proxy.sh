#!/bin/bash
# 智能 SSH 代理脚本 / Smart SSH Proxy Script
# 优先使用 SOCKS5 代理（如果可用），否则直连
# Prefer SOCKS5 proxy if available, otherwise direct connection

HOST=$1
PORT=$2
SOCKS_PROXY="127.0.0.1:1080"

# 检测 SOCKS 代理是否可用
if nc -z -w 1 ${SOCKS_PROXY//:/ } &>/dev/null; then
  # SOCKS 代理可用，使用代理连接
  exec nc -x "$SOCKS_PROXY" "$HOST" "$PORT"
else
  # 代理不可用，尝试直连
  exec nc "$HOST" "$PORT"
fi
