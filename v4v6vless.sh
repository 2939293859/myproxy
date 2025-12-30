#!/usr/bin/env bash
set -e

# ================== 基础参数 ==================
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.bing.com"

PORT_V4=30191
PORT_V6=30192

NS_V4="ns-ipv4"
NS_V6="ns-ipv6"

XRAY_DIR="/usr/local/etc/xray"

# ================== REALITY 参数 ==================
PRIVATE_KEY="AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0"
PUBLIC_KEY="l5XWxm8T69d2JbhjiPSQQIf53iXR0DN3THYDfs-5TAE"
SHORT_ID="50dcc34c59ea05a4"

# ================== 安装依赖 ==================
# echo "▶ 安装依赖..."
# apt update -y
# apt install -y curl unzip jq iproute2

# ================== 安装 Xray ==================
# echo "▶ 安装 / 更新 Xray-core..."
# bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

XRAY_BIN=$(command -v xray)
[ -z "$XRAY_BIN" ] && { echo "❌ 未找到 xray"; exit 1; }

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
  "outbounds": [
    { "protocol": "freedom" }
  ]
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
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

# ================== 启动 Xray（netns） ==================
echo "▶ 启动 IPv4 VLESS（$NS_V4:$PORT_V4）"
ip netns exec $NS_V4 pkill xray 2>/dev/null || true
ip netns exec $NS_V4 $XRAY_BIN run -c $XRAY_DIR/v4.json &

echo "▶ 启动 IPv6 VLESS（$NS_V6:$PORT_V6）"
ip netns exec $NS_V6 pkill xray 2>/dev/null || true
ip netns exec $NS_V6 $XRAY_BIN run -c $XRAY_DIR/v6.json &

sleep 1

# ================== 验证 ==================
echo
echo "▶ 监听状态："
ip netns exec $NS_V4 ss -lntp | grep $PORT_V4 || echo "❌ IPv4 未监听"
ip netns exec $NS_V6 ss -lntp | grep $PORT_V6 || echo "❌ IPv6 未监听"

# ================== 输出 ==================
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
