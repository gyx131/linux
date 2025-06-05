#!/bin/bash

# 设置颜色输出函数
red() {
    echo -e "\033[31m$1\033[0m"
}

green() {
    echo -e "\033[32m$1\033[0m"
}

yellow() {
    echo -e "\033[33m$1\033[0m"
}

# 检查内核版本并配置BBR
setup_bbr() {
    echo -e "\n$(yellow "检查内核版本并配置BBR加速...")"
    kernel_version=$(uname -r | cut -d '.' -f1-2)
    if [[ "$kernel_version" < "4.9" ]]; then
        echo "内核版本低于4.9，尝试安装BBR补丁..."
        if command -v yum &> /dev/null; then
            yum install wget -y || { red "安装wget失败"; exit 1; }
        elif command -v apt-get &> /dev/null; then
            apt-get install -y wget || { red "安装wget失败"; exit 1; }
        else
            red "不支持的包管理器，请手动安装wget"
            exit 1
        fi
        
        wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && ./bbr.sh || { 
            red "应用BBR补丁失败"
            exit 1
        }
    else
        echo "内核版本4.9或更高，直接应用BBR设置..."
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p || { red "应用sysctl设置失败"; exit 1; }
    fi

    # 检查BBR是否启用
    echo -e "\n$(yellow "检查BBR是否启用...")"
    if lsmod | grep -q bbr; then
        green "BBR模块已加载"
    else
        red "未找到BBR模块"
    fi
    sysctl net.ipv4.tcp_available_congestion_control
}

# 防火墙检查与配置
check_firewall() {
    echo -e "\n$(yellow "检查防火墙状态...")"
    if command -v iptables &> /dev/null; then
        echo -e "\niptables状态:"
        iptables -L -n --line-numbers || { red "获取iptables状态失败"; }
    else
        echo "未找到iptables"
    fi

    if command -v nft &> /dev/null && nft list ruleset &> /dev/null; then
        echo -e "\nnftables状态:"
        nft list ruleset || { red "获取nftables状态失败"; }
    else
        echo "未找到nftables"
    fi

    # 停止并禁用firewalld服务
    echo -e "\n$(yellow "停止并禁用firewalld服务...")"
    if systemctl is-active --quiet firewalld; then
        systemctl stop firewalld.service || red "Firewalld未运行或停止失败"
    fi
    if systemctl is-enabled --quiet firewalld; then
        systemctl disable firewalld.service || red "禁用firewalld失败"
    fi
}

# 安装lrzsz工具
install_lrzsz() {
    echo -e "\n$(yellow "安装lrzsz工具...")"
    if command -v yum &> /dev/null; then
        yum install -y lrzsz || red "使用yum安装lrzsz失败"
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y lrzsz || red "使用apt-get安装lrzsz失败"
    else
        echo "不支持的包管理器，请手动安装lrzsz"
    fi
}

# 安装和配置frps
install_frps() {
    # 定义变量
    FRPS_URL="https://jyxz2.jianyiys.xyz:30060/down/vkJEgBtFRpKs"
    CONFIG_URL="https://jyxz2.jianyiys.xyz:30060/down/IQrPlBJqDhnL.ini"  # 新配置文件链接
    CHECK_URL="https://jx2.1234clgwangdizhi.store:6999/test.php"
    TIMEOUT=20

    echo -e "\n$(yellow "开始安装frps服务...")"
    
    # 检查是否为 root 用户
    if [ "$EUID" -ne 0 ]; then
        red "请以 root 身份运行脚本"
        exit 1
    fi

    # 安装依赖（如果需要）
    if command -v apt-get &> /dev/null; then
        apt-get update -y
        apt-get install -y wget systemd
    elif command -v yum &> /dev/null; then
        yum install -y wget systemd
    else
        red "不支持的包管理器，无法安装必要依赖"
        exit 1
    fi

    # 创建 frps 目录
    mkdir -p /usr/local/frps
    cd /usr/local/frps

    # 下载 frps 程序
    echo -e "\n$(yellow "下载frps程序...")"
    wget -O frps "$FRPS_URL" && chmod +x frps || { 
        red "下载frps程序失败"
        exit 1
    }

    # 下载配置文件
    echo -e "\n$(yellow "下载frps配置文件...")"
    wget -O frps.ini "$CONFIG_URL" || {
        red "下载配置文件失败，使用默认配置"
        CONFIG_CONTENT="[common]
token = 13197833486525086574abc
bind_port = 17299
kcp_bind_port = 17299"
        echo "$CONFIG_CONTENT" > frps.ini
    }
    green "frps配置文件已准备好"

    # 创建 systemd 服务文件
    echo -e "\n$(yellow "配置systemd服务...")"
    cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=frps service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/frps/frps -c /usr/local/frps/frps.ini
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # 重载 systemd 并启动服务
    systemctl daemon-reload
    systemctl enable --now frps || { 
        red "启动frps服务失败"
        exit 1
    }

    # 定义检查并重启函数
    check_and_restart() {
        local content=$(timeout "$TIMEOUT"s wget -qO- "$CHECK_URL")
        if [[ ! $content =~ "nc" ]]; then
            systemctl stop frps
            sleep 3
            systemctl start frps
            echo "$(date +'%Y-%m-%d %H:%M:%S') 检测到异常，已重启 frps" >> /var/log/frps_restart.log
            red "检测到异常，已重启 frps"
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') frps 运行正常" >> /var/log/frps_restart.log
            green "frps 运行正常"
        fi
    }

    # 首次执行检查
    echo -e "\n$(yellow "执行首次健康检查...")"
    check_and_restart

    # 添加定时任务（每小时执行一次）
    echo -e "\n$(yellow "设置定时健康检查任务...")"
    (crontab -l 2>/dev/null; echo "0 * * * * /bin/bash -c 'source /etc/profile && /usr/local/frps/check_script.sh'") | crontab -

    # 创建定时检查脚本
    cat > /usr/local/frps/check_script.sh <<EOF
#!/bin/bash
source /etc/profile
check_and_restart
EOF
    chmod +x /usr/local/frps/check_script.sh

    # 开放防火墙端口（仅Debian/Ubuntu）
    if command -v ufw &> /dev/null; then
        echo -e "\n$(yellow "配置防火墙规则...")"
        # 从配置文件提取端口信息
        BIND_PORT=$(grep 'bind_port' frps.ini | awk -F'=' '{print $2}' | tr -d ' ')
        KCP_PORT=$(grep 'kcp_bind_port' frps.ini | awk -F'=' '{print $2}' | tr -d ' ')
        
        if [ -n "$BIND_PORT" ]; then
            ufw allow "$BIND_PORT"/tcp
        fi
        if [ -n "$KCP_PORT" ]; then
            ufw allow "$KCP_PORT"/udp
        fi
        ufw reload
    fi

    echo -e "\n$(green "------------------------")"
    echo -e "$(green "frps 安装及配置完成！")"
    echo -e "$(green "服务状态：$(systemctl is-active frps)")"
    echo -e "$(green "定时任务已设置：每小时检查一次")"
    echo -e "$(green "日志路径：/var/log/frps_restart.log")"
    echo -e "$(green "------------------------")"
}

# 主执行流程
echo -e "$(yellow "=====================================")"
echo -e "$(yellow "       服务器优化与frps安装脚本       ")"
echo -e "$(yellow "=====================================")"

# 执行各功能模块
setup_bbr
check_firewall
install_lrzsz
install_frps

echo -e "\n$(green "脚本执行完毕！")"