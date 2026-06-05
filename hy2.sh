#!/bin/bash
set -euo pipefail

BIN=/usr/local/bin/hysteria
CONF_DIR=/etc/hysteria
CONF_FILE=$CONF_DIR/config.yaml
CERT_FILE=$CONF_DIR/cert.pem
KEY_FILE=$CONF_DIR/key.pem
UNIT_FILE=/etc/systemd/system/hysteria2.service
NODE_FILE=$CONF_DIR/node.txt
SERVICE_NAME=hysteria2.service

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';NC='\033[0m'

rand_port(){ shuf -i 20000-60000 -n1; }
rand_hex(){ openssl rand -hex 16; }

do_install(){
    echo -e "${GREEN}>>> 安装/更新 Hysteria2...${NC}"

    bash <(curl -fsSL https://get.hy2.sh/)
    mkdir -p "$CONF_DIR"

    if [[ ! -f $CERT_FILE || ! -f $KEY_FILE ]]; then
        echo -e "${GREEN}>>> 生成证书...${NC}"
        openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout "$KEY_FILE" -out "$CERT_FILE" \
        -subj "/CN=hy2.local" 2>/dev/null
        chmod 600 "$KEY_FILE"
    fi

    local PORT PASS IP LINK
    PORT=$(rand_port)
    PASS=$(rand_hex)

    read -rp "端口 [${PORT}]: " p
    PORT=${p:-$PORT}
    
    read -rp "密码 [${PASS}]: " p
    PASS=${p:-$PASS}

    cat > "$CONF_FILE" <<EOF
listen: ":$PORT"
auth:
  type: password
  password: "$PASS"
tls:
  cert: "$CERT_FILE"
  key: "$KEY_FILE"
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
    rewriteHost: true
EOF

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

    ufw allow "$PORT/udp" >/dev/null 2>&1

    IP=$(curl -4 -s https://api.ipify.org || curl -s ipv4.ip.sb)
    LINK="hysteria2://${PASS}@${IP}:${PORT}?insecure=1#HY2-${IP}"

    echo "$LINK" > "$NODE_FILE"
    
    echo -e "${GREEN}=========== 安装完成 ===========${NC}"
    echo -e "配置文件 : ${YELLOW}$CONF_FILE${NC}"
    echo -e "节点链接 : ${YELLOW}$LINK${NC}"
    echo -e "保存位置 : ${YELLOW}$NODE_FILE${NC}"
    echo -e "${GREEN}================================${NC}"
}

do_uninstall(){
    echo -e "${RED}>>> 卸载 Hysteria2...${NC}"

    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    [[ -f $CONF_FILE ]] && PORT=$(grep '^listen:' "$CONF_FILE" | grep -oE '[0-9]+')

    rm -f "$UNIT_FILE"
    systemctl daemon-reload

    pkill -9 -f "hysteria server" 2>/dev/null || true
    rm -rf "$CONF_DIR"

    bash <(curl -fsSL https://get.hy2.sh/) --remove >/dev/null 2>&1 || true

    [[ -n ${PORT:-} ]] && ufw delete allow "$PORT/udp" >/dev/null 2>&1 || true

    echo -e "${GREEN}>>> 卸载完成！${NC}"
}

do_upgrade(){
    echo -e "${GREEN}>>> 升级 Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/)
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    echo -e "${GREEN}>>> 升级完成！${NC}"
}

show_node(){
    if [[ -f $NODE_FILE ]]; then
        echo -e "${GREEN}=========== 节点信息 ===========${NC}"
        cat "$NODE_FILE"
        echo -e "${GREEN}================================${NC}"
    else
        echo -e "${RED}未找到节点链接！${NC}"
    fi
}

while true; do
    clear
    echo -e "${GREEN}====== Hysteria2 一键管理脚本 ======${NC}"
    echo "1) 安装 Hysteria2"
    echo "2) 升级 Hysteria2"
    echo "3) 卸载 Hysteria2"
    echo "4) 显示节点信息"
    echo "5) 退出脚本"
    echo -e "${GREEN}===================================${NC}"

    read -rp "请输入选项 [1-5]: " option

    case "$option" in
        1) do_install ;;
        2) do_upgrade ;;
        3) do_uninstall ;;
        4) show_node ;;
        5) exit 0 ;;
        *) echo -e "${RED}无效，请重输！${NC}" ;;
    esac

    echo
    read -rp "按回车继续..." _
done
