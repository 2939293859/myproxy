#!/bin/bash
# VLESS + REALITY 一键部署脚本（伪装为 www.microsoft.com）
# （基于 Xray 官方示例）

set -e

# === 配置参数 ===
PORT=${1:-443}                     # 默认端口 443，可传参 ./install.sh 30191
UUID=${2:-"3a734d50-8ad6-4f05-b089-fb7662d7990d"}  # 你的 UUID
DEST_HOST="www.microsoft.com"
DEST_PORT=443
SHORT_ID=$(openssl rand -hex 4)    # 随机 shortId，如 a1b2c3d4

# === 检查是否为 root ===
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本（sudo su）"
  exit 1
fi

# === 安装依赖 ===
echo "[*] 安装必要工具..."
apt update >/dev/null 2>&1 || yum update -y >/dev/null 2>&1
apt install -y curl wget openssl jq >/dev/null 2>&1 || yum install -y curl wget openssl jq >/dev/null 2>&1

# === 安装 Xray（如果未安装）===
if ! command -v xray &> /dev/null; then
  echo "[*] 安装 Xray..."
  bash -c "$(curl -L https://github.com/XTLS/Xray-core/releases/latest/download/install-release.sh)" @ install
else
  echo "[*] Xray 已安装，跳过安装。"
fi

# === 生成 REALITY 私钥和公钥 ===
echo "[*] 生成 REALITY 密钥对..."
PRIVATE_KEY=$(xray x25519 --gen-private)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | xray x25519)

# === 创建配置目录 ===
mkdir -p /etc/xray

# === 生成 config.json ===
cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST_HOST:$DEST_PORT",
          "xver": 0,
          "serverNames": ["$DEST_HOST"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# === 重启 Xray 服务 ===
systemctl daemon-reexec
systemctl enable xray --now
systemctl restart xray

# === 检查状态 ===
if systemctl is-active --quiet xray; then
  echo -e "\n✅ Xray (VLESS + REALITY) 部署成功！\n"
else
  echo "❌ Xray 启动失败，请检查配置：journalctl -u xray -n 50"
  exit 1
fi

# === 输出客户端配置 ===
SERVER_IP=$(curl -s4m5 ip.sb || curl -s4m5 ifconfig.co || hostname -I | awk '{print $1}')
echo "📱 客户端配置信息如下："
echo "----------------------------------------"
echo "协议类型   : VLESS"
echo "地址       : $SERVER_IP"
echo "端口       : $PORT"
echo "用户ID     : $UUID"
echo "加密       : none"
echo "传输方式   : TCP"
echo "安全类型   : REALITY"
echo "Server Name: $DEST_HOST"
echo "Public Key : $PUBLIC_KEY"
echo "Short ID   : $SHORT_ID"
echo "指纹       : （留空或 auto）"
echo "----------------------------------------"
echo "💡 提示：在 v2rayN 4.6+、Qv2ray 或支持 REALITY 的客户端中填入以上信息即可使用。"
