#!/bin/bash
#
# Shadowsocks-Rust 管理脚本
# 功能：安装 / 卸载 / 升级 / 退出

set -o pipefail

CONFIG_DIR="/etc/shadowsocks"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks.service"
BIN_DIR="/usr/local/bin"
TMP_DIR="/tmp/ssrust"
INFO_FILE="${CONFIG_DIR}/connection-info.txt"
TARGET="x86_64-unknown-linux-gnu"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "请使用 root 运行此脚本"
        exit 1
    fi
}

check_deps() {
    apt update -qq
    apt install -y curl wget jq openssl tar >/dev/null
}

get_latest_version() {
    curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | jq -r .tag_name
}

is_installed() {
    [[ -f "${BIN_DIR}/ssserver" && -f "${SERVICE_FILE}" ]]
}

get_public_ip() {
    curl -4 -s --max-time 5 https://api.ipify.org
}

print_connection_info() {
    local ip="$1" port="$2" method="$3" password="$4"
    local b64 ss_link

    b64=$(echo -n "${method}:${password}" | base64 -w0)
    ss_link="ss://${b64}@${ip}:${port}#Shadowsocks-$(hostname)"

    {
        echo "=============================="
        echo "Shadowsocks-Rust 安装完成"
        echo "服务器: ${ip}"
        echo "端口: ${port}"
        echo "加密: ${method}"
        echo "密码: ${password}"
        echo "------------------------------"
        echo "分享链接:"
        echo "${ss_link}"
        echo "=============================="
    } | tee "$INFO_FILE"
}

install_shadowsocks() {
    if is_installed; then
        echo "检测到已安装 Shadowsocks-Rust。"
        read -rp "是否重新安装？这将覆盖现有配置 (y/N): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
        systemctl stop shadowsocks 2>/dev/null || true
    fi

    check_deps

    echo "获取最新版本..."
    local version file url port method key ip
    version=$(get_latest_version)

    file="shadowsocks-${version#v}.${TARGET}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "下载 ${file} ..."
    wget -q --show-progress "$url"
    tar -xf "$file"

    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"

    read -rp "请输入监听端口 (留空则随机生成): " port
    [[ -z "$port" ]] && port=$(shuf -i 10000-60000 -n 1)

    method="2022-blake3-aes-256-gcm"
    key=$(openssl rand -base64 32)

    mkdir -p "$CONFIG_DIR"
    cat >"$CONFIG_FILE" <<EOF
{
    "server":"0.0.0.0",
    "server_port":${port},
    "method":"${method}",
    "password":"${key}",
    "mode":"tcp_only"
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
        echo "已在 ufw 中放行端口 ${port}/tcp"
    fi

    ip=$(get_public_ip)
    echo
    print_connection_info "$ip" "$port" "$method" "$key"

    rm -rf "$TMP_DIR"
    echo
    echo "安装完成！"
}

uninstall_shadowsocks() {
    if ! is_installed; then
        echo "未检测到安装，无需卸载"
        return
    fi

    read -rp "确认要完全卸载 Shadowsocks-Rust 吗？(y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "已取消"; return; }

    local port=""
    [[ -f "$CONFIG_FILE" ]] && port=$(jq -r .server_port "$CONFIG_FILE" 2>/dev/null)

    systemctl stop shadowsocks 2>/dev/null || true
    systemctl disable shadowsocks 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true

    rm -f "${BIN_DIR}/ssserver" "${BIN_DIR}/sslocal"
    rm -rf "$CONFIG_DIR" "$TMP_DIR"

    if [[ -n "$port" && "$port" != "null" ]] && command -v ufw >/dev/null 2>&1; then
        ufw delete allow "${port}/tcp" >/dev/null 2>&1
        echo "已移除端口 ${port}/tcp 的防火墙规则"
    fi

    echo "卸载完成，所有文件与服务已清理干净。"
}

upgrade_shadowsocks() {
    if ! is_installed; then
        echo "未检测到已安装的 Shadowsocks-Rust，请先安装"
        return
    fi

    check_deps

    echo "获取最新版本..."
    local version file url
    version=$(get_latest_version)

    file="shadowsocks-${version#v}.${TARGET}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo "下载 ${file} ..."
    wget -q --show-progress "$url"
    tar -xf "$file"

    systemctl stop shadowsocks
    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"
    systemctl start shadowsocks

    rm -rf "$TMP_DIR"
    echo "升级完成，当前版本: ${version}"
}

show_current_info() {
    if [[ -f "$INFO_FILE" ]]; then
        cat "$INFO_FILE"
    elif [[ -f "$CONFIG_FILE" ]]; then
        local port method key ip
        port=$(jq -r .server_port "$CONFIG_FILE")
        method=$(jq -r .method "$CONFIG_FILE")
        key=$(jq -r .password "$CONFIG_FILE")
        ip=$(get_public_ip)
        print_connection_info "$ip" "$port" "$method" "$key"
    else
        echo "未找到连接信息，请先安装"
    fi
}

show_menu() {
    clear
    echo "=================================="
    echo "   Shadowsocks-Rust 管理脚本"
    echo "=================================="
    echo "  1. 安装"
    echo "  2. 卸载"
    echo "  3. 升级"
    echo "  4. 查看连接信息"
    echo "  5. 退出"
    echo "=================================="
}

main() {
    check_root
    while true; do
        show_menu
        read -rp "请输入选项 [1-5]: " choice
        case "$choice" in
            1) install_shadowsocks ;;
            2) uninstall_shadowsocks ;;
            3) upgrade_shadowsocks ;;
            4) show_current_info ;;
            5) exit 0 ;;
            *) echo "无效选项" ;;
        esac
        echo
        read -rp "按回车键返回菜单..." _
    done
}

main "$@"
