#!/bin/bash

while true
do
    clear

    echo "================================"
    echo "       Debian 系统查询工具"
    echo "================================"
    echo "1. 系统信息"
    echo "2. CPU内存"
    echo "3. 磁盘空间"
    echo "4. 目录占用"
    echo "5. 进程"
    echo "6. 实时监控"
    echo "7. 网络信息"
    echo "8. 监听端口"
    echo "9. 服务状态"
    echo "10. 系统日志"
    echo "0. 退出"
    echo "================================"

    read -p "请选择 [0-10]: " n

    case $n in

    1)
        hostnamectl
        uptime
        uname -r
        ;;

    2)
        echo "===== CPU ====="
        lscpu | grep -E "CPU\(s\)|Model name"
        echo
        echo "===== 内存 ====="
        free -h
        ;;

    3)
        df -hT
        echo
        lsblk
        ;;

    4)
        read -p "目录 [默认 /var]: " dir
        dir=${dir:-/var}
        du -xh --max-depth=1 "$dir" 2>/dev/null | sort -h
        ;;

    5)
        echo "===== CPU 占用 ====="
        ps aux --sort=-%cpu | head
        echo
        echo "===== 内存占用 ====="
        ps aux --sort=-%mem | head
        ;;

    6)
        top
        ;;

    7)
        echo "===== IP ====="
        ip -br addr
        echo
        echo "===== 路由 ====="
        ip route
        ;;

    8)
        ss -lntup
        ;;

    9)
        read -p "服务名称: " service
        systemctl status "$service" --no-pager
        ;;

    10)
        journalctl -n 50 --no-pager
        ;;

    0)
        echo "退出"
        exit 0
        ;;

    *)
        echo "无效选项"
        ;;

    esac

    echo
    read -p "按 Enter 返回菜单..." _
done
