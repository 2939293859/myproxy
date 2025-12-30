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
#!/bin/bash

# 网络命名空间双栈隔离配置脚本

set -e

echo "开始配置网络命名空间隔离..."

# 1. 创建两个网络命名空间
echo "创建网络命名空间..."
ip netns add ns-public   # 用于eth0 (公网接口)
ip netns add ns-private  # 用于eth1 (内网接口)

# 2. 将网卡移入对应的命名空间
echo "移动网络接口到命名空间..."
ip link set eth0 netns ns-public
ip link set eth1 netns ns-private

# 3. 配置ns-public命名空间 (eth0 - 公网)
echo "配置公网命名空间..."

# 启用loopback和eth0
ip netns exec ns-public ip link set lo up
ip netns exec ns-public ip link set eth0 up

# 配置IPv4地址
ip netns exec ns-public ip addr add 23.27.120.248/24 brd 23.27.120.255 dev eth0

# 配置IPv6地址
ip netns exec ns-public ip -6 addr add 2400:8d60:2::1:4f08:bd65/48 dev eth0

# 配置IPv4默认路由
ip netns exec ns-public ip route add default via 23.27.120.1 dev eth0

# 配置IPv6默认路由
ip netns exec ns-public ip -6 route add default via 2400:8d60:2::1 dev eth0

# 4. 配置ns-private命名空间 (eth1 - 内网)
echo "配置内网命名空间..."

# 启用loopback和eth1
ip netns exec ns-private ip link set lo up
ip netns exec ns-private ip link set eth1 up

# 配置IPv4地址
ip netns exec ns-private ip addr add 10.1.8.90/8 brd 10.255.255.255 dev eth1

# 配置IPv4路由（10.0.0.0/8网段）
ip netns exec ns-private ip route add 10.0.0.0/8 dev eth1 src 10.1.8.90

# 5. 验证配置
echo ""
echo "===== 公网命名空间 (ns-public) 配置 ====="
echo "--- IPv4 地址 ---"
ip netns exec ns-public ip -4 addr show eth0
echo "--- IPv6 地址 ---"
ip netns exec ns-public ip -6 addr show eth0
echo "--- IPv4 路由 ---"
ip netns exec ns-public ip -4 route
echo "--- IPv6 路由 ---"
ip netns exec ns-public ip -6 route

echo ""
echo "===== 内网命名空间 (ns-private) 配置 ====="
echo "--- IPv4 地址 ---"
ip netns exec ns-private ip -4 addr show eth1
echo "--- IPv4 路由 ---"
ip netns exec ns-private ip -4 route

echo ""
echo "配置完成！"
echo ""
echo "使用方法："
echo "  公网命名空间: ip netns exec ns-public <command>"
echo "  内网命名空间: ip netns exec ns-private <command>"
echo ""
echo "测试连接："
echo "  公网IPv4: ip netns exec ns-public ping -c 3 8.8.8.8"
echo "  公网IPv6: ip netns exec ns-public ping6 -c 3 2001:4860:4860::8888"
echo "  内网测试: ip netns exec ns-private ping -c 3 10.1.8.1"

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
