#!/bin/bash
# Debian/Ubuntu 一键管理 Hysteria2 
set -euo pipefail

CONFIG_FILE="/etc/hysteria/config.yaml"
CONFIG_DIR="/etc/hysteria"

# ===== 颜色 =====
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
RESET="\033[0m"

# ===== 图标 =====
OK="${GREEN}✔${RESET}"
ERR="${RED}✘${RESET}"
INFO="${BLUE}➜${RESET}"

# ===== 获取配置 =====
get_port() {
    grep listen ${CONFIG_FILE} 2>/dev/null | awk -F: '{print $NF}'
}

get_password() {
    grep password ${CONFIG_FILE} 2>/dev/null | awk '{print $2}'
}

# ===== 状态 =====
status_hy2() {
    echo -e "${BLUE}==== 状态信息 ====${RESET}"

    if ! systemctl list-unit-files | grep -q hysteria-server; then
        echo -e "${ERR} 未安装"
        return
    fi

    if systemctl is-active --quiet hysteria-server; then
        echo -e "${OK} 服务状态: 运行中"
    else
        echo -e "${ERR} 服务状态: 未运行"
    fi

    PORT=$(get_port)
    PASSWORD=$(get_password)

    echo -e "${INFO} 端口: ${YELLOW}${PORT}${RESET}"

    if ss -tuln | grep -q ":${PORT}"; then
        echo -e "${OK} 端口监听正常"
    else
        echo -e "${ERR} 端口未监听"
    fi

    UPTIME=$(systemctl show hysteria-server --property=ActiveEnterTimestamp | cut -d= -f2)
    echo -e "${INFO} 启动时间: ${UPTIME}"

    IP=$(curl -s ifconfig.me)

    echo -e "${INFO} IP: ${IP}"
    echo -e "${GREEN}连接:${RESET}"
    echo -e "${YELLOW}hysteria2://${PASSWORD}@${IP}:${PORT}/?insecure=1${RESET}"
}

# ===== 安装 =====
install_hy2() {
    echo -e "${INFO} 安装依赖..."
    apt update -y
    apt install -y curl openssl ufw

    echo -e "${INFO} 官方安装..."
    bash <(curl -fsSL https://get.hy2.sh/)

    mkdir -p ${CONFIG_DIR}

    read -p "端口(默认4433): " PORT
    PORT=${PORT:-4433}

    read -p "密码(留空自动生成): " PASSWORD
    [ -z "$PASSWORD" ] && PASSWORD=$(openssl rand -base64 12)

    echo -e "${INFO} 生成证书..."
    openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout ${CONFIG_DIR}/key.pem \
    -out ${CONFIG_DIR}/cert.pem \
    -days 3650 \
    -subj "/CN=bing.com"

    cat > ${CONFIG_FILE} <<EOF
listen: :${PORT}

tls:
  cert: ${CONFIG_DIR}/cert.pem
  key: ${CONFIG_DIR}/key.pem

auth:
  type: password
  password: ${PASSWORD}
EOF

    ufw allow ${PORT}/tcp || true
    ufw allow ${PORT}/udp || true
    ufw --force enable || true

    systemctl enable hysteria-server
    systemctl restart hysteria-server

    echo -e "${OK} 安装完成"
}

# ===== 升级 =====
upgrade_hy2() {
    echo -e "${INFO} 升级中..."
    bash <(curl -fsSL https://get.hy2.sh/)
    systemctl restart hysteria-server
    echo -e "${OK} 升级完成"
}

# ===== 卸载 =====
uninstall_hy2() {
    echo -e "${YELLOW}确认卸载？(y/n)${RESET}"
    read confirm
    [[ "$confirm" != "y" ]] && return

    bash <(curl -fsSL https://get.hy2.sh/) --remove
    rm -rf ${CONFIG_DIR}
    systemctl daemon-reload

    echo -e "${OK} 卸载完成"
}

# ===== 重启 =====
restart_hy2() {
    systemctl restart hysteria-server
    echo -e "${OK} 已重启"
}

# ===== 修改端口 =====
change_port() {
    OLD=$(get_port)
    read -p "新端口: " NEW

    sed -i "s/:${OLD}/:${NEW}/" ${CONFIG_FILE}

    ufw delete allow ${OLD}/tcp 2>/dev/null || true
    ufw delete allow ${OLD}/udp 2>/dev/null || true
    ufw allow ${NEW}/tcp
    ufw allow ${NEW}/udp

    systemctl restart hysteria-server

    echo -e "${OK} 端口已修改为 ${NEW}"
}

# ===== 修改密码 =====
change_password() {
    read -p "新密码: " NEW
    sed -i "s/password:.*/password: ${NEW}/" ${CONFIG_FILE}
    systemctl restart hysteria-server
    echo -e "${OK} 密码已修改"
}

# ===== 连通性检测 =====
check_connectivity() {
    PORT=$(get_port)
    IP=$(curl -s ifconfig.me)

    echo -e "${INFO} 检测 ${IP}:${PORT} ..."

    if timeout 3 bash -c "</dev/tcp/${IP}/${PORT}" 2>/dev/null; then
        echo -e "${OK} 端口可访问"
    else
        echo -e "${ERR} 端口不可访问"
    fi
}

# ===== 菜单 =====
menu() {
    clear
    echo -e "${BLUE}"
    echo "=================================="
    echo "     Hysteria2 管理面板"
    echo "=================================="
    echo -e "${RESET}"
    echo -e " ${GREEN}1.${RESET} 安装"
    echo -e " ${GREEN}2.${RESET} 升级"
    echo -e " ${GREEN}3.${RESET} 卸载"
    echo -e " ${GREEN}4.${RESET} 查看状态"
    echo -e " ${GREEN}5.${RESET} 重启服务"
    echo -e " ${GREEN}6.${RESET} 修改端口"
    echo -e " ${GREEN}7.${RESET} 修改密码"
    echo -e " ${GREEN}8.${RESET} 连通性检测"
    echo -e " ${GREEN}0.${RESET} 退出"
    echo ""
    read -p "请选择: " num

    case "$num" in
        1) install_hy2 ;;
        2) upgrade_hy2 ;;
        3) uninstall_hy2 ;;
        4) status_hy2 ;;
        5) restart_hy2 ;;
        6) change_port ;;
        7) change_password ;;
        8) check_connectivity ;;
        0) exit 0 ;;
        *) echo -e "${ERR} 无效输入" ;;
    esac
}

while true; do
    menu
    echo ""
    read -p "按回车继续..." temp
done
