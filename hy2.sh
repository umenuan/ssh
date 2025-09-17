#!/bin/bash
# Debian/Ubuntu 一键管理 Hysteria2 

set -euo pipefail

# 常量定义
BIN="/usr/local/bin/hysteria"
CONF_DIR="/etc/hysteria"
CONF_FILE="${CONF_DIR}/config.yaml"
CERT_FILE="${CONF_DIR}/cert.pem"
KEY_FILE="${CONF_DIR}/key.pem"
UNIT_FILE="/etc/systemd/system/hysteria2.service"
NODE_FILE="${CONF_DIR}/node.txt"
SERVICE_NAME="hysteria2.service"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 依赖检查
check_deps() {
    local deps=("curl" "openssl" "ufw")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${YELLOW}正在安装依赖: $dep...${NC}"
            apt update -y && apt install -y "$dep"
            clear
        fi
    done
}

# 随机生成端口密码
rand_port() { shuf -i 20000-60000 -n 1; }
rand_hex() { openssl rand -hex 16; }

# 获取公网IP
get_pub_ip() {
    local ip=""
    ip=$(curl -4fsS --max-time 4 https://ipv4.icanhazip.com || true)
    [[ -z "$ip" ]] && ip=$(curl -4fsS --max-time 4 https://ifconfig.me || true)
    [[ -z "$ip" ]] && ip=$(ip -4 addr show scope global | awk '/inet /{sub("/.*","",$2); print $2; exit}')
    echo "${ip//[[:space:]]/}"
}

# 安装Hysteria2
do_install() {
    check_deps

    echo -e "${GREEN}>>> 正在安装/更新 Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/)

    mkdir -p "$CONF_DIR"

    # 生成自签证书
    if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
        echo -e "${GREEN}>>> 生成自签证书...${NC}"
        openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
          -keyout "$KEY_FILE" -out "$CERT_FILE" \
          -subj "/CN=hy2.local" 2>/dev/null
        chmod 600 "$KEY_FILE"
    fi

    # 交互式配置
    local PORT PASS
    PORT=$(rand_port)
    PASS=$(rand_hex)

    read -rp "请输入服务器端口 [默认: $PORT]: " input_port
    PORT=${input_port:-$PORT}
    read -rp "请输入服务器密码 [默认: $PASS]: " input_pass
    PASS=${input_pass:-$PASS}

    # 写入配置文件
    cat > "$CONF_FILE" <<EOF
listen: ":${PORT}"

auth:
  type: password
  password: "${PASS}"

tls:
  cert: "${CERT_FILE}"
  key: "${KEY_FILE}"

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
    rewriteHost: true
EOF

   # 配置systemd服务
    cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
Type=simple
ExecStart=$BIN server -c $CONF_FILE
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME"

    # 防火墙规则
    ufw allow "$PORT/udp" >/dev/null 2>&1

    # 生成节点信息
    local IP NAME LINK
    IP=$(get_pub_ip)
    NAME="HY2-${IP}"
    LINK="hysteria2://${PASS}@${IP}:${PORT}?insecure=1"
    LINK+="#${NAME}"
    echo "$LINK" | tee "$NODE_FILE"

    echo -e "${GREEN}\n=== 安装完成 ===${NC}"
    echo -e "配置文件: ${YELLOW}$CONF_FILE${NC}"
    echo -e "节点链接: ${YELLOW}$LINK${NC}"
    echo -e "已保存到: ${YELLOW}$NODE_FILE${NC}"
}

# 彻底卸载
do_uninstall() {
    echo -e "${RED}>>> 正在卸载 Hysteria2...${NC}"

    # 停止服务
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
    fi

    # 禁用服务
    if systemctl is-enabled --quiet "$SERVICE_NAME"; then
        systemctl disable "$SERVICE_NAME"
    fi

    # 删除服务文件
    if [[ -f "$UNIT_FILE" ]]; then
        rm -f "$UNIT_FILE"
        systemctl daemon-reload
    fi

    # 杀死残留进程
    pkill -9 -f "hysteria server" 2>/dev/null || true

    # 删除配置文件
    [[ -d "$CONF_DIR" ]] && rm -rf "$CONF_DIR"

    # 调用官方卸载
    bash <(curl -fsSL https://get.hy2.sh/) --remove >/dev/null 2>&1

    # 清理防火墙规则
    if [[ -f "$CONF_FILE" ]]; then
        local PORT
        PORT=$(grep "listen:" "$CONF_FILE" | awk -F':' '{print $2}' | tr -d ' "')
        ufw delete allow "$PORT/udp" 2>/dev/null || true
    fi

    echo -e "${GREEN}>>> 卸载完成，所有文件和服务已清理！${NC}"
}

# 升级Hysteria2
do_upgrade() {
    echo -e "${GREEN}>>> 正在升级 Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/)
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    echo -e "${GREEN}>>> 升级完成！${NC}"
}

# 显示节点信息
show_node() {
    if [[ -f "$NODE_FILE" ]]; then
        echo -e "${GREEN}>>> 节点链接：${NC}"
        cat "$NODE_FILE"
    else
        echo -e "${RED}未找到节点链接，请先执行安装！${NC}"
    fi
}

# 显示菜单
show_menu() {
    clear
    echo -e "${GREEN}====== Hysteria2 一键管理脚本 ======${NC}"
    echo -e "1) 安装 Hysteria2"
    echo -e "2) 升级 Hysteria2"
    echo -e "3) 卸载 Hysteria2"
    echo -e "4) 显示节点信息"
    echo -e "5) 退出脚本"
    echo -e "${GREEN}===================================${NC}"
}

# 主函数
main() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}请使用 root 用户运行此脚本！${NC}"
        exit 1
    }

    while true; do
        show_menu
        read -rp "请输入选项 [1-5]: " option
        case $option in
            1) do_install ;;
            2) do_upgrade ;;
            3) do_uninstall ;;
            4) show_node ;;
            5) exit 0 ;;
            *) echo -e "${RED}无效选项，请重新输入！${NC}" ;;
        esac
        read -rp "按回车键继续..." _
    done
}

main
