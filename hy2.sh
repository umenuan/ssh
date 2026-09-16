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
    echo -e "${GREEN}>>> Install Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/)
    mkdir -p "$CONF_DIR"

    if [[ ! -f $CERT_FILE || ! -f $KEY_FILE ]]; then
        echo -e "${GREEN}>>> get cert...${NC}"
        openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
            -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=hy2.local" 2>/dev/null
        chmod 600 "$KEY_FILE"
    fi

    local PORT PASS IP LINK IP_TYPE
    PORT=$(rand_port); PASS=$(rand_hex)
    read -rp "port [${PORT}]: " p; PORT=${p:-$PORT}
    read -rp "pass [${PASS}]: " p; PASS=${p:-$PASS}

    pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | cut -d= -f2)

    cat > "$CONF_FILE" <<EOF
listen: ":$PORT"
auth:
  type: password
  password: "$PASS"
tls:
  cert: "$CERT_FILE"
  key: "$KEY_FILE"
  pinSHA256: "$pinSHA256"
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

    IP=$(hostname -I | awk '{print $1}')
    LINK="hysteria2://${PASS}@${IP}:${PORT}?insecure=1&pinSHA256=${pinSHA256}#HY2-${IP}"

    echo "$LINK" > "$NODE_FILE"
    echo ""
    echo -e "${YELLOW}$LINK${NC}"
}

do_uninstall(){
    echo -e "${RED}>>> remove Hysteria2...${NC}"
    systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
    pkill -9 -f "hysteria server" 2>/dev/null || true
    [[ -f $CONF_FILE ]] && PORT=$(grep '^listen:' "$CONF_FILE" | grep -oE '[0-9]+')
    rm -f "$UNIT_FILE"
    systemctl daemon-reload
    rm -rf "$CONF_DIR"
    bash <(curl -fsSL https://get.hy2.sh/) --remove >/dev/null 2>&1 || true
    [[ -n ${PORT:-} ]] && ufw delete allow "$PORT/udp" >/dev/null 2>&1 || true
    echo -e "${GREEN}>>> uninstall！${NC}"
}

do_upgrade(){
    echo -e "${GREEN}>>> upgrade Hysteria2...${NC}"
    bash <(curl -fsSL https://get.hy2.sh/)
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    echo -e "${GREEN}>>> ok！${NC}"
}

show_node(){
    if [[ -f $NODE_FILE ]]; then
        echo -e "${GREEN}=========== info ===========${NC}"
        cat "$NODE_FILE"
        echo -e "${GREEN}============================${NC}"
    else
        echo -e "${RED}null！${NC}"
    fi
}

while true; do
    clear
    echo -e "${GREEN}====== Hysteria2  ======${NC}"
    echo "1) install"
    echo "2) upgrade"
    echo "3) uninstall"
    echo "4) show"
    echo "0) exit"
    echo -e "${GREEN}=========================${NC}"
    read -rp "Pick : " option
    case "$option" in
        1) do_install ;;
        2) do_upgrade ;;
        3) do_uninstall ;;
        4) show_node ;;
        0) exit 0 ;;
        *) echo -e "${RED}No！${NC}" ;;
    esac
    echo; read -rp "skip..." _
done
