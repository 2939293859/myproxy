#!/bin/bash

# === 颜色定义（美化输出）===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始安装 Xray...${NC}"

# === 步骤 1：更新系统并安装 curl ===
echo -e "${YELLOW}正在更新系统并安装 curl...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl 安装失败，请检查网络！${NC}"
    exit 1
fi

# === 步骤 2：下载并安装 Xray ===
echo -e "${YELLOW}正在安装 Xray...${NC}"
curl -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh | sudo bash -s -- install
if ! command -v xray &> /dev/null; then
    echo -e "${RED}Xray 安装失败！${NC}"
    exit 1
fi

# === 步骤 3：创建 Xray 配置文件 config.json ===
CONFIG='{
    "inbounds": [{
        "port": 30191,
        "protocol": "vless",
        "settings": {
            "clients": [
                {
                    "id": "3a734d50-8ad6-4f05-b089-fb7662d7990d",
                    "level": 0,
                    "email": "user@v2ray.com"
                }
            ],
            "decryption": "none"
        },
        "streamSettings": {
            "network": "tcp"
        }
    }],
    "outbounds": [{
        "protocol": "freedom",
        "settings": {}
    }]
}'

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="$CONFIG_DIR/config.json"

echo -e "${YELLOW}正在创建配置文件 $CONFIG_FILE...${NC}"

# 确保目录存在
sudo mkdir -p $CONFIG_DIR

# 写入配置文件
echo "$CONFIG" | sudo tee $CONFIG_FILE > /dev/null

# 设置权限
sudo chmod 644 $CONFIG_FILE

echo -e "${GREEN}配置文件已生成。${NC}"

# === 步骤 4：启动并设置开机自启 Xray ===
echo -e "${YELLOW}正在启动 Xray 并设置开机自启...${NC}"
sudo systemctl start xray
sudo systemctl enable xray
sudo systemctl restart xray

# 检查状态
if sudo systemctl is-active xray >/dev/null 2>&1; then
    echo -e "${GREEN}Xray 已成功启动！${NC}"
else
    echo -e "${RED}Xray 启动失败，请检查日志：journalctl -u xray${NC}"
    exit 1
fi

# === 最后提示信息 ===
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}✅ Xray 安装并启动成功！${NC}"
echo -e "${GREEN}端口: 30191${NC}"
echo -e "${GREEN}协议: VLESS-TCP${NC}"
echo -e "${GREEN}用户ID: 3a734d50-8ad6-4f05-b089-fb7662d7990d${NC}"
echo -e "${GREEN}==================================================${NC}"