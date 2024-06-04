#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "请以root用户身份运行此脚本。"
    exit 1
fi

# 检查firewalld状态
echo "Firewalld Status:"
systemctl status firewalld.service

# 停止并禁用firewalld服务
echo "Stopping and disabling firewalld..."
if systemctl is-active --quiet firewalld.service; then
    systemctl stop firewalld.service
    systemctl disable firewalld.service
    echo "Firewalld has been stopped and disabled."
else
    echo "Firewalld is not active or not installed."
fi

# 配置BBR拥塞控制
echo "Enabling BBR congestion control..."
cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl -p
if sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
    echo "BBR congestion control has been enabled."
else
    echo "Failed to enable BBR congestion control."
fi

# 检查BBR是否启用
echo "Checking if BBR is enabled..."
if lsmod | grep -q bbr && sysctl net.ipv4.tcp_available_congestion_control | grep -q bbr; then
    echo "BBR is enabled."
else
    echo "BBR might not be properly enabled. Check the configuration."
fi

# 安装lrzsz
echo "Installing lrzsz..."
if command -v yum &> /dev/null; then
    yum install -y lrzsz
elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y lrzsz
else
    echo "Unsupported package manager. Please install lrzsz manually."
fi

echo "Script execution completed."
