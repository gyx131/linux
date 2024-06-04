#!/bin/bash
# 检查firewalld状态
echo "Firewalld Status:"
systemctl status firewalld.service
# 停止并禁用firewalld服务
echo "Stopping and disabling firewalld..."
systemctl stop firewalld.service
systemctl disable firewalld.service
# 配置BBR拥塞控制
echo "Enabling BBR congestion control..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
# 检查BBR是否启用
echo "Checking if BBR is enabled..."
lsmod | grep bbr
sysctl net.ipv4.tcp_available_congestion_control
# 安装lrzsz
echo "Installing lrzsz..."
if command -v yum &> /dev/null; then
    # CentOS/RHEL系
    yum install -y lrzsz
elif command -v apt-get &> /dev/null; then
    # Debian/Ubuntu系
    sudo apt-get update && sudo apt-get install -y lrzsz
else
    echo "Unsupported package manager. Please install lrzsz manually."
fi
echo "Script execution completed."
