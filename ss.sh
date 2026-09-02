#!/bin/bash
#
# Shadowsocks-Rust manage

set -o pipefail

CONFIG_DIR="/etc/shadowsocks"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks.service"
BIN_DIR="/usr/local/bin"
TMP_DIR="/tmp/ssrust"
INFO_FILE="${CONFIG_DIR}/connection-info.txt"
TARGET="x86_64-unknown-linux-gnu"

check_deps() {
    apt install -y curl wget jq openssl tar xz-utils
}

get_latest_version() {
    curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | jq -r .tag_name
}

is_installed() {
    [[ -f "${BIN_DIR}/ssserver" && -f "${SERVICE_FILE}" ]]
}

print_connection_info() {
    local ip4="$1" ip6="$2" port="$3" method="$4" password="$5"
    local b64 link4 link6 tag

    b64=$(echo -n "${method}:${password}" | base64 -w0)
    tag="Shadowsocks-$(hostname)"

    {
        echo "=============================="
        echo "Shadowsocks-Rust is OK!"
        echo "    port: ${port}"
        echo "  method: ${method}"
        echo "password: ${password}"
        echo "------------------------------"
        if [[ -n "$ip4" ]]; then
            link4="ss://${b64}@${ip4}:${port}#${tag}-v4"
            echo "IPv4: ${ip4}"
            echo "${link4}"
            echo "------------------------------"
        fi
        if [[ -n "$ip6" ]]; then
            link6="ss://${b64}@[${ip6}]:${port}#${tag}-v6"
            echo "IPv6: ${ip6}"
            echo "${link6}"
            echo "------------------------------"
        fi
        echo "IPv4 / IPv6 is OK!"
        echo "=============================="
    } | tee "$INFO_FILE"
}

install_shadowsocks() {
    if is_installed; then
        echo "SS installed!"
        read -rp "reinstall ? (y/N): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
        systemctl stop shadowsocks 2>/dev/null || true
    fi

    check_deps

    echo "get_latest_version..."
    local version file url port method key ip ip6
    version=$(get_latest_version)
    if [[ -z "$version" || "$version" == "null" ]]; then
        echo "No!"
        return 1
    fi

    file="shadowsocks-${version}.${TARGET}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "download ${file} ..."
    if ! wget -q --show-progress "$url"; then
        echo "error: $url"
        return 1
    fi
    tar -xf "$file"

    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"

    read -rp "enter port: " port
    [[ -z "$port" ]] && port=$(shuf -i 10000-60000 -n 1)

    method="2022-blake3-aes-256-gcm"
    key=$(openssl rand -base64 32)

    mkdir -p "$CONFIG_DIR"
    cat >"$CONFIG_FILE" <<EOF
{
    "servers":[
        {
            "server":"0.0.0.0",
            "server_port":${port},
            "method":"${method}",
            "password":"${key}",
            "mode":"tcp_only"
        },
        {
            "server":"::",
            "server_port":${port},
            "method":"${method}",
            "password":"${key}",
            "mode":"tcp_only"
        }
    ]
}
EOF
    chmod 600 "$CONFIG_FILE"

    cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Shadowsocks Rust Server
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/ssserver -c ${CONFIG_FILE}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks >/dev/null 2>&1
    systemctl restart shadowsocks

    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${port}/tcp" >/dev/null 2>&1
    fi

    ip=$(hostname -I | awk '{print $1}')
    ip6=$(hostname -I | tr ' ' '\n' | grep ':' | head -n 1)
    echo
    print_connection_info "$ip" "$ip6" "$port" "$method" "$key"

    rm -rf "$TMP_DIR"
    echo
    echo "ok！"
}

uninstall_shadowsocks() {
    if ! is_installed; then
        echo "no!"
        return
    fi

    local port=""
    [[ -f "$CONFIG_FILE" ]] && port=$(jq -r '.servers[0].server_port' "$CONFIG_FILE" 2>/dev/null)

    systemctl stop shadowsocks 2>/dev/null || true
    systemctl disable shadowsocks 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true

    rm -f "${BIN_DIR}/ssserver" "${BIN_DIR}/sslocal"
    rm -rf "$CONFIG_DIR" "$TMP_DIR"

    if [[ -n "$port" && "$port" != "null" ]] && command -v ufw >/dev/null 2>&1; then
        ufw delete allow "${port}/tcp" >/dev/null 2>&1
    fi

    echo "Uninstallation complete"
}

upgrade_shadowsocks() {
    if ! is_installed; then
        echo "no!"
        return
    fi

    check_deps

    echo "get_latest_version..."
    local version file url
    version=$(get_latest_version)
    if [[ -z "$version" || "$version" == "null" ]]; then
        echo "error"
        return 1
    fi

    file="shadowsocks-${version}.${TARGET}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "download ${file} ..."
    if ! wget -q --show-progress "$url"; then
        echo "error: $url"
        return 1
    fi
    tar -xf "$file"

    systemctl stop shadowsocks
    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"
    systemctl start shadowsocks

    rm -rf "$TMP_DIR"
    echo "Upgrade complete: ${version}"
}

show_current_info() {
    if [[ -f "$INFO_FILE" ]]; then
        cat "$INFO_FILE"
    elif [[ -f "$CONFIG_FILE" ]]; then
        local port method key ip ip6
        port=$(jq -r '.servers[0].server_port' "$CONFIG_FILE")
        method=$(jq -r '.servers[0].method' "$CONFIG_FILE")
        key=$(jq -r '.servers[0].password' "$CONFIG_FILE")
        ip=$(hostname -I | awk '{print $1}')
        ip6=$(hostname -I | tr ' ' '\n' | grep ':' | head -n 1)
        print_connection_info "$ip" "$ip6" "$port" "$method" "$key"
    else
        echo "Install first."
    fi
}

show_menu() {
    clear
    echo "=================================="
    echo "   Shadowsocks-Rust "
    echo "=================================="
    echo "  1. install"
    echo "  2. uninstall"
    echo "  3. upgrade"
    echo "  4. show"
    echo "  0. exit"
    echo "=================================="
}

main() {
    while true; do
        show_menu
        read -rp "Pick [1-5]: " choice
        case "$choice" in
            1) install_shadowsocks ;;
            2) uninstall_shadowsocks ;;
            3) upgrade_shadowsocks ;;
            4) show_current_info ;;
            0) exit 0 ;;
            *) echo "No" ;;
        esac
        echo
        read -rp "skip..." _
    done
}

main "$@"
