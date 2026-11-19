#!/bin/bash

echo "alias m='bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/ssh.sh)'" > ~/.bashrc && source ~/.bashrc

while true; do
    clear
    echo "  MY VPS"
    echo "=========="
    echo " 1. vps"
    echo " 2. apt"
    echo " 3. opt"
    echo " 4. bbr"
    echo " 5. dns"
    echo " 6. hy2"
    echo " 7. ss"
    echo " 8. rb"
    echo " 9. ook"
    echo "=========="
    echo " 0. exit "
    echo "=========="
    read -p " Pick: " choice

    case $choice in
        1)
            ipv4=$(hostname -I | awk '{print $1}')
            ipv6=$(hostname -I | tr ' ' '\n' | grep ':' | head -n 1)
            cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
            cpu_arch=$(uname -m);cpu_cores=$(nproc);cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')
            mem_info=$(free -b | awk 'NR==2{u=$3/1048576;t=$2/1048576;printf"%.2f/%.2f MB (%.2f%%)",u,t,u*100/t}')
            disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
            kernel_version=$(uname -r);os_info=$(lsb_release -ds 2>/dev/null || echo "Debian $(</etc/debian_version)")
            congestion=$(sysctl -n net.ipv4.tcp_congestion_control); queue=$(sysctl -n net.core.default_qdisc)
            net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "%.2f %s\n%.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
            net_down=$(echo "$net_traffic" | sed -n '1p');net_up=$(echo "$net_traffic" | sed -n '2p')
            read swap_used swap_total <<< $(free -m | awk '/Swap:/{print $3, $2}');swap_info="${swap_used}MB/${swap_total}MB ($(( swap_total ? swap_used * 100 / swap_total : 0 ))%)"
            dns_list=($(awk '/^nameserver/{print $2}' /etc/resolv.conf))
            clear
            line="------------------------------------------------------------"
            echo "$line"
            printf "%-12s%s\n" "System:"   "${os_info}"
            printf "%-12s%s\n" "Kernel:"   "${kernel_version}"
            echo "$line"
            printf "%-12s%s\n" "CPU:"      "${cpu_info}"
            printf "%-12s%s | %s | %s\n" "" "${cpu_arch}" "${cpu_cores} cores" "${cpu_freq}"
            echo "$line"
            printf "%-12s%s\n" "Memo:"     "${mem_info}"
            printf "%-12s%s\n" "Swap:"     "${swap_info}"
            printf "%-12s%s\n" "Disk:"     "${disk_info}"
            echo "$line"
            printf "%-12s%s\n" "Down:"     "${net_down}"
            printf "%-12s%s\n" "Uoop:"     "${net_up}"
            echo "$line"
            printf "%-12s%s %s\n" "BBR:"   "${congestion}" "${queue}"
            echo "$line"
            printf "%-12s%s\n" "IPv4:"     "${ipv4}"
            printf "%-12s%s\n" "IPv6:"     "${ipv6}"
            echo "$line"
            printf "%-12s%s\n" "DNS:" "${dns_list[0]}"
            for d in "${dns_list[@]:1}"; do printf "%-12s%s\n" "" "$d"; done
            echo "$line"
            read -n 1 -s -r -p ""
            echo ""
            ;;
        2)
            clear
            apt update && apt upgrade -y
            apt autoremove --purge -y && apt clean && apt autoclean
            apt install -y curl wget unzip sudo ufw openssl
            echo "ok！"
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
            echo "BBR+FQ is OK！"
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
            : >/etc/resolv.conf
            for i in $dns; do echo "nameserver $i" >> /etc/resolv.conf; done
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
            echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 2001:4860:4860::8888\nnameserver 2001:4860:4860::8844" > /etc/resolv.conf
            echo "BBR+FQ+DNS is OK！"
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
