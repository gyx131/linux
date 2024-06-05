#!/bin/bash

# 设置颜色输出函数
red() {
    echo -e "\033[31m$1\033[0m"
}

# 检查内核版本
kernel_version=$(uname -r | cut -d '.' -f1-2)
if [[ "$kernel_version" < "4.9" ]]; then
    echo "Kernel version is lower than 4.9. Installing BBR patch..."
    yum install wget -y || { red "Failed to install wget"; exit 1; }
    wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh || { red "Failed to apply BBR patch"; exit 1; }
else
    echo "Kernel version is 4.9 or higher. Applying BBR settings directly..."
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p || { red "Failed to apply sysctl settings"; exit 1; }
fi

# 检查BBR是否启用
echo "Checking if BBR is enabled..."
lsmod | grep bbr || echo "BBR module not found"
sysctl net.ipv4.tcp_available_congestion_control

# 检查iptables和nftables状态
echo -e "\nChecking firewall status:"
if command -v iptables &> /dev/null; then
    echo -e "\niptables status:"
    iptables -L -n --line-numbers || { red "Failed to get iptables status"; }
else
    echo "iptables not found"
fi

if command -v nft list ruleset &> /dev/null; then
    echo -e "\nnftables status:"
    nft list ruleset || { red "Failed to get nftables status"; }
else
    echo "nftables not found"
fi

# 停止并禁用firewalld服务（这里假设可能存在的firewalld）
echo -e "\nStopping and disabling firewalld..."
systemctl stop firewalld.service || { red "Firewalld not running or failed to stop"; }
systemctl disable firewalld.service || { red "Failed to disable firewalld"; }

# 安装lrzsz
echo -e "\nInstalling lrzsz..."
if command -v yum &> /dev/null; then
    yum install -y lrzsz || { red "Failed to install lrzsz with yum"; }
elif command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y lrzsz || { red "Failed to install lrzsz with apt-get"; }
else
    echo "Unsupported package manager. Please install lrzsz manually."
fi

echo -e "\nScript execution completed."
