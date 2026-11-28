#!/bin/bash

do_install(){
    HYSTERIA_USER=root bash <(curl -fsSL https://get.hy2.sh/)

    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout /etc/hysteria/key.pem -out /etc/hysteria/cert.pem -subj "/CN=hy2.local" 2>/dev/null
		
    pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in /etc/hysteria/cert.pem | cut -d= -f2)
	
    PORT=55555; PASS=$(openssl rand -hex 16)
    read -rp "port [$PORT]: " p; PORT=${p:-$PORT}
    read -rp "pass [$PASS]: " p; PASS=${p:-$PASS}

    cat > /etc/hysteria/config.yaml <<EOF
listen: ":$PORT"
auth:
  type: password
  password: "$PASS"
tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
    rewriteHost: true
EOF

    systemctl enable hysteria-server.service
    systemctl restart hysteria-server.service
    ufw allow "$PORT/udp" >/dev/null 2>&1 || true
    IP=$(hostname -I | awk '{print $1}')
    echo "hysteria2://${PASS}@${IP}:${PORT}?insecure=1&pinSHA256=${pinSHA256}#HY2-${IP}" | tee /etc/hysteria/node.txt
}

do_uninstall(){
    bash <(curl -fsSL https://get.hy2.sh/) --remove >/dev/null 2>&1 || true
	awk -F'[@:?#]' '{print "ufw delete allow " $4 "/udp"}' /etc/hysteria/node.txt 2>/dev/null | sh >/dev/null 2>&1
    rm -rf /etc/hysteria
}

do_upgrade(){
    HYSTERIA_USER=root bash <(curl -fsSL https://get.hy2.sh/)
    systemctl restart hysteria-server.service
}

while true; do
	clear
    echo "━━━━━━━━━━━━━━━━━━━━━━"
	echo "   Hysteria2"
	echo "━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. Install"
    echo "2. Upgrade"
    echo "3. Uninstall"
    echo "4. Show"
    echo "0. exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    read -rp "select : " select
    case $select in
        1) do_install ;;
        2) do_upgrade ;;
        3) do_uninstall ;;
        4) cat /etc/hysteria/node.txt ;;
        0) exit ;;
    esac
    read -rp "skip..." _
done
