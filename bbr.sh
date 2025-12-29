# 1. 安装完整内核模块（保险起见）
sudo apt update && sudo apt install --reinstall linux-modules-$(uname -r)

# 2. 加载 BBR 模块
sudo modprobe tcp_bbr

# 3. 设置开机自启
echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf

# 4. 启用 BBR 算法
echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf

# 5. 应用配置
sudo sysctl -p

# 6. 验证
sysctl net.ipv4.tcp_congestion_control
lsmod | grep bbr
