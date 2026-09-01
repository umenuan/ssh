#!/bin/bash

re='\e[0m'; red='\e[1;31m'; white='\e[1;30m'; green='\e[1;32m'; yellow='\e[1;33m'; purple='\e[1;35m'; skyblue='\e[1;34m'

while true; do
    clear
    echo -e "${skyblue}  MY VPS${re}"
    echo "=========="
    echo -e "${green} 1. vps"
    echo -e "${green} 2. apt"
    echo -e "${green} 3. opt"
    echo -e "${green} 4. bbr"
    echo -e "${green} 5. dns"
    echo -e "${green} 6. hy2"
    echo -e "${green} 7. ss"
    echo -e "${green} 8. rb"
    echo -e "${green} 9. ok"
    echo "=========="
    echo -e "${green} 0. exit ${re}"
    echo "=========="
    read -p $'\033[1;91m Pick: \033[0m' choice

    case $choice in
        1)
            clear
            ipv4=$(curl -s ipv4.ip.sb);ipv6=$(curl -s ipv6.ip.sb)
            cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//');cpu_cores=$(nproc);cpu_arch=$(uname -m)
            cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')
            mem_info=$(free -b | awk 'NR==2{u=$3/1048576;t=$2/1048576;printf"%.2f/%.2f MB (%.2f%%)",u,t,u*100/t}')
            disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
            ipinfo=$(curl -s ipinfo.io);country=$(echo "$ipinfo" | awk -F\" '/country/{print $4}');city=$(echo "$ipinfo" | awk -F\" '/city/{print $4}');isp_info=$(echo "$ipinfo" | awk -F\" '/org/{print $4}')
            hostname=$(hostname);kernel_version=$(uname -r)
            congestion=$(sysctl -n net.ipv4.tcp_congestion_control);queue=$(sysctl -n net.core.default_qdisc)
            os_info=$(lsb_release -ds 2>/dev/null || echo "Debian $(</etc/debian_version)")
            net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "dd: %.2f %s\nup: %.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
            read swap_used swap_total <<< $(free -m | awk '/Swap:/{print $3, $2}');swap_info="${swap_used}MB/${swap_total}MB";swap_info+=" ($(( swap_total ? swap_used * 100 / swap_total : 0 ))%)"
            dns=$(awk '/^nameserver/{printf "%s ", $2} END {print ""}' /etc/resolv.conf)
            loadavg=$(awk '{print $1, $2, $3}' /proc/loadavg)
            tcp=$(ss -t | wc -l) && udp=$(ss -u | wc -l)
            current_time=$(date "+%Y-%m-%d %H:%M:%S")  && runtime=$(uptime -p)
            echo ""
            echo -e "${white}hostname: ${purple}${hostname}${re}"
            echo -e "${white}asninfo: ${purple}${isp_info}${re}"
            echo ""
            echo -e "${white}system: ${purple}${os_info}${re}"
            echo -e "${white}kernel: ${purple}${kernel_version}${re}"
            echo ""
            echo -e "${white}cpu_arch: ${purple}${cpu_arch}${re}"
            echo -e "${white}cpu_info: ${purple}${cpu_info}${re}"
            echo -e "${white}cpu_cores: ${purple}${cpu_cores}${re}"
            echo -e "${white}cpu_freq: ${purple}${cpu_freq}${re}"
            echo ""
            echo -e "${white}tcp|udp: ${purple}${tcp}|${udp}${re}"
            echo ""
            echo -e "${white} mem: ${purple}${mem_info}${re}"
            echo -e "${white}swap: ${purple}${swap_info}${re}"
            echo -e "${white}disk: ${purple}${disk_info}${re}"
            echo -e "${white}load: ${purple}${loadavg}${re}"
            echo ""
            echo -e "${purple}$net_traffic${re}"
            echo ""
            echo -e "${white}bbr: ${purple}${congestion} ${queue}${re}"
            echo ""
            echo -e "${white}ipv4: ${purple}${ipv4}${re}"
            echo -e "${white}ipv6: ${purple}${ipv6}${re}"
            echo ""
            echo -e "${white}city: ${purple}${country} $city${re}"
            echo -e "${white}time: ${purple}${current_time}${re}"
            echo ""          
            echo -e "${white}dns: ${purple}${dns}${re}"
            echo ""
            echo -e "${purple}${runtime}${re}"
            echo ""
            echo -e "${yellow}ok...${re}"
            read -n 1 -s -r -p ""
            echo ""
            ;;
        2)
            clear
            echo -e "${yellow}apt...${re}"
            apt update && apt upgrade -y
            apt autoremove --purge -y && apt clean && apt autoclean
            apt install -y curl wget unzip sudo ufw openssl
            echo -e "${green}ok！${re}"
            read -n 1 -s -r -p ""
            ;;
        3)
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/opt.sh)
            read -n 1 -s -r -p ""
            ;;
        4)
            clear
            echo "net.core.default_qdisc=fq" > /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl --system >/dev/null 2>&1
            sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
            echo -e "${green}BBR+FQ is OK！${re}"
            read -n 1 -s -r -p ""
            ;;
        5)
            echo -e "1) Cloudflare\n2) Google"
            read -rp "Pick [1-2]: " c
            case $c in
            1) dns="1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001";;
            2) dns="8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844";;
            *) exit 1;;
            esac
            chattr -i /etc/resolv.conf
            : >/etc/resolv.conf
            for i in $dns; do echo "nameserver $i" >> /etc/resolv.conf; done
            chattr +i /etc/resolv.conf
            cat /etc/resolv.conf
            read -n 1 -s -r -p ""
            ;;
        6)
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/hy2.sh)
            read -n 1 -s -r -p ""
            ;;
        7)
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/ss.sh)
            read -n 1 -s -r -p ""
            ;;       
        8)
            reboot
            ;;
        9)
            echo "net.core.default_qdisc=fq" > /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl --system >/dev/null 2>&1
            chattr -i /etc/resolv.conf
            echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 2001:4860:4860::8888\nnameserver 2001:4860:4860::8844" > /etc/resolv.conf
            chattr +i /etc/resolv.conf
            echo -e "${green}BBR+FQ+DNS is OK！${re}"
            read -n 1 -s -r -p ""
            ;;
        0)
            clear
            exit
            ;;
        *)
            ;;
    esac
done
