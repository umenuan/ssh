#!/bin/bash

while true; do
    clear
    echo "================="
    echo "1) 安装 Nezha"
    echo "2) 卸载 Nezha Agent"
    echo "3) 安装 Komari"
    echo "4) 卸载 Komari Agent"
    echo "5) 安装 3X-UI"
    echo "6) 安装 Speedtest"
    echo "7) 安装 1Panel"
    echo "8) 切换 DNS"
    echo "0) 退出脚本"
    echo "================="
    read -p "Pick (1-5): " choice

    case $choice in
        1)
            curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
            ;;
        2)
            ./agent.sh uninstall
            ;;
        3)
            curl -fsSL https://raw.githubusercontent.com/komari-monitor/komari/main/install-komari.sh -o install-komari.sh && chmod +x install-komari.sh && sudo ./install-komari.sh
            ;;
        4)
            sudo systemctl stop komari-agent && sudo systemctl disable komari-agent && sudo rm -f /etc/systemd/system/komari-agent.service && sudo systemctl daemon-reload && sudo rm -rf /opt/komari/agent /var/log/komari
            ;;
        5)
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
            ;;
        6)
            bash <(curl -Ls https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh) && apt install speedtest -y            
            ;;     
        7)
            bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"           
            ;;
        8)
            echo -e "1) Cloudflare\n2) Google"
            read -rp "Pick [1-2]: " c
            case $c in
            1) dns="1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001";;
            2) dns="8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844";;
            *) exit 1;;
            esac
            : >/etc/resolv.conf; for i in $dns; do echo "nameserver $i" >> /etc/resolv.conf; done
            cat /etc/resolv.conf          
            ;;
        0)
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "No!"
            ;;
    esac

    read -p "按回车键继续..."
done
