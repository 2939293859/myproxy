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
    "loglevel": "warning"
  },

  "dns": {
    "servers": [
      {
        "tag": "dns-v4",
        "address": "8.8.8.8",
        "domains": ["geosite:geolocation-!cn"],
        "expectIPs": ["geoip:!cn"]
      },
      {
        "tag": "dns-v6",
        "address": "2001:4860:4860::8888",
        "domains": ["geosite:geolocation-!cn"],
        "expectIPs": ["geoip:!cn"]
      }
    ]
  },

  "inbounds": [
    {
      "tag": "in-v4",
      "port": 30191,
      "listen": "0.0.0.0",
      "protocol": "vless",
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
          "dest": "www.bing.com:443",
          "serverNames": ["www.bing.com"],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "shortIds": ["50dcc34c59ea05a4"]
        }
      }
    },
    {
      "tag": "in-v6",
      "port": 30191,
      "listen": "::",
      "protocol": "vless",
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
          "dest": "www.bing.com:443",
          "serverNames": ["www.bing.com"],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "shortIds": ["50dcc34c59ea05a4"]
        }
      }
    }
  ],

  "outbounds": [
    {
      "tag": "out-v4",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      },
      "sendThrough": "23.27.120.248"
    },
    {
      "tag": "out-v6",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv6"
      },
      "sendThrough": "2400:8d60:0002:0000:0000:0001:4f08:bd65"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],

  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["in-v4"],
        "outboundTag": "out-v4"
      },
      {
        "type": "field",
        "inboundTag": ["in-v6"],
        "outboundTag": "out-v6"
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
