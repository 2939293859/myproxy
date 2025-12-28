#!/usr/bin/env bash
set -e

PORT=30191
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.bing.com"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

echo "▶ 更新系统 & 安装依赖..."
apt update -y
apt install -y curl unzip jq openssl

echo "▶ 安装 / 更新 Xray-core..."
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

XRAY_BIN=$(command -v xray)
[[ -z "$XRAY_BIN" ]] && { echo "❌ 未找到 xray"; exit 1; }

echo "▶ 生成 REALITY 密钥..."
OUT="$(${XRAY_BIN} x25519)"

# 使用 awk 直接提取字段值，避免 xargs 和空格问题
PRIVATE_KEY=$(echo "$OUT" | awk '/^PrivateKey:/ {print $2}')
PUBLIC_KEY=$(echo "$OUT" | awk '/^Password:/   {print $2}')

if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
  echo "❌ REALITY 密钥解析失败"
  echo "原始输出："
  echo "$OUT"
  exit 1
fi

echo "  ✔ PrivateKey = $PRIVATE_KEY"
echo "  ✔ PublicKey (Hash32) = $PUBLIC_KEY"

mkdir -p /usr/local/etc/xray

echo "▶ 写入 Xray 配置..."
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
          "shortIds": ["6ba8e4"]
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
