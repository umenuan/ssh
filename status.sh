#!/bin/bash

while true; do
    clear
    echo "===== 探针管理 ====="
    echo "1) 安装哪吒 (Nezha)"
    echo "2) 卸载哪吒 (Nezha)"
    echo "3) 安装 Komari"
    echo "4) 卸载 Komari"
    echo "5) 退出脚本"
    echo "======================="
    read -p "请输入选项 (1-5): " choice

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
            echo "退出脚本..."
            exit 0
            ;;
        *)
            echo "无效输入，请重新选择。"
            ;;
    esac

    read -p "按回车键继续..."
done
