#!/bin/bash
# VPN 控制脚本 / VPN Control Script

# ================= 配置区域 / Configuration =================
EC_SERVER="https://your-vpn-server.edu.cn"   # VPN 服务器地址
EC_USERNAME="your_username"                   # 用户名
EC_PASSWORD="your_password"                   # 密码
CONTAINER_NAME="easyconnect"
# ============================================================

ACTION=$1

case "$ACTION" in
  start)
    # 检查 Docker
    if ! docker info &>/dev/null; then
      echo "❌ Docker 未运行，请先启动 Docker Desktop"
      exit 1
    fi
    
    # 检查是否已运行
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "✅ VPN 已在运行"
      exit 0
    fi
    
    # 清理旧容器
    docker rm -f $CONTAINER_NAME 2>/dev/null
    
    echo "🚀 启动 VPN..."
    docker run -d \
      --name $CONTAINER_NAME \
      --device /dev/net/tun \
      --cap-add NET_ADMIN \
      -e EC_VER=7.6.7 \
      -e CLI_OPTS="-d $EC_SERVER -u $EC_USERNAME -p $EC_PASSWORD" \
      -p 1080:1080 \
      hagb/docker-easyconnect:cli
    
    echo "⏳ 等待连接..."
    for i in {1..15}; do
      sleep 1
      if nc -z 127.0.0.1 1080 2>/dev/null; then
        echo "✅ VPN 连接成功！"
        exit 0
      fi
      echo "  等待中... ($i/15)"
    done
    
    echo "❌ VPN 连接超时，查看日志："
    docker logs $CONTAINER_NAME | tail -10
    exit 1
    ;;
    
  stop)
    echo "🛑 停止 VPN..."
    docker stop $CONTAINER_NAME 2>/dev/null
    docker rm $CONTAINER_NAME 2>/dev/null
    echo "✅ VPN 已停止"
    ;;
    
  status)
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
      echo "✅ VPN 运行中"
      nc -z 127.0.0.1 1080 && echo "   SOCKS5: 127.0.0.1:1080 ✅" || echo "   SOCKS5: ❌"
    else
      echo "❌ VPN 未运行"
    fi
    ;;
    
  restart)
    $0 stop
    sleep 2
    $0 start
    ;;
    
  *)
    echo "用法 / Usage: $0 {start|stop|status|restart}"
    exit 1
    ;;
esac
