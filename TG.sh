#!/bin/bash
export LANG=en_US.UTF-8

# Telegram 机器人参数
TG_BOT_TOKEN="你的TelegramBotToken"
TG_CHAT_ID="你的聊天ID"

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d text="$message" \
        -d parse_mode="Markdown" > /dev/null
}

# 获取IPv4和IPv6
ip_address() {
    ipv4_address=$(curl -s -m 2 ipv4.ip.sb)
    ipv6_address=$(curl -s -m 2 ipv6.ip.sb)
}

ip_address

cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
cpu_usage_percent=$(printf "%.2f%%" "$cpu_usage")
cpu_cores=$(nproc)
mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')
disk_info=$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)", $3,$2,$5}')
country=$(curl -s ipinfo.io/country)
city=$(curl -s ipinfo.io/city)
isp_info=$(curl -s ipinfo.io/org)
cpu_arch=$(uname -m)
hostname=$(hostname)
kernel_version=$(uname -r)
congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
queue_algorithm=$(sysctl -n net.core.default_qdisc)
os_info=$(lsb_release -ds 2>/dev/null)
[ -z "$os_info" ] && os_info="Debian $(cat /etc/debian_version 2>/dev/null)"

output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
    NR > 2 { rx_total += $2; tx_total += $10 }
    END {
        rx_units = "Bytes";
        tx_units = "Bytes";
        if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
        if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
        if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }
        if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
        if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
        if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }
        printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
    }' /proc/net/dev)

current_time=$(date "+%Y-%m-%d %I:%M %p")
swap_used=$(free -m | awk 'NR==3{print $3}')
swap_total=$(free -m | awk 'NR==3{print $2}')
swap_percentage=0
[ "$swap_total" -ne 0 ] && swap_percentage=$((swap_used * 100 / swap_total))
swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"
runtime=$(cat /proc/uptime | awk -F. '{
    run_days=int($1 / 86400);
    run_hours=int(($1 % 86400) / 3600);
    run_minutes=int(($1 % 3600) / 60);
    if (run_days > 0) printf("%d天 ", run_days);
    if (run_hours > 0) printf("%d小时 ", run_hours);
    if (run_minutes > 0) printf("%d分钟", run_minutes);
}')

# 组装信息为Markdown格式（转义特殊符号）
message=$(cat <<EOF
*系统信息详情*
------------------------
*主机名:* \`${hostname}\`
*运营商:* \`${isp_info}\`
------------------------
*系统版本:* \`${os_info}\`
*Linux内核:* \`${kernel_version}\`
------------------------
*CPU架构:* \`${cpu_arch}\`
*CPU型号:* \`${cpu_info}\`
*CPU核心数:* \`${cpu_cores}\`
------------------------
*CPU占用:* \`${cpu_usage_percent}\`
*物理内存:* \`${mem_info}\`
*虚拟内存:* \`${swap_info}\`
*硬盘占用:* \`${disk_info}\`
------------------------
\`${output}\`
------------------------
*网络拥堵算法:* \`${congestion_algorithm} ${queue_algorithm}\`
------------------------
*公网IPv4地址:* \`${ipv4_address}\`
*公网IPv6地址:* \`${ipv6_address}\`
------------------------
*地理位置:* \`${country} ${city}\`
*系统时间:* \`${current_time}\`
------------------------
*系统运行时长:* \`${runtime}\`
EOF
)

send_telegram "$message"
