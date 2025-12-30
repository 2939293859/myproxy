#!/bin/bash
set -e

echo "=== 初始化 IPv4 / IPv6 协议隔离环境（含 DNS 修复）==="

# ===== 修复 netns 目录 =====
mkdir -p /var/run/netns
mountpoint -q /var/run/netns || mount --bind /var/run/netns /var/run/netns

# ===== 参数 =====
NS_IPV4="ns-ipv4"
NS_IPV6="ns-ipv6"
ETH_PUBLIC="eth0"  # 主机用于访问外网的物理接口，请根据实际修改（如 ens3、enp0s3 等）

# IPv4 网段
V4_HOST="10.100.0.1/24"
V4_NS="10.100.0.2/24"
V4_GW="10.100.0.1"

# IPv6 网段（ULA）
V6_HOST="fd00:1000::1/64"
V6_NS="fd00:1000::2/64"
V6_GW="fd00:1000::1"

# ===== 清理旧配置 =====
echo "清理旧配置..."
ip netns del $NS_IPV4 2>/dev/null || true
ip netns del $NS_IPV6 2>/dev/null || true
ip link del veth-ipv4 2>/dev/null || true
ip link del veth-ipv6 2>/dev/null || true
rm -rf /etc/netns/$NS_IPV4 /etc/netns/$NS_IPV6

# ===== 创建命名空间 =====
echo "创建网络命名空间..."
ip netns add $NS_IPV4
ip netns add $NS_IPV6

# 保活（防止被 GC）
ip netns exec $NS_IPV4 sleep infinity &
IPV4_SLEEP_PID=$!
ip netns exec $NS_IPV6 sleep infinity &
IPV6_SLEEP_PID=$!

# ==============================
# === 配置 IPv4 专用命名空间 ===
# ==============================
echo "配置 IPv4 专用命名空间 ($NS_IPV4)..."

ip link add veth-ipv4 type veth peer name veth-ipv4-ns
ip link set veth-ipv4-ns netns $NS_IPV4

# 主机端
ip addr add $V4_HOST dev veth-ipv4
ip link set veth-ipv4 up

# 命名空间端
ip netns exec $NS_IPV4 ip link set lo up
ip netns exec $NS_IPV4 ip addr add $V4_NS dev veth-ipv4-ns
ip netns exec $NS_IPV4 ip link set veth-ipv4-ns up
ip netns exec $NS_IPV4 ip route add default via $V4_GW

# 禁用 IPv6
ip netns exec $NS_IPV4 sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
ip netns exec $NS_IPV4 sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null

# 配置 IPv4 DNS
mkdir -p /etc/netns/$NS_IPV4
cat > /etc/netns/$NS_IPV4/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
options timeout:1
EOF

# ==============================
# === 配置 IPv6 专用命名空间 ===
# ==============================
echo "配置 IPv6 专用命名空间 ($NS_IPV6)..."

ip link add veth-ipv6 type veth peer name veth-ipv6-ns
ip link set veth-ipv6-ns netns $NS_IPV6

# 主机端
ip -6 addr add $V6_HOST dev veth-ipv6
ip link set veth-ipv6 up

# 命名空间端
ip netns exec $NS_IPV6 ip link set lo up
ip netns exec $NS_IPV6 ip -6 addr add $V6_NS dev veth-ipv6-ns
ip netns exec $NS_IPV6 ip link set veth-ipv6-ns up
ip netns exec $NS_IPV6 ip -6 route add default via $V6_GW

# 阻断所有 IPv4 流量（模拟“禁用 IPv4”）
ip netns exec $NS_IPV6 iptables -P INPUT DROP
ip netns exec $NS_IPV6 iptables -P FORWARD DROP
ip netns exec $NS_IPV6 iptables -P OUTPUT DROP
# （可选）允许本地回环（通常不需要，保持 DROP 更干净）
# ip netns exec $NS_IPV6 iptables -A INPUT -i lo -j ACCEPT
# ip netns exec $NS_IPV6 iptables -A OUTPUT -o lo -j ACCEPT

# 配置 IPv6-only DNS（关键修复！）
mkdir -p /etc/netns/$NS_IPV6
cat > /etc/netns/$NS_IPV6/resolv.conf <<EOF
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
# Cloudflare IPv6 DNS (可选替换)：
# nameserver 2606:4700:4700::1111
# nameserver 2606:4700:4700::1001
options timeout:1
EOF

# ==============================
# === 启用主机转发 ===
# ==============================
echo "启用 IPv4/IPv6 转发..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
sysctl -w net.ipv6.conf.$ETH_PUBLIC.forwarding=1 >/dev/null

# ==============================
# === 配置 NAT 和防火墙规则 ===
# ==============================
echo "配置 NAT 和防火墙规则..."

# ---- IPv4 规则 ----
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true

iptables -t nat -A POSTROUTING -s $V4_NS -o $ETH_PUBLIC -j MASQUERADE
iptables -A FORWARD -i veth-ipv4 -o $ETH_PUBLIC -j ACCEPT
iptables -A FORWARD -i $ETH_PUBLIC -o veth-ipv4 -m state --state RELATED,ESTABLISHED -j ACCEPT

# ---- IPv6 规则 ----
ip6tables -t nat -F POSTROUTING 2>/dev/null || true
ip6tables -F FORWARD 2>/dev/null || true

# 注意：IPv6 MASQUERADE 需要内核支持（≥3.7）
ip6tables -t nat -A POSTROUTING -s $V6_NS -o $ETH_PUBLIC -j MASQUERADE
ip6tables -A FORWARD -i veth-ipv6 -o $ETH_PUBLIC -j ACCEPT
ip6tables -A FORWARD -i $ETH_PUBLIC -o veth-ipv6 -m state --state RELATED,ESTABLISHED -j ACCEPT

# ==============================
# === 验证输出 ===
# ==============================
echo ""
echo "✅ IPv4/IPv6 协议隔离环境创建完成（含 DNS 修复）！"
echo ""
echo "=== 命名空间列表 ==="
ip netns list
echo ""

echo "=== $NS_IPV4 (纯 IPv4) ==="
ip netns exec $NS_IPV4 ip -4 addr show veth-ipv4-ns 2>/dev/null
ip netns exec $NS_IPV4 ip -4 route 2>/dev/null
echo "DNS:"
ip netns exec $NS_IPV4 cat /etc/resolv.conf
echo ""

echo "=== $NS_IPV6 (纯 IPv6) ==="
ip netns exec $NS_IPV6 ip -6 addr show veth-ipv6-ns 2>/dev/null | grep -v fe80
ip netns exec $NS_IPV6 ip -6 route 2>/dev/null | grep -v fe80
echo "DNS:"
ip netns exec $NS_IPV6 cat /etc/resolv.conf
echo ""

echo "=== 测试命令 ==="
echo "# 测试 IPv4 命名空间（应成功）"
echo "ip netns exec $NS_IPV4 ping -c 2 google.com"
echo ""
echo "# 测试 IPv6 命名空间（应成功）"
echo "ip netns exec $NS_IPV6 ping6 -c 2 ipv6.google.com"
echo ""
echo "# 进入命名空间进行交互测试"
echo "ip netns exec $NS_IPV4 bash   # 纯 IPv4 环境"
echo "ip netns exec $NS_IPV6 bash   # 纯 IPv6 环境"
