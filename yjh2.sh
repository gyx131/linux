#!/bin/bash

# 检查内核版本
kernel_version=$(uname -r | cut -d '.' -f1-2)
if [[ "$kernel_version" < "4.9" ]]; then
    echo "Kernel version is lower than 4.9. Installing BBR patch..."
    yum install wget
    wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh
else
    echo "Kernel version is 4.9 or higher. Applying BBR settings directly..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 检查BBR是否启用
echo "Checking if BBR is enabled..."
lsmod | grep bbr
sysctl net.ipv4.tcp_available_congestion_control

# 检查firewalld状态
echo "Firewalld Status:"
systemctl status firewalld.service

# 停止并禁用firewalld服务
echo "Stopping and disabling firewalld..."
systemctl stop firewalld.service
systemctl disable firewalld.service

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