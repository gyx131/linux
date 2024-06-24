#!/bin/bash

# 定义变量
INTERFACE="eth0"  # 修改为你的网络接口名称
LIMIT_PORT="80"  # 限制的目标端口号
LIMIT_SPEED="0.1Mbit"  # 针对目标端口的限速设置
WHITE_LIST_IP=("192.168.1.2" "192.168.1.3")  # 白名单IP数组，按需添加

# 清理之前的设置
#sudo iptables -t mangle -F
#sudo tc qdisc del dev $INTERFACE root &> /dev/null

# 设置针对TCP端口6999的限速
sudo tc qdisc add dev $INTERFACE root handle 1: htb default 20
sudo tc class add dev $INTERFACE parent 1: classid 1:1 htb rate $LIMIT_SPEED ceil $LIMIT_SPEED
sudo tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 u32 match ip protocol 6 0xff match ip dport $LIMIT_PORT 0xffff flowid 1:1

# 为端口6999添加流量过滤规则，但先跳过白名单检查
sudo tc filter add dev $INTERFACE protocol ip parent 1:0 prio 2 u32 match ip dport $LIMIT_PORT 0xffff flowid 1:2 return
# 默认规则，允许其他非6999端口的流量
sudo tc filter add dev $INTERFACE protocol ip parent 1:0 prio 3 u32 match ip protocol 0xff flowid 1:2

# 添加白名单规则，对白名单中的IP不做端口6999的流量限制
for IP in "${WHITE_LIST_IP[@]}"; do
    echo "Adding white list rule for IP: $IP"
    sudo iptables -t mangle -A PREROUTING -s $IP -j MARK --set-mark 2
    sudo tc filter add dev $INTERFACE protocol ip parent 1:0 prio 7 u32 match mark 2 flowid 1:2
done

echo "TCP port $LIMIT_PORT traffic limited to $LIMIT_SPEED per IP except for whitelisted IPs. Other traffic is unlimited."

# 注意：此脚本为示例，使用前请在测试环境中验证。
