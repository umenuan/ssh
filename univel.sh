#!/bin/bash

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
    echo -e "${skyblue}  MY VPS${re}"
    echo "-----------------"
    echo -e "${green} 1. Info"
    echo -e "${green} 2. Apt"
    echo -e "${green} 3. Panel"
    echo -e "${green} 4. BBR"
    echo -e "${green} 5. HY2-V4"
    echo -e "${green} 6. HY2-V6"
    echo -e "${green} 7. Vless+ws"
    echo -e "${green} 8. Reinstall"
    echo -e "${green} 9. WARP IPv4"
    echo -e "${green} 10.NodeQuality"
    echo "-----------------"
    echo -e "${green} 0. Exit ${re}"
    echo "-----------------"
    read -p $'\033[1;91m请选择: \033[0m' choice

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
            net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "总接收: %.2f %s\n总发送: %.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
            current_time=$(date "+%Y-%m-%d %I:%M %p")
            read swap_used swap_total <<< $(free -m | awk '/Swap:/{print $3, $2}')
            swap_info="${swap_used}MB/${swap_total}MB"
            swap_info+=" ($(( swap_total ? swap_used * 100 / swap_total : 0 ))%)"
            runtime=$(uptime -p)
            echo ""
            echo -e "${white}系统信息${re}"
            echo "------------------------"
            echo -e "${white}主机名: ${purple}${hostname}${re}"
            echo -e "${white}运营商: ${purple}${isp_info}${re}"
            echo "------------------------"
            echo -e "${white}系统版本: ${purple}${os_info}${re}"
            echo -e "${white}Linux内核: ${purple}${kernel_version}${re}"
            echo "------------------------"
            echo -e "${white}CPU架构: ${purple}${cpu_arch}${re}"
            echo -e "${white}CPU型号: ${purple}${cpu_info}${re}"
            echo -e "${white}CPU核心: ${purple}${cpu_cores}${re}"
            echo "------------------------"
            echo -e "${white}CPU占用: ${purple}${cpu_usage_percent}${re}"
            echo -e "${white}物理内存: ${purple}${mem_info}${re}"
            echo -e "${white}虚拟内存: ${purple}${swap_info}${re}"
            echo -e "${white}硬盘占用: ${purple}${disk_info}${re}"
            echo "------------------------"
            echo -e "${purple}$net_traffic${re}"
            echo "------------------------"
            echo -e "${white}网络拥堵算法: ${purple}${congestion_algorithm} ${queue_algorithm}${re}"
            echo "------------------------"
            echo -e "${white}IPv4地址: ${purple}${ipv4_address}${re}"
            echo -e "${white}IPv6地址: ${purple}${ipv6_address}${re}"
            echo "------------------------"
            echo -e "${white}地理位置: ${purple}${country} $city${re}"
            echo -e "${white}系统时间: ${purple}${current_time}${re}"
            echo "------------------------"
            echo -e "${white}运行时长: ${purple}${runtime}${re}"
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
        3)
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/panel.sh)
            echo -e "${green}执行完成！返回主菜单...${re}"
            read -n 1 -s -r -p ""
            ;;
        4)
            clear
            echo -e "${yellow}正在开启BBR...${re}"
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/bbr.sh)
            echo -e "${green}执行完成！返回主菜单...${re}"
            read -n 1 -s -r -p ""
            ;;
        5)
            clear
            echo -e "${yellow}正在运行HY2-V4脚本...${re}"
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/hy2.sh)
            echo -e "${green}执行完成！返回主菜单...${re}"
            read -n 1 -s -r -p ""
            ;;
        6)
            clear
            echo -e "${yellow}正在运行HY2-V6脚本...${re}"
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/hy6.sh)
            echo -e "${green}执行完成！返回主菜单...${re}"
            read -n 1 -s -r -p ""
            ;;
        7)
            clear
            echo -e "${yellow}正在运行vless+ws脚本...${re}"
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/vless.sh)
            echo -e "${green}执行完成！返回主菜单...${re}"
            read -n 1 -s -r -p ""
            ;;
         8)
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) debian 13
            ;;
         9)
            clear
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh 4
            ;;
         10)
            clear
            bash <(curl -sL https://run.NodeQuality.com)
            ;;
        0)
            clear
            exit
            ;;
        *)
            echo -e "${purple}无效输入!${re}"
            sleep 1
            ;;
    esac
done
