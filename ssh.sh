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
            ipv4=$(curl -s ipv4.ip.sb); ipv6=$(curl -s ipv6.ip.sb)
            cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
            cpu_cores=$(nproc); cpu_arch=$(uname -m)
            cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')
            mem_info=$(free -b | awk 'NR==2{u=$3/1048576;t=$2/1048576;printf"%.2f/%.2f MB (%.2f%%)",u,t,u*100/t}')
            disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
            kernel_version=$(uname -r)
            congestion=$(sysctl -n net.ipv4.tcp_congestion_control); queue=$(sysctl -n net.core.default_qdisc)
            os_info=$(lsb_release -ds 2>/dev/null || echo "Debian $(</etc/debian_version)")
            net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "%.2f %s\n%.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
            net_down=$(echo "$net_traffic" | sed -n '1p')
            net_up=$(echo "$net_traffic" | sed -n '2p')
            read swap_used swap_total <<< $(free -m | awk '/Swap:/{print $3, $2}')
            swap_info="${swap_used}MB/${swap_total}MB ($(( swap_total ? swap_used * 100 / swap_total : 0 ))%)"
            dns_list=($(awk '/^nameserver/{print $2}' /etc/resolv.conf))

            clear
            line="${white}------------------------------------------------------------${re}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "System:"   "${os_info}"
            printf "${white}%-12s${purple}%s${re}\n" "Kernel:"   "${kernel_version}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "CPU:"      "${cpu_info}"
            printf "${white}%-12s${purple}%s | %s | %s${re}\n" "" "${cpu_arch}" "${cpu_cores} cores" "${cpu_freq}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "Memo:"   "${mem_info}"
            printf "${white}%-12s${purple}%s${re}\n" "Swap:"     "${swap_info}"
            printf "${white}%-12s${purple}%s${re}\n" "Disk:"     "${disk_info}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "Down:"     "${net_down}"
            printf "${white}%-12s${purple}%s${re}\n" "Up:"       "${net_up}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s %s${re}\n" "BBR:"    "${congestion}" "${queue}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "IPv4:"     "${ipv4}"
            printf "${white}%-12s${purple}%s${re}\n" "IPv6:"     "${ipv6}"
            echo -e "$line"
            printf "${white}%-12s${purple}%s${re}\n" "DNS:" "${dns_list[0]}"
            for d in "${dns_list[@]:1}"; do printf "${white}%-12s${purple}%s${re}\n" "" "$d"; done
            echo -e "$line"
            uptime
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
