#!/bin/bash

re='\e[0m'; red='\e[1;91m'; white='\e[1;97m'; green='\e[1;32m'; yellow='\e[1;33m'; purple='\e[1;35m'; skyblue='\e[1;96m'

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
    echo -e "${green} 8. sb"
    echo -e "${green} 9. NQ"
    echo "=========="
    echo -e "${green} 0. Exit ${re}"
    echo "=========="
    read -p $'\033[1;91m Pick: \033[0m' choice

    case $choice in
        1)
            clear
            ipv4=$(curl -s ipv4.ip.sb)
            ipv6=$(curl -s ipv6.ip.sb)
            cpu_info=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')
            cpu_usage=$(awk '{u=$2+$3+$4+$6+$7+$8;t=u+$5;if(NR==1){u1=u;t1=t}else printf"%.2f%%\n",(u-u1)*100/(t-t1)}' <(grep '^cpu ' /proc/stat) <(sleep 1;grep '^cpu ' /proc/stat))
            cpu_cores=$(nproc);virt=$(systemd-detect-virt)
            cpu_freq=$(cat /proc/cpuinfo | grep "MHz" | head -n 1 | awk '{printf "%.1f GHz\n", $4/1000}')
            mem_info=$(free -b | awk 'NR==2{u=$3/1048576;t=$2/1048576;printf"%.2f/%.2f MB (%.2f%%)",u,t,u*100/t}')
            disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
            ipinfo=$(curl -s ipinfo.io);country=$(echo "$ipinfo" | awk -F\" '/country/{print $4}');city=$(echo "$ipinfo" | awk -F\" '/city/{print $4}');isp_info=$(echo "$ipinfo" | awk -F\" '/org/{print $4}')
            hostname=$(hostname);cpu_arch=$(uname -m);kernel_version=$(uname -r)
            congestion=$(sysctl -n net.ipv4.tcp_congestion_control);queue=$(sysctl -n net.core.default_qdisc)
            os_info=$(lsb_release -ds 2>/dev/null || echo "Debian $(</etc/debian_version)")
            net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "下载: %.2f %s\n上传: %.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
            read swap_used swap_total <<< $(free -m | awk '/Swap:/{print $3, $2}');swap_info="${swap_used}MB/${swap_total}MB";swap_info+=" ($(( swap_total ? swap_used * 100 / swap_total : 0 ))%)"
            dns=$(awk '/^nameserver/{printf "%s ", $2} END {print ""}' /etc/resolv.conf)
            loadavg=$(awk '{print $1, $2, $3}' /proc/loadavg)
            tcp=$(ss -t | wc -l) && udp=$(ss -u | wc -l)
            current_time=$(date "+%Y-%m-%d %H:%M:%S")  && runtime=$(uptime -p)
            echo ""
            echo -e "${white}详细信息${re}"
            echo "========"
            echo -e "${white}虚拟化: ${purple}${virt}${re}"
            echo -e "${white}主机名: ${purple}${hostname}${re}"
            echo -e "${white}运营商: ${purple}${isp_info}${re}"
            echo "------------------------"
            echo -e "${white}系统版本: ${purple}${os_info}${re}"
            echo -e "${white}内核版本: ${purple}${kernel_version}${re}"
            echo "------------------------"
            echo -e "${white}CPU架构: ${purple}${cpu_arch}${re}"
            echo -e "${white}CPU型号: ${purple}${cpu_info}${re}"
            echo -e "${white}CPU核心: ${purple}${cpu_cores}${re}"
            echo -e "${white}CPU频率: ${purple}${cpu_freq}${re}"
            echo -e "${white}CPU占用: ${purple}${cpu_usage}${re}"
            echo "------------------------"
            echo -e "${white}TCP|UDP: ${purple}${tcp}|${udp}${re}"
            echo "------------------------"
            echo -e "${white}物理内存: ${purple}${mem_info}${re}"
            echo -e "${white}虚拟内存: ${purple}${swap_info}${re}"
            echo -e "${white}硬盘占用: ${purple}${disk_info}${re}"
            echo -e "${white}系统负载: ${purple}${loadavg}${re}"
            echo "------------------------"
            echo -e "${purple}$net_traffic${re}"
            echo "------------------------"
            echo -e "${white}调度: ${purple}${congestion} ${queue}${re}"
            echo "------------------------"
            echo -e "${white}IPv4: ${purple}${ipv4}${re}"
            echo -e "${white}IPv6: ${purple}${ipv6}${re}"
            echo "------------------------"
            echo -e "${white}地理位置: ${purple}${country} $city${re}"
            echo -e "${white}系统时间: ${purple}${current_time}${re}"
            echo "------------------------"
            echo -e "${white}DNS: ${purple}${dns}${re}"
            echo "------------------------"
            echo -e "${purple}${runtime}${re}"
            echo ""
            echo -e "${yellow}按任意键返回...${re}"
            read -n 1 -s -r -p ""
            echo ""
            ;;
        2)
            clear
            echo -e "${yellow}正在更新...${re}"
            apt update && apt upgrade -y
            apt autoremove -y && apt autoclean -y
            apt install -y curl wget unzip sudo ufw openssl
            echo -e "${green}更新完成！${re}"
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
            echo -e "${green}BBR+FQ OK！${re}"
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
            clear
            bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/sb.sh)
            read -n 1 -s -r -p ""
            ;;
        9)
            clear
            bash <(curl -sL https://run.NodeQuality.com)
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
