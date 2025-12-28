#!/usr/bin/env bash
set -e

# ================== 基础参数 ==================
PORT=30191
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.microsoft.com"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

echo "▶ 更新系统 & 安装依赖..."
apt update -y
apt install -y curl unzip jq openssl

echo "▶ 安装 / 更新 Xray-core..."
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

XRAY_BIN=$(command -v xray)
if [[ -z "$XRAY_BIN" ]]; then
  echo "❌ 未找到 xray"
  exit 1
fi

echo "▶ 生成 REALITY PrivateKey..."
RAW_OUT="$(${XRAY_BIN} x25519)"

PRIVATE_KEY=$(echo "$RAW_OUT" | grep '^PrivateKey:' | awk -F: '{print $2}' | xargs)

if [[ -z "$PRIVATE_KEY" ]]; then
  echo "❌ PrivateKey 解析失败"
  echo "$RAW_OUT"
  exit 1
fi

echo "  ✔ PrivateKey = $PRIVATE_KEY"

echo "▶ 使用 std-encoding 推导 PublicKey..."
STD_OUT="$(${XRAY_BIN} x25519 -i "$PRIVATE_KEY" --std-encoding)"

PUBLIC_KEY=$(echo "$STD_OUT" | grep '^Public key:' | awk -F: '{print $2}' | xargs)

if [[ -z "$PUBLIC_KEY" ]]; then
  echo "❌ PublicKey 推导失败（std-encoding）"
  echo "$STD_OUT"
  exit 1
fi

echo "  ✔ PublicKey  = $PUBLIC_KEY"

echo "▶ 写入 Xray 配置文件..."
mkdir -p /usr/local/etc/xray

cat > "$XRAY_CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": ${PORT},
      "listen": "::",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": ["${SNI}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

echo "▶ 启动 Xray..."
systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

echo
echo "================= 部署完成 ================="
echo "地址        : <你的服务器IP>"
echo "端口        : ${PORT}"
echo "UUID        : ${UUID}"
echo "SNI         : ${SNI}"
echo "Public Key  : ${PUBLIC_KEY}"
echo "Flow        : xtls-rprx-vision"
echo "============================================"
