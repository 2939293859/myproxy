#!/usr/bin/env bash
set -euo pipefail

# ================== 基础参数 ==================
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.bing.com"

PORT_V4=30191
PORT_V6=30192

NS_V4="ns-ipv4"
NS_V6="ns-ipv6"

# netns 内 veth IP（⚠️ DNAT 只能指向这里）
NS_V4_IP="10.100.0.2"
NS_V6_IP="fd00:1000::2"

EXT_IFACE="eth0"

XRAY_DIR="/usr/local/etc/xray"
XRAY_BIN="/usr/local/bin/xray"

PID_V4="/run/xray-ipv4.pid"
PID_V6="/run/xray-ipv6.pid"

# ================== REALITY 参数 ==================
PRIVATE_KEY="AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0"
PUBLIC_KEY="l5XWxm8T69d2JbhjiPSQQIf53iXR0DN3THYDfs-5TAE"
SHORT_ID="50dcc34c59ea05a4"

# ================== 修复 netns 目录 ==================
mkdir -p /var/run/netns
mountpoint -q /var/run/netns || mount --bind /var/run/netns /var/run/netns

# ================== 安装 Xray（仅首次） ==================
if ! command -v xray >/dev/null; then
  echo "▶ 在 ${NS_V4} 中安装 Xray"
  ip netns exec $NS_V4 bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
fi

[ ! -x "$XRAY_BIN" ] && { echo "❌ Xray 安装失败"; exit 1; }
mkdir -p "$XRAY_DIR"

# ================== 生成 IPv4 配置 ==================
cat > "$XRAY_DIR/v4.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT_V4,
    "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "$UUID", "flow": "xtls-rprx-vision" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "$SNI:443",
        "serverNames": ["$SNI"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "dns": {
    "servers": ["8.8.8.8", "8.8.4.4"],
    "queryStrategy": "UseIPv4"
  },
  "outbounds": [{
    "protocol": "freedom",
    "settings": { "domainStrategy": "UseIPv4" }
  }]
}
EOF

# ================== 生成 IPv6 配置 ==================
cat > "$XRAY_DIR/v6.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT_V6,
    "listen": "::",
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "$UUID", "flow": "xtls-rprx-vision" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "$SNI:443",
        "serverNames": ["$SNI"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "dns": {
    "servers": [
      "2001:4860:4860::8888",
      "2001:4860:4860::8844"
    ],
    "queryStrategy": "UseIPv6"
  },
  "outbounds": [{
    "protocol": "freedom",
    "settings": { "domainStrategy": "UseIPv6" }
  }]
}
EOF

# ================== 停止旧实例 ==================
for ns in $NS_V4 $NS_V6; do
  PID_FILE="/run/xray-${ns}.pid"
  if [[ -f "$PID_FILE" ]]; then
    ip netns exec $ns kill "$(cat $PID_FILE)" || true
    rm -f "$PID_FILE"
  fi
done

# ================== 启动 Xray ==================
ip netns exec $NS_V4 nohup $XRAY_BIN run -c $XRAY_DIR/v4.json \
  >/var/log/xray-ipv4.log 2>&1 & echo $! > $PID_V4

ip netns exec $NS_V6 nohup $XRAY_BIN run -c $XRAY_DIR/v6.json \
  >/var/log/xray-ipv6.log 2>&1 & echo $! > $PID_V6

sleep 1

# ================== DNAT（关键） ==================
echo "▶ 配置 DNAT 转发到 netns"

# IPv4 转发
sysctl -w net.ipv4.ip_forward=1

iptables -t nat -A PREROUTING -p tcp --dport $PORT_V4 \
  -j DNAT --to-destination ${NS_V4_IP}:${PORT_V4}

iptables -A FORWARD -p tcp -d ${NS_V4_IP} --dport $PORT_V4 \
  -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p tcp -s ${NS_V4_IP} --sport $PORT_V4 \
  -m state --state ESTABLISHED,RELATED -j ACCEPT

# IPv6 转发（⚠️ 若机房不支持 NAT66，可先注释）
sysctl -w net.ipv6.conf.all.forwarding=1

ip6tables -t nat -A PREROUTING -p tcp --dport $PORT_V6 \
  -j DNAT --to-destination [${NS_V6_IP}]:${PORT_V6}

ip6tables -A FORWARD -p tcp -d ${NS_V6_IP} --dport $PORT_V6 -j ACCEPT
ip6tables -A FORWARD -p tcp -s ${NS_V6_IP} --sport $PORT_V6 -j ACCEPT

# ================== 验证 ==================
echo
echo "▶ netns 监听状态："
ip netns exec $NS_V4 ss -lntp | grep $PORT_V4 || echo "❌ IPv4 未监听"
ip netns exec $NS_V6 ss -lntp | grep $PORT_V6 || echo "❌ IPv6 未监听"

echo
echo "================= 部署完成 ================="
echo "IPv4 入口 → 宿主:$PORT_V4 → ${NS_V4_IP}:$PORT_V4"
echo "IPv6 入口 → 宿主:$PORT_V6 → [${NS_V6_IP}]:$PORT_V6"
echo "UUID       : $UUID"
echo "SNI        : $SNI"
echo "Public Key : $PUBLIC_KEY"
echo "Short ID   : $SHORT_ID"
echo "Flow       : xtls-rprx-vision"
echo "============================================"
