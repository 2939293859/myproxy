#!/usr/bin/env bash
set -e

# ================== 基础参数 ==================
PORT=30191
UUID="3a734d50-8ad6-4f05-b089-fb7662d7990d"
SNI="www.bing.com"

XRAY_CONFIG="/usr/local/etc/xray/config.json"

# ================== REALITY 固定参数 ==================
PRIVATE_KEY="AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0"
PUBLIC_KEY="l5XWxm8T69d2JbhjiPSQQIf53iXR0DN3THYDfs-5TAE"
SHORT_ID="50dcc34c59ea05a4"

# ================== 安装依赖 ==================
echo "▶ 更新系统 & 安装依赖..."
apt update -y
apt install -y curl unzip jq openssl

# ================== 安装 Xray ==================
echo "▶ 安装 / 更新 Xray-core..."
bash <(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)

XRAY_BIN=$(command -v xray)
if [[ -z "$XRAY_BIN" ]]; then
  echo "❌ 未找到 xray"
  exit 1
fi

mkdir -p /usr/local/etc/xray

# ================== 写入配置 ==================
echo "▶ 写入 Xray REALITY 配置..."
cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "info"
  },

  "dns": {
    "disableFallback": true,
    "disableFallbackIfMatch": true,
    "servers": [
      {
        "tag": "dns-v4",
        "address": "https://1.1.1.1/dns-query",
        "queryStrategy": "UseIPv4"
      },
      {
        "tag": "dns-v6",
        "address": "https://[2606:4700:4700::1111]/dns-query",
        "queryStrategy": "UseIPv6"
      }
    ]
  },

  "inbounds": [
    {
      "port": 30191,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "tag": "in-v4",
      "settings": {
        "clients": [
          {
            "id": "3a734d50-8ad6-4f05-b089-fb7662d7990d",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "204.79.197.200:443",
          "serverNames": [
            "www.bing.com"
          ],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "shortIds": [
            "50dcc34c59ea05a4"
          ]
        }
      }
    },

    {
      "port": 30192,
      "listen": "::",
      "protocol": "vless",
      "tag": "in-v6",
      "settings": {
        "clients": [
          {
            "id": "3a734d50-8ad6-4f05-b089-fb7662d7990d",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "[2620:1ec:bdf::35]:443",
          "serverNames": [
            "www.bing.com"
          ],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "shortIds": [
            "50dcc34c59ea05a4"
          ]
        }
      }
    }
  ],

  "outbounds": [
    {
      "tag": "ipv4-out",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    },
    {
      "tag": "ipv6-out",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv6"
      }
    },
    {
      "tag": "dns-v4",
      "protocol": "dns"
    },
    {
      "tag": "dns-v6",
      "protocol": "dns"
    }
  ],

  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["in-v4"],
        "outboundTag": "ipv4-out"
      },
      {
        "type": "field",
        "inboundTag": ["in-v6"],
        "outboundTag": "ipv6-out"
      },
      {
        "type": "field",
        "inboundTag": ["in-v4"],
        "outboundTag": "dns-v4",
        "network": "udp"
      },
      {
        "type": "field",
        "inboundTag": ["in-v6"],
        "outboundTag": "dns-v6",
        "network": "udp"
      }
    ]
  }
}





EOF

# ================== 启动服务 ==================
echo "▶ 启动 Xray..."
systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

# ================== 输出信息 ==================
echo
echo "================= 部署完成 ================="
echo "地址        : <你的服务器IP>"
echo "端口        : ${PORT}"
echo "UUID        : ${UUID}"
echo "SNI         : ${SNI}"
echo "Public Key  : ${PUBLIC_KEY}"
echo "Short ID    : ${SHORT_ID}"
echo "Flow        : xtls-rprx-vision"
echo "============================================"
