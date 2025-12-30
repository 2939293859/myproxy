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
set -e

echo "=== 创建网络命名空间（最终稳定版）==="

# ================== 基础参数 ==================
PUB_NS="ns-public"
PRIV_NS="ns-private"

PUB_VETH_HOST="veth-pub"
PUB_VETH_NS="veth-pub-ns"

PRIV_VETH_HOST="veth-priv"
PRIV_VETH_NS="veth-priv-ns"

PUB_NET4_HOST="172.16.100.1/30"
PUB_NET4_NS="172.16.100.2/30"

PRIV_NET4_HOST="172.16.200.1/30"
PRIV_NET4_NS="172.16.200.2/30"

ETH_PUBLIC="eth0"
ETH_PRIVATE="eth1"

# ================== 清理旧环境 ==================
ip netns del $PUB_NS 2>/dev/null || true
ip netns del $PRIV_NS 2>/dev/null || true
ip link del $PUB_VETH_HOST 2>/dev/null || true
ip link del $PRIV_VETH_HOST 2>/dev/null || true

# ================== 创建 netns ==================
ip netns add $PUB_NS
ip netns add $PRIV_NS

# 防止 netns 被 GC（关键）
ip netns exec $PUB_NS bash -c "sleep infinity" &
ip netns exec $PRIV_NS bash -c "sleep infinity" &

# ================== veth - public ==================
ip link add $PUB_VETH_HOST type veth peer name $PUB_VETH_NS
ip link set $PUB_VETH_NS netns $PUB_NS

ip addr add $PUB_NET4_HOST dev $PUB_VETH_HOST
ip link set $PUB_VETH_HOST up

ip netns exec $PUB_NS ip addr add $PUB_NET4_NS dev $PUB_VETH_NS
ip netns exec $PUB_NS ip link set lo up
ip netns exec $PUB_NS ip link set $PUB_VETH_NS up
ip netns exec $PUB_NS ip route add default via 172.16.100.1

# ================== veth - private ==================
ip link add $PRIV_VETH_HOST type veth peer name $PRIV_VETH_NS
ip link set $PRIV_VETH_NS netns $PRIV_NS

ip addr add $PRIV_NET4_HOST dev $PRIV_VETH_HOST
ip link set $PRIV_VETH_HOST up

ip netns exec $PRIV_NS ip addr add $PRIV_NET4_NS dev $PRIV_VETH_NS
ip netns exec $PRIV_NS ip link set lo up
ip netns exec $PRIV_NS ip link set $PRIV_VETH_NS up
ip netns exec $PRIV_NS ip route add default via 172.16.200.1

# ================== 内核转发 ==================
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# ================== NAT 规则 ==================
iptables -t nat -A POSTROUTING -s 172.16.100.2 -o $ETH_PUBLIC -j MASQUERADE

# 🚫 禁止 ns-private 出公网
iptables -A FORWARD -s 172.16.200.2 -o $ETH_PUBLIC -j DROP

# ================== 完成 ==================
echo ""
echo "✅ 配置完成"
echo ""
echo "测试："
echo "  公网 IPv4: ip netns exec ns-public ping -c 3 8.8.8.8"
echo "  内网测试: ip netns exec ns-private ping -c 3 10.1.8.1"
echo ""
echo "运行代理示例："
echo "  ip netns exec ns-public xray run -c /etc/xray/config.json"
echo "  ip netns exec ns-private your_program"

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
