#!/usr/bin/env bash
set -euo pipefail

# ================== 基础参数 ==================
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.bing.com"

PORT_V4=30191
PORT_V6=30192

NS_V4="ns-ipv4"
NS_V6="ns-ipv6"

XRAY_DIR="/usr/local/etc/xray"
XRAY_BIN="/usr/local/bin/xray"

PID_V4="/run/xray-ipv4.pid"
PID_V6="/run/xray-ipv6.pid"

# ================== REALITY 参数 ==================
PRIVATE_KEY="AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0"
PUBLIC_KEY="l5XWxm8T69d2JbhjiPSQQIf53iXR0DN3THYDfs-5TAE"
SHORT_ID="50dcc34c59ea05a4"

# ================== 修复 netns 目录（关键） ==================
mkdir -p /var/run/netns
mountpoint -q /var/run/netns || mount --bind /var/run/netns /var/run/netns

# ================== 安装 Xray（必须在有网的 netns） ==================
if ! command -v xray >/dev/null; then
  echo "▶ 在 ${NS_V4} 中安装 Xray（必须能联网）"
  ip netns exec $NS_V4 bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
fi

[ ! -x "$XRAY_BIN" ] && { echo "❌ Xray 安装失败"; exit 1; }

mkdir -p "$XRAY_DIR"

# ================== IPv4 配置 ==================
cat > "$XRAY_DIR/v4.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT_V4,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "flow": "xtls-rprx-vision" }
        ],
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
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ================== IPv6 配置 ==================
cat > "$XRAY_DIR/v6.json" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": $PORT_V6,
      "listen": "::",
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$UUID", "flow": "xtls-rprx-vision" }
        ],
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
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# ================== 停止旧实例（不误杀） ==================
if [[ -f "$PID_V4" ]]; then
  echo "▶ 停止旧 IPv4 Xray"
  ip netns exec $NS_V4 kill "$(cat $PID_V4)" || true
  rm -f "$PID_V4"
fi

if [[ -f "$PID_V6" ]]; then
  echo "▶ 停止旧 IPv6 Xray"
  ip netns exec $NS_V6 kill "$(cat $PID_V6)" || true
  rm -f "$PID_V6"
fi

# ================== 启动 Xray ==================
echo "▶ 启动 IPv4 VLESS（$NS_V4:$PORT_V4）"
ip netns exec $NS_V4 bash -c "
  nohup $XRAY_BIN run -c $XRAY_DIR/v4.json >/var/log/xray-ipv4.log 2>&1 &
  echo \$! > $PID_V4
"

echo "▶ 启动 IPv6 VLESS（$NS_V6:$PORT_V6）"
ip netns exec $NS_V6 bash -c "
  nohup $XRAY_BIN run -c $XRAY_DIR/v6.json >/var/log/xray-ipv6.log 2>&1 &
  echo \$! > $PID_V6
"

sleep 1

# ================== 验证 ==================
echo
echo "▶ 监听状态："
ip netns exec $NS_V4 ss -lntp | grep $PORT_V4 || echo "❌ IPv4 未监听"
ip netns exec $NS_V6 ss -lntp | grep $PORT_V6 || echo "❌ IPv6 未监听"

echo
echo "================= 部署完成 ================="
echo "IPv4  VLESS : ${PORT_V4}  (ns-ipv4)"
echo "IPv6  VLESS : ${PORT_V6}  (ns-ipv6)"
echo "UUID        : ${UUID}"
echo "SNI         : ${SNI}"
echo "Public Key  : ${PUBLIC_KEY}"
echo "Short ID    : ${SHORT_ID}"
echo "Flow        : xtls-rprx-vision"
echo "============================================"
