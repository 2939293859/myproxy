#!/usr/bin/env bash
set -e

# ================== 基础参数 ==================
PORT=30191
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.microsoft.com"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

echo "▶ 安装依赖..."
apt update
apt install -y curl unzip jq openssl

echo "▶ 安装 Xray..."
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

echo "▶ 生成 REALITY 密钥..."
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key/ {print $3}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/Public key/ {print $3}')

echo "▶ 写入 Xray 配置..."

cat > ${XRAY_CONFIG} <<EOF
{
  "log": {
    "loglevel": "warning"
  },
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
          "serverNames": [
            "${SNI}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            ""
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

echo "▶ 重启 Xray..."
systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

echo
echo "================= 部署完成 ================="
echo "VLESS + REALITY 信息："
echo
echo "地址        : <你的服务器IP>"
echo "端口        : ${PORT}"
echo "UUID        : ${UUID}"
echo "加密        : none"
echo "传输协议    : tcp"
echo "安全        : reality"
echo "SNI         : ${SNI}"
echo "Public Key  : ${PUBLIC_KEY}"
echo "Flow        : xtls-rprx-vision"
echo
echo "============================================"
