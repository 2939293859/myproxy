#!/bin/bash
set -e

echo "=== 初始化 IPv4 / IPv6 协议隔离环境（正确禁协议版）==="

# ===== 修复 netns 目录 =====
mkdir -p /var/run/netns
mountpoint -q /var/run/netns || mount --bind /var/run/netns /var/run/netns

# ===== 参数 =====
NS_IPV4="ns-ipv4"
NS_IPV6="ns-ipv6"
ETH_PUBLIC="eth0"

V4_HOST="10.100.0.1/24"
V4_NS="10.100.0.2/24"
V4_GW="10.100.0.1"

V6_HOST="fd00:1000::1/64"
V6_NS="fd00:1000::2/64"
V6_GW="fd00:1000::1"

# ===== 清理 =====
ip netns del $NS_IPV4 2>/dev/null || true
ip netns del $NS_IPV6 2>/dev/null || true
ip link del veth-ipv4 2>/dev/null || true
ip link del veth-ipv6 2>/dev/null || true
rm -rf /etc/netns/$NS_IPV4 /etc/netns/$NS_IPV6

# ===== 创建 netns =====
ip netns add $NS_IPV4
ip netns add $NS_IPV6

ip netns exec $NS_IPV4 sleep infinity &
ip netns exec $NS_IPV6 sleep infinity &

# ================= IPv4-only =================
echo "配置 $NS_IPV4（纯 IPv4）"

ip link add veth-ipv4 type veth peer name veth-ipv4-ns
ip link set veth-ipv4-ns netns $NS_IPV4

ip addr add $V4_HOST dev veth-ipv4
ip link set veth-ipv4 up

ip netns exec $NS_IPV4 ip link set lo up
ip netns exec $NS_IPV4 ip addr add $V4_NS dev veth-ipv4-ns
ip netns exec $NS_IPV4 ip link set veth-ipv4-ns up
ip netns exec $NS_IPV4 ip route add default via $V4_GW

# 真·禁 IPv6
ip netns exec $NS_IPV4 sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
ip netns exec $NS_IPV4 sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
ip netns exec $NS_IPV4 sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null

mkdir -p /etc/netns/$NS_IPV4
cat > /etc/netns/$NS_IPV4/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# ================= IPv6-only =================
echo "配置 $NS_IPV6（纯 IPv6）"

ip link add veth-ipv6 type veth peer name veth-ipv6-ns
ip link set veth-ipv6-ns netns $NS_IPV6

ip -6 addr add $V6_HOST dev veth-ipv6
ip link set veth-ipv6 up

ip netns exec $NS_IPV6 ip link set lo up
ip netns exec $NS_IPV6 ip -6 addr add $V6_NS dev veth-ipv6-ns
ip netns exec $NS_IPV6 ip link set veth-ipv6-ns up
ip netns exec $NS_IPV6 ip -6 route add default via $V6_GW

# 真·禁 IPv4（不分配 IPv4 + policy）
ip netns exec $NS_IPV6 sysctl -w net.ipv4.conf.all.disable_policy=1 >/dev/null
ip netns exec $NS_IPV6 sysctl -w net.ipv4.conf.default.disable_policy=1 >/dev/null
ip netns exec $NS_IPV6 sysctl -w net.ipv4.conf.lo.disable_policy=1 >/dev/null

mkdir -p /etc/netns/$NS_IPV6
cat > /etc/netns/$NS_IPV6/resolv.conf <<EOF
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
EOF

# ================= 转发 =================
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
sysctl -w net.ipv6.conf.$ETH_PUBLIC.forwarding=1 >/dev/null

# ================= 防火墙（兜底，不禁协议） =================
iptables -t nat -F POSTROUTING || true
iptables -F FORWARD || true

iptables -t nat -A POSTROUTING -s $V4_NS -o $ETH_PUBLIC -j MASQUERADE
iptables -A FORWARD -i veth-ipv4 -o $ETH_PUBLIC -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

ip6tables -t nat -F POSTROUTING || true
ip6tables -F FORWARD || true

ip6tables -t nat -A POSTROUTING -s $V6_NS -o $ETH_PUBLIC -j MASQUERADE
ip6tables -A FORWARD -i veth-ipv6 -o $ETH_PUBLIC -j ACCEPT
ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "✅ IPv4 / IPv6 协议隔离完成（无误杀版）"
