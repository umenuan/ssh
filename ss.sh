#!/usr/bin
#
# Shadowsocks-Rust 管理脚本
# 功能：安装 / 卸载 / 升级 / 退出
#
set -o pipefail

CONFIG_DIR="/etc/shadowsocks"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/shadowsocks.service"
BIN_DIR="/usr/local/bin"
TMP_DIR="/tmp/ssrust"
INFO_FILE="${CONFIG_DIR}/connection-info.txt"

# ---------- 基础检查 ----------
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

get_arch_target() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "x86_64-unknown-linux-gnu"
            ;;
        aarch64)
            echo "aarch64-unknown-linux-gnu"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_latest_version() {
    local version
    version=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest | jq -r .tag_name)
    if [[ -z "$version" || "$version" == "null" ]]; then
        echo ""
    else
        echo "$version"
    fi
}

is_installed() {
    [[ -f "${BIN_DIR}/ssserver" && -f "${SERVICE_FILE}" ]]
}

get_public_ip() {
    curl -4 -s --max-time 5 https://api.ipify.org || curl -6 -s --max-time 5 https://api64.ipify.org
}

detect_fastopen_support() {
    # 检测内核是否支持 TCP Fast Open
    if [[ -f /proc/sys/net/ipv4/tcp_fastopen ]]; then
        local val
        val=$(cat /proc/sys/net/ipv4/tcp_fastopen)
        if [[ "$val" -ge 1 ]]; then
            echo "true"
            return
        fi
    fi
    echo "false"
}

# ---------- 生成 ss:// 链接并展示 ----------
print_connection_info() {
    local ip="$1" port="$2" method="$3" password="$4"
    local userinfo b64 ss_link

    userinfo="${method}:${password}"
    b64=$(echo -n "$userinfo" | base64 -w0 | tr -d '\n')
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

    echo
    echo "连接信息已保存到: ${INFO_FILE}"
}

# ---------- 防火墙放行端口 ----------
open_firewall_port() {
    local port="$1"
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "${port}/tcp" >/dev/null 2>&1
        ufw allow "${port}/udp" >/dev/null 2>&1
        echo "已在 ufw 中放行端口 ${port}"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1
        firewall-cmd --permanent --add-port="${port}/udp" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo "已在 firewalld 中放行端口 ${port}"
    else
        echo "未检测到 ufw/firewalld，请自行确认云服务商安全组已放行端口 ${port} (TCP+UDP)"
    fi
}

# ---------- 安装 ----------
install_shadowsocks() {
    if is_installed; then
        echo "检测到已安装 Shadowsocks-Rust。"
        read -rp "是否重新安装？这将覆盖现有配置 (y/N): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
        systemctl stop shadowsocks 2>/dev/null || true
    fi

    check_deps

    local target version file url port method key fastopen ip

    target=$(get_arch_target)
    if [[ -z "$target" ]]; then
        echo "不支持的架构：$(uname -m)"
        return 1
    fi

    echo "获取最新版本..."
    version=$(get_latest_version)
    if [[ -z "$version" ]]; then
        echo "获取版本信息失败，请检查网络连接或稍后重试"
        return 1
    fi
    echo "最新版本: ${version}"

    file="shadowsocks-${version#v}.${target}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || return 1

    echo "下载 ${file} ..."
    if ! wget -q --show-progress "$url"; then
        echo "下载失败，请检查网络或链接是否有效: $url"
        return 1
    fi

    if ! tar -xf "$file"; then
        echo "解压失败"
        return 1
    fi

    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"

    # 端口：允许自定义，默认随机生成，避免固定 8388 被扫描
    read -rp "请输入监听端口 (留空则随机生成 10000-60000): " port
    if [[ -z "$port" ]]; then
        port=$(shuf -i 10000-60000 -n 1)
    fi

    method="2022-blake3-aes-256-gcm"
    key=$(openssl rand -base64 32)
    fastopen=$(detect_fastopen_support)

    mkdir -p "$CONFIG_DIR"
    cat >"$CONFIG_FILE" <<EOF
{
    "server":"0.0.0.0",
    "server_port":${port},
    "method":"${method}",
    "password":"${key}",
    "mode":"tcp_and_udp",
    "fast_open":${fastopen}
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
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks >/dev/null 2>&1
    systemctl restart shadowsocks

    open_firewall_port "$port"

    sleep 1
    if ! systemctl is-active --quiet shadowsocks; then
        echo "警告：服务未能正常启动，请查看日志: journalctl -u shadowsocks -e"
        return 1
    fi

    ip=$(get_public_ip)
    echo
    print_connection_info "$ip" "$port" "$method" "$key"

    rm -rf "$TMP_DIR"
    echo
    echo "安装完成！"
}

# ---------- 卸载（完全清理，不留痕迹） ----------
uninstall_shadowsocks() {
    if ! is_installed; then
        echo "未检测到 Shadowsocks-Rust 安装，无需卸载"
        return
    fi

    read -rp "确认要完全卸载 Shadowsocks-Rust 吗？此操作不可恢复 (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "已取消"; return; }

    # 尝试读取端口以关闭防火墙规则
    local port=""
    if [[ -f "$CONFIG_FILE" ]]; then
        port=$(jq -r .server_port "$CONFIG_FILE" 2>/dev/null)
    fi

    echo "停止并禁用服务..."
    systemctl stop shadowsocks 2>/dev/null || true
    systemctl disable shadowsocks 2>/dev/null || true

    echo "删除 systemd 服务文件..."
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true

    echo "删除二进制文件..."
    rm -f "${BIN_DIR}/ssserver" "${BIN_DIR}/sslocal" "${BIN_DIR}/ssmanager" "${BIN_DIR}/ssurl" "${BIN_DIR}/ssservice"

    echo "删除配置文件与连接信息..."
    rm -rf "$CONFIG_DIR"

    echo "清理临时文件..."
    rm -rf "$TMP_DIR"

    if [[ -n "$port" && "$port" != "null" ]]; then
        if command -v ufw >/dev/null 2>&1; then
            ufw delete allow "${port}/tcp" >/dev/null 2>&1
            ufw delete allow "${port}/udp" >/dev/null 2>&1
        elif command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --remove-port="${port}/tcp" >/dev/null 2>&1
            firewall-cmd --permanent --remove-port="${port}/udp" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
        fi
        echo "已尝试移除端口 ${port} 的防火墙规则"
    fi

    echo
    echo "卸载完成，所有相关文件、服务、防火墙规则已清理干净。"
}

# ---------- 升级 ----------
upgrade_shadowsocks() {
    if ! is_installed; then
        echo "未检测到已安装的 Shadowsocks-Rust，请先安装"
        return
    fi

    check_deps

    local target version file url current_version

    target=$(get_arch_target)
    if [[ -z "$target" ]]; then
        echo "不支持的架构：$(uname -m)"
        return 1
    fi

    current_version=$("${BIN_DIR}/ssserver" --version 2>/dev/null | awk '{print $2}')
    echo "当前版本: ${current_version:-未知}"

    echo "获取最新版本..."
    version=$(get_latest_version)
    if [[ -z "$version" ]]; then
        echo "获取版本信息失败，请检查网络连接"
        return 1
    fi
    echo "最新版本: ${version}"

    if [[ "${version#v}" == "$current_version" ]]; then
        echo "已经是最新版本，无需升级"
        return
    fi

    file="shadowsocks-${version#v}.${target}.tar.xz"
    url="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${version}/${file}"

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR" || return 1

    echo "下载 ${file} ..."
    if ! wget -q --show-progress "$url"; then
        echo "下载失败"
        return 1
    fi

    if ! tar -xf "$file"; then
        echo "解压失败"
        return 1
    fi

    echo "停止服务..."
    systemctl stop shadowsocks

    install -m 755 ssserver "${BIN_DIR}/"
    install -m 755 sslocal "${BIN_DIR}/"

    echo "启动服务..."
    systemctl start shadowsocks

    sleep 1
    if systemctl is-active --quiet shadowsocks; then
        echo "升级成功，当前版本: ${version}"
    else
        echo "警告：服务未能正常启动，请查看日志: journalctl -u shadowsocks -e"
    fi

    rm -rf "$TMP_DIR"
}

# ---------- 查看当前连接信息 ----------
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

# ---------- 主菜单 ----------
show_menu() {
    clear
    echo "=================================="
    echo "   Shadowsocks-Rust 管理脚本"
    echo "=================================="
    if is_installed; then
        if systemctl is-active --quiet shadowsocks; then
            echo "  当前状态: 已安装 (运行中)"
        else
            echo "  当前状态: 已安装 (未运行)"
        fi
    else
        echo "  当前状态: 未安装"
    fi
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
            5) echo "已退出"; exit 0 ;;
            *) echo "无效选项" ;;
        esac
        echo
        read -rp "按回车键返回菜单..." _
    done
}

main "$@"
