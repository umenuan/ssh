#!/bin/bash

while true; do
    clear
    echo "================="
    echo " 1) 安装 Nezha"
    echo " 2) 安装 Komari"
    echo " 3) 安装 3X-UI"
    echo " 4) 安装 1Panel"
    echo " 5) 安装 Docker"
    echo " 6) 安装 Debian"
    echo " 7) 安装 Warp"
    echo " 8) 测试 NQ"
    echo " 0) 退出脚本"
    echo "================="
    read -p "Pick : " choice

    case $choice in
        1)
            curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
            ;;
        2)
            curl -fsSL https://raw.githubusercontent.com/komari-monitor/komari/main/install-komari.sh -o install-komari.sh && chmod +x install-komari.sh && sudo ./install-komari.sh
            ;;
        3)
            bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
            ;; 
        4)
            bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"           
            ;;
        5)
            curl -fsSL https://get.docker.com | sudo sh           
            ;;
        6)
            bash <(curl -Ls https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh) debian --ssh-key "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmhMiWBMLsvwLJY2X6qkCm+Lm/tEOu4SCH+/ujMw9oO"
            ;;
        7)
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
            ;;
        8)
            bash <(curl -sL https://run.NodeQuality.com)
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
