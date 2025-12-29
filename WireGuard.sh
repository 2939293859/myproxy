#!/usr/bin/env bash
set -e

echo "=== WireGuard 双实例（wg0 IPv6 + wg1 IPv4）一键安装脚本 ==="

# ================== 基础检查 ==================
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行"
  exit 1
fi

IFACE_OUT="eth0"

# ================== 安装 WireGuard ==================
echo ">>> 安装 WireGuard..."
apt update
apt install -y wireguard iptables iproute2

# ================== sysctl 永久开启转发 ==================
echo ">>> 配置内核转发..."
cat >/etc/sysctl.d/99-wireguard-forward.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

sysctl --system

# ================== 写入 wg0 (IPv6) ==================
echo ">>> 写入 wg0 (IPv6)..."
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = fd42:42:42::1/64
ListenPort = 26313
PrivateKey = mB73Nm54cPeZuQX9NKrY7LNWcT57yVsqr5UplNGKHVQ=

PostUp   = ip6tables -A FORWARD -i wg0 -j ACCEPT
PostUp   = ip6tables -A FORWARD -o wg0 -j ACCEPT
PostUp   = ip6tables -t nat -A POSTROUTING -o ${IFACE_OUT} -j MASQUERADE

PostDown = ip6tables -D FORWARD -i wg0 -j ACCEPT
PostDown = ip6tables -D FORWARD -o wg0 -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o ${IFACE_OUT} -j MASQUERADE

[Peer]
PublicKey = +fQ2eCWt0GYVOA8xseFmmQ9CeIkji8uHNeHikhZjZnU=
AllowedIPs = fd42:42:42::2/128
EOF

chmod 600 /etc/wireguard/wg0.conf

# ================== 写入 wg1 (IPv4) ==================
echo ">>> 写入 wg1 (IPv4)..."
cat >/etc/wireguard/wg1.conf <<EOF
[Interface]
Address = 10.10.10.1/24
ListenPort = 47527
PrivateKey = mB73Nm54cPeZuQX9NKrY7LNWcT57yVsqr5UplNGKHVQ=

PostUp   = iptables -A FORWARD -i wg1 -j ACCEPT
PostUp   = iptables -A FORWARD -o wg1 -j ACCEPT
PostUp   = iptables -t nat -A POSTROUTING -o ${IFACE_OUT} -j MASQUERADE

PostDown = iptables -D FORWARD -i wg1 -j ACCEPT
PostDown = iptables -D FORWARD -o wg1 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${IFACE_OUT} -j MASQUERADE

[Peer]
PublicKey = +fQ2eCWt0GYVOA8xseFmmQ9CeIkji8uHNeHikhZjZnU=
AllowedIPs = 10.10.10.2/32
EOF

chmod 600 /etc/wireguard/wg1.conf

# ================== 启动并设为开机自启 ==================
echo ">>> 启动 WireGuard..."
systemctl enable wg-quick@wg0
systemctl enable wg-quick@wg1

systemctl restart wg-quick@wg0
systemctl restart wg-quick@wg1

# ================== 状态检查 ==================
echo ">>> WireGuard 状态："
wg show

echo "=== ✅ 安装完成 ==="
echo "监听端口："
echo "  wg0 (IPv6): UDP 51820"
echo "  wg1 (IPv4): UDP 51821"
