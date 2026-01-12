#!/bin/bash

# ================= 配置区域 / Configuration =================
# 格式: "别名|用户名|主机|端口"
# Format: "alias|username|host|port"
SERVERS=(
  "Server1|user|192.168.1.100|22"
  "Server2|root|192.168.1.101|22"
  # 添加更多服务器 / Add more servers
)

# SOCKS5 代理配置 (用于 VPN Docker)
SOCKS_PROXY="127.0.0.1:1080"
CONTAINER_NAME="easyconnect"
VPN_SCRIPT="$HOME/Documents/SwiftBar/vpn_control.sh"
# ============================================================

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -o LogLevel=ERROR"

# 检测 VPN 是否运行
VPN_RUNNING=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$" && echo "true" || echo "false")

# 检测 SOCKS 代理是否可用
PROXY_OK=$(nc -z ${SOCKS_PROXY//:/ } 2>/dev/null && echo "true" || echo "false")

# 决定连接方式：有代理就用代理
USE_PROXY=false
if [ "$PROXY_OK" = "true" ]; then
  USE_PROXY=true
  NETWORK_STATUS="🌐 VPN 代理"
else
  NETWORK_STATUS="📡 直连模式"
fi

total_free=0
total_gpus=0
all_output=""

# 显示网络状态
all_output+="$NETWORK_STATUS\n"
all_output+="---\n"

for server in "${SERVERS[@]}"; do
  IFS='|' read -r alias user host port <<< "$server"
  
  # 构建 SSH 命令
  if [ "$USE_PROXY" = true ]; then
    SSH_CMD="/usr/bin/ssh $SSH_OPTS -o ProxyCommand='nc -x $SOCKS_PROXY %h %p' -p $port ${user}@${host}"
  else
    SSH_CMD="/usr/bin/ssh $SSH_OPTS -p $port ${user}@${host}"
  fi
  
  # 获取 GPU 数据
  RAW_DATA=$(eval $SSH_CMD "nvidia-smi --query-gpu=index,name,utilization.gpu,memory.free,memory.total --format=csv,noheader,nounits" 2>/dev/null | grep -v "^Warning\|^Error\|^\[Warning")
  
  if [ -z "$RAW_DATA" ]; then
    all_output+="$alias | color=red\n"
    all_output+="--⚠️ 连接失败 | color=gray\n"
    continue
  fi
  
  # 解析 GPU 数据
  server_output=$(echo "$RAW_DATA" | awk -F', ' -v alias="$alias" -v user="$user" -v host="$host" -v port="$port" '
  BEGIN { free_count = 0; gpu_count = 0; menu = "" }
  {
    idx=$1; name=$2; util=$3; mem_free=$4; mem_total=$5
    gpu_count++
    
    gsub(/NVIDIA /, "", name)
    gsub(/GeForce /, "", name)
    split(name, a, "-"); if(length(a[1])>0) name=a[1]
    
    if (util < 5 && mem_free > 4000) {
      icon = "🟢"; free_count++; color = ""
    } else {
      icon = "🔴"; color = " | color=#FF453A"
    }
    
    menu = menu sprintf("--%s [%s] %s: %dMB/%dMB (%d%%) | font=Menlo size=11 refresh=true%s\n", icon, idx, name, mem_free, mem_total, util, color)
  }
  END {
    title_color = (free_count == 0) ? " | color=#FF453A" : " | color=#30D158"
    printf "%s (%d/%d)%s\n%s", alias, free_count, gpu_count, title_color, menu
    printf "--🔗 SSH | shell=ssh param1=%s@%s param2=-p param3=%s terminal=true\n", user, host, port
    printf "STATS:%d:%d\n", free_count, gpu_count
  }')
  
  # 统计
  stats=$(echo "$server_output" | grep "^STATS:")
  if [ -n "$stats" ]; then
    total_free=$((total_free + $(echo "$stats" | cut -d: -f2)))
    total_gpus=$((total_gpus + $(echo "$stats" | cut -d: -f3)))
  fi
  
  all_output+=$(echo "$server_output" | grep -v "^STATS:")
  all_output+="\n"
done

# === 顶部状态栏 ===
if [ $total_gpus -eq 0 ]; then
  echo "GPU: -- | color=gray"
elif [ $total_free -eq 0 ]; then
  echo "GPU: 0/${total_gpus} | color=red"
else
  echo "GPU: ${total_free}/${total_gpus} | color=#30D158"
fi

echo "---"
echo -e "$all_output"
echo "---"

# === VPN 控制 ===
if [ "$VPN_RUNNING" = "true" ]; then
  echo "🟢 VPN 运行中 | color=#30D158"
  echo "--🛑 停止 | shell=bash param1=$VPN_SCRIPT param2=stop terminal=false refresh=true"
  echo "--📋 日志 | shell=docker param1=logs param2=-f param3=$CONTAINER_NAME terminal=true"
else
  echo "⚪ VPN 未运行"
  echo "--🚀 启动 | shell=bash param1=$VPN_SCRIPT param2=start terminal=true refresh=true"
fi

echo "---"
echo "🔄 刷新 | refresh=true"
