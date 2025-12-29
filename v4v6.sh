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
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "listen": "0.0.0.0",
      "tag": "inbound-ipv4",
      "settings": {
        "clients": [
          {
            "id": "3a734d50-8ad6-4f05-b089-fb7662d7990d",
            "flow": "",
            "level": 0,
            "email": "ipv4_user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.bing.com:443",
          "xver": 0,
          "serverNames": [
            "www.bing.com"
          ],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [
            "50dcc34c59ea05a4"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "listen": "::",
      "tag": "inbound-ipv6",
      "settings": {
        "clients": [
          {
            "id": "3a734d50-8ad6-4f05-b089-fb7662d7990d",
            "flow": "",
            "level": 0,
            "email": "ipv6_user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.bing.com:443",
          "xver": 0,
          "serverNames": [
            "www.bing.com"
          ],
          "privateKey": "AHqEoFBhId-0WnCKEJkPNWUUYpohOVdxrIGyX-DFQG0",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [
            "50dcc34c59ea05a4"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "outbound-ipv4",
      "settings": {
        "domainStrategy": "UseIPv4"
      },
      "streamSettings": {
        "sockopt": {
          "mark": 100,
          "tcpFastOpen": true
        }
      }
    },
    {
      "protocol": "freedom",
      "tag": "outbound-ipv6",
      "settings": {
        "domainStrategy": "UseIPv6"
      },
      "streamSettings": {
        "sockopt": {
          "mark": 200,
          "tcpFastOpen": true
        }
      }
    },
    {
      "protocol": "blackhole",
      "tag": "block-ipv6-on-ipv4"
    },
    {
      "protocol": "blackhole",
      "tag": "block-ipv4-on-ipv6"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "dns": {
    "servers": [
      {
        "address": "1.1.1.1",
        "port": 53,
        "domains": [],
        "expectIPs": [],
        "queryStrategy": "UseIPv4"
      },
      {
        "address": "2606:4700:4700::1111",
        "port": 53,
        "domains": [],
        "expectIPs": [],
        "queryStrategy": "UseIPv6"
      }
    ],
    "queryStrategy": "UseIP",
    "disableCache": false,
    "disableFallback": true,
    "tag": "dns_inbound"
  },
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "inbound-ipv4"
        ],
        "network": "tcp,udp",
        "outboundTag": "outbound-ipv4"
      },
      {
        "type": "field",
        "inboundTag": [
          "inbound-ipv6"
        ],
        "network": "tcp,udp",
        "outboundTag": "outbound-ipv6"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "statsUserUplink": false,
        "statsUserDownlink": false,
        "bufferSize": 10240
      }
    },
    "system": {
      "statsInboundUplink": false,
      "statsInboundDownlink": false,
      "statsOutboundUplink": false,
      "statsOutboundDownlink": false
    }
  }
}
EOF

# ================== 启动服务 ==================
echo "▶ 启动 Xray..."
sed -i '1s/^\xEF\xBB\xBF//' /usr/local/etc/xray/config.json
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
