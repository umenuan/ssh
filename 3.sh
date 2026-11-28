#!/bin/bash

download_shadowsocks() {
    local v
    v=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | jq -r .tag_name)
    echo "download ${v} ..."
    wget -qO- "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${v}/shadowsocks-${v}.x86_64-unknown-linux-gnu.tar.xz" | tar -xJ -C /usr/local/bin ssserver
}

show() {
    local ip4="$1" ip6="$2" port="$3" method="$4" pass="$5"
    local b64 tag
    b64=$(echo -n "${method}:${pass}" | base64 -w0)
    tag="Shadowsocks-$(hostname)"
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "port: ${port}"
        echo "meth: ${method}"
        echo "pass: ${pass}"
        echo "────────────────────────────────────"
        [[ -n "$ip4" ]] && echo -e "IPv4: ${ip4}\nss://${b64}@${ip4}:${port}#${tag}"
        echo "────────────────────────────────────"
        [[ -n "$ip6" ]] && echo -e "IPv6: ${ip6}\nss://${b64}@[${ip6}]:${port}#${tag}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } | tee /etc/shadowsocks/info.txt
}

install_shadowsocks() {
    local port method="2022-blake3-aes-256-gcm" pass ip ip6 p
    download_shadowsocks
    port=33333; pass=$(openssl rand -base64 32)
    read -rp "port [$port]: " p; port=${p:-$port}
    read -rp "pass [$pass]: " p; pass=${p:-$pass}
    mkdir -p /etc/shadowsocks
    cat >/etc/shadowsocks/config.json <<EOF
{
    "server":"::",
    "server_port":${port},
    "method":"${method}",
    "password":"${pass}"
}
EOF
    chmod 600 /etc/shadowsocks/config.json

    cat >/etc/systemd/system/shadowsocks.service <<EOF
[Unit]
Description=Shadowsocks Rust Server
After=network.target

[Service]
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks >/dev/null 2>&1
    systemctl restart shadowsocks
    ufw allow "${port}/tcp" >/dev/null 2>&1
    ip=$(hostname -I | awk '{print $1}')
    ip6=$(hostname -I | tr ' ' '\n' | grep ':' | head -n 1)
    show "$ip" "$ip6" "$port" "$method" "$pass"
}

uninstall_shadowsocks() {
    local port
    port=$(jq -r '.server_port' /etc/shadowsocks/config.json 2>/dev/null)
    systemctl disable --now shadowsocks 2>/dev/null
    rm -rf /etc/systemd/system/shadowsocks.service /usr/local/bin/ssserver /etc/shadowsocks
    systemctl daemon-reload
    ufw delete allow "${port}/tcp" >/dev/null 2>&1
}

upgrade_shadowsocks() {
    download_shadowsocks
    systemctl restart shadowsocks
}

while true; do
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "     Shadowsocks-Rust "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1. Install"
    echo "  2. Upgrade"
    echo "  3. Uninstall"
    echo "  4. Show"
    echo "  0. exit"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -rp "select : " select
    case $select in
        1) install_shadowsocks ;;
        2) upgrade_shadowsocks ;;
        3) uninstall_shadowsocks ;;
        4) cat /etc/shadowsocks/info.txt 2>/dev/null ;;
        0) exit ;;
    esac
    read -rp "skip..."
done
