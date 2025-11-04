#!/bin/bash
export LANG=en_US.UTF-8

# 定义颜色
re='\e[0m'
red='\e[1;91m'
white='\e[1;97m'
green='\e[1;32m'
yellow='\e[1;33m'
purple='\e[1;35m'
skyblue='\e[1;96m'

# 仅允许root用户运行
[[ $EUID -ne 0 ]] && echo -e "${red}请在root用户下运行脚本${re}" && exit 1

# 获取IPv4和IPv6
ip_address() {
    ipv4_address=$(curl -s -m 2 ipv4.ip.sb)
    ipv6_address=$(curl -s -m 2 ipv6.ip.sb)
}


while true; do
    clear
    echo -e "${skyblue} VPS详细信息${re}"
    echo "-----------------"
    echo -e "${green} 1. 本机信息"
    echo -e "${green} 2. 系统更新"
    echo -e "${green} 3. BBR管理"
    echo -e "${green} 4. HY2管理"
    echo -e "${green} 5. HY2-IPV6"
    echo -e "${green} 6. vless+ws"
    echo "-----------------"
    echo -e "${green} 0. 退出脚本${re}"
    echo "-----------------"
    read -p $'\033[1;91m请输入你的选择: \033[0m' choice

    case $choice in
        1)
            clear
            ip_address
            cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
            cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
            cpu_usage_percent=$(printf "%.2f" "$cpu_usage")%
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
            runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d小时 ", run_hours); if (run_minutes > 0) printf("%d分钟", run_minutes); }')

            echo ""
            echo -e "${white}系统信息详情${re}"
            echo "------------------------"
            echo -e "${white}主机名: ${purple}${hostname}${re}"
            echo -e "${white}运营商: ${purple}${isp_info}${re}"
            echo "------------------------"
            echo -e "${white}系统版本: ${purple}${os_info}${re}"
            echo -e "${white}Linux内核: ${purple}${kernel_version}${re}"
            echo "------------------------"
            echo -e "${white}CPU架构: ${purple}${cpu_arch}${re}"
            echo -e "${white}CPU型号: ${purple}${cpu_info}${re}"
            echo -e "${white}CPU核心数: ${purple}${cpu_cores}${re}"
            echo "------------------------"
            echo -e "${white}CPU占用: ${purple}${cpu_usage_percent}${re}"
            echo -e "${white}物理内存: ${purple}${mem_info}${re}"
            echo -e "${white}虚拟内存: ${purple}${swap_info}${re}"
            echo -e "${white}硬盘占用: ${purple}${disk_info}${re}"
            echo "------------------------"
            echo -e "${purple}$output${re}"
            echo "------------------------"
            echo -e "${white}网络拥堵算法: ${purple}${congestion_algorithm} ${queue_algorithm}${re}"
            echo "------------------------"
            echo -e "${white}公网IPv4地址: ${purple}${ipv4_address}${re}"
            echo -e "${white}公网IPv6地址: ${purple}${ipv6_address}${re}"
            echo "------------------------"
            echo -e "${white}地理位置: ${purple}${country} $city${re}"
            echo -e "${white}系统时间: ${purple}${current_time}${re}"
            echo "------------------------"
            echo -e "${white}系统运行时长: ${purple}${runtime}${re}"
            echo ""
            echo -e "${yellow}按任意键返回...${re}"
            read -n 1 -s -r -p ""
            echo ""
            ;;
        2)
            clear
            echo -e "${yellow}正在更新系统...${re}"
            apt update && apt upgrade -y
            apt install -y curl wget unzip sudo
            apt autoremove -y
            echo -e "${green}系统更新完成！${re}"
            echo -e "${yellow}按任意键返回...${re}"
            read -n 1 -s -r -p ""
            echo ""
            ;;
        0)
            clear
            exit
            ;;
        *)
            echo -e "${purple}无效的输入!${re}"
            sleep 1
            ;;
    esac
done
