#!/bin/bash
#
# sing-box 一键安装/升级/卸载管理脚本
# 适用系统: Debian (amd64)
# 支持协议: Hysteria2 / Shadowsocks 2022 / 两者同时安装
# 全部监听 "::" 双栈地址，同时兼容 IPv4 / IPv6
#
set -o pipefail

# ------------------------- 基础变量 -------------------------
SB_BIN="/usr/local/bin/sing-box"
SB_DIR="/etc/sing-box"
SB_CONF="${SB_DIR}/config.json"
SB_META="${SB_DIR}/.meta"          # 记录协议类型/端口/密码等，供菜单读取
SB_PORTS_FILE="${SB_DIR}/.ports"   # 记录放行的防火墙端口，卸载时回收
SB_SYSCTL_FLAG="${SB_DIR}/.sysctl_ipv6_changed"
SB_SYSCTL_CONF="/etc/sysctl.d/99-sing-box-ipv6.conf"
SB_SERVICE="/etc/systemd/system/sing-box.service"
GITHUB_REPO="SagerNet/sing-box"

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; NC='\033[0m'

info()  { echo -e "${GREEN}[信息]${NC} $*"; }
warn()  { echo -e "${YELLOW}[警告]${NC} $*"; }
err()   { echo -e "${RED}[错误]${NC} $*"; }

# ------------------------- 基础检查 -------------------------
check_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) ARCH="amd64" ;;
        *)
            err "本脚本仅适配 amd64 架构，检测到架构为: $arch"
            exit 1
            ;;
    esac
    if [[ ! -f /etc/debian_version ]]; then
        warn "未检测到 /etc/debian_version，本脚本主要为 Debian 系统设计，其他系统可能不兼容"
    fi
}

install_deps() {
    info "检查并安装依赖 (curl wget tar openssl coreutils)..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y curl wget tar openssl ca-certificates >/dev/null 2>&1
}

# ------------------------- IPv6 双栈检测 -------------------------
# sing-box 监听 "::" 时，只要内核 net.ipv6.bindv6only=0（Linux 默认值），
# 该 socket 即同时接受 IPv4 / IPv6 连接，无需为两个协议族分别监听。
check_ipv6_dualstack() {
    if [[ ! -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
        warn "系统内核未启用 IPv6 支持，节点将仅可通过 IPv4 访问"
        return
    fi
    local bindv6only
    bindv6only=$(sysctl -n net.ipv6.bindv6only 2>/dev/null)
    if [[ "$bindv6only" == "1" ]]; then
        warn "检测到 net.ipv6.bindv6only=1，会导致监听地址 :: 无法同时接受 IPv4 连接"
        read -rp "是否自动修改为双栈模式 (0)? [Y/n]: " fix
        if [[ "$fix" != "n" && "$fix" != "N" ]]; then
            echo "net.ipv6.bindv6only = 0" > "$SB_SYSCTL_CONF"
            sysctl -p "$SB_SYSCTL_CONF" >/dev/null 2>&1
            touch "$SB_SYSCTL_FLAG"
            info "已设置 net.ipv6.bindv6only=0，端口将同时支持 IPv4 / IPv6"
        else
            warn "已跳过，节点可能仅支持单一协议族"
        fi
    fi
}

revert_ipv6_dualstack() {
    if [[ -f "$SB_SYSCTL_FLAG" ]]; then
        rm -f "$SB_SYSCTL_CONF"
        sysctl -w net.ipv6.bindv6only=1 >/dev/null 2>&1
        info "已恢复 net.ipv6.bindv6only 系统默认设置"
    fi
}

# ------------------------- 获取最新版本并下载 -------------------------
get_latest_version() {
    info "获取 sing-box 最新版本号..."
    LATEST_TAG=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" \
        | grep -oP '"tag_name":\s*"\K[^"]+')
    if [[ -z "$LATEST_TAG" ]]; then
        err "获取最新版本失败，请检查网络（是否可以访问 GitHub）"
        exit 1
    fi
    info "最新版本: ${LATEST_TAG}"
}

download_singbox() {
    get_latest_version
    local ver_num="${LATEST_TAG#v}"
    local fname="sing-box-${ver_num}-linux-${ARCH}.tar.gz"
    local url="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}/${fname}"
    local tmpdir
    tmpdir=$(mktemp -d)

    info "下载: ${url}"
    if ! curl -L --fail -o "${tmpdir}/${fname}" "$url"; then
        err "下载失败，请检查网络或稍后重试"
        rm -rf "$tmpdir"
        exit 1
    fi

    tar -xzf "${tmpdir}/${fname}" -C "$tmpdir"
    local extracted_dir="${tmpdir}/sing-box-${ver_num}-linux-${ARCH}"

    if [[ ! -f "${extracted_dir}/sing-box" ]]; then
        err "解压后未找到 sing-box 可执行文件"
        rm -rf "$tmpdir"
        exit 1
    fi

    systemctl stop sing-box >/dev/null 2>&1
    install -m 755 "${extracted_dir}/sing-box" "$SB_BIN"
    rm -rf "$tmpdir"
    info "sing-box 已安装到 ${SB_BIN}, 版本: $(${SB_BIN} version | head -n1)"
}

# ------------------------- 工具函数 -------------------------
rand_port() {
    shuf -i 20000-60000 -n1
}

port_in_use_by_us() {
    # 检查端口是否已被本次安装中其它协议占用
    local p=$1
    [[ "$p" == "${HY2_PORT:-}" ]] && return 0
    [[ "$p" == "${SS_PORT:-}" ]] && return 0
    return 1
}

pick_free_port() {
    local p
    p=$(rand_port)
    while port_in_use_by_us "$p"; do
        p=$(rand_port)
    done
    echo "$p"
}

open_firewall_port() {
    local port=$1
    local proto=$2  # tcp/udp
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ufw allow "${port}/${proto}" >/dev/null 2>&1
        echo "ufw:${port}/${proto}" >> "$SB_PORTS_FILE"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="${port}/${proto}" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo "firewalld:${port}/${proto}" >> "$SB_PORTS_FILE"
    fi
}

close_firewall_ports() {
    [[ -f "$SB_PORTS_FILE" ]] || return
    while IFS= read -r line; do
        local kind="${line%%:*}"
        local rest="${line#*:}"
        if [[ "$kind" == "ufw" ]] && command -v ufw >/dev/null 2>&1; then
            ufw delete allow "$rest" >/dev/null 2>&1
        elif [[ "$kind" == "firewalld" ]] && command -v firewall-cmd >/dev/null 2>&1; then
            firewall-cmd --permanent --remove-port="$rest" >/dev/null 2>&1
            firewall-cmd --reload >/dev/null 2>&1
        fi
    done < "$SB_PORTS_FILE"
}

get_public_ipv4() {
    curl -s4 --max-time 5 https://ip.sb 2>/dev/null || curl -s4 --max-time 5 https://ifconfig.me 2>/dev/null
}

get_public_ipv6() {
    curl -s6 --max-time 5 https://ip.sb 2>/dev/null || curl -s6 --max-time 5 https://ifconfig.co 2>/dev/null
}

write_systemd_service() {
    cat > "$SB_SERVICE" <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=${SB_BIN} run -c ${SB_CONF}
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
}

# ------------------------- 协议配置：Hysteria2 -------------------------
# 配置结果写入全局变量 HY2_INBOUND_JSON，并将 meta 追加到 SB_META
configure_hysteria2() {
    mkdir -p "$SB_DIR"
    read -rp "[Hysteria2] 请输入监听端口 (回车随机): " port
    [[ -z "$port" ]] && port=$(pick_free_port)
    HY2_PORT="$port"

    read -rp "[Hysteria2] 请输入连接密码 (回车随机生成): " password
    if [[ -z "$password" ]]; then
        password=$("$SB_BIN" generate rand 16 --base64 2>/dev/null)
        [[ -z "$password" ]] && password=$(openssl rand -base64 16)
    fi

    echo
    echo "[Hysteria2] 证书方式:"
    echo "  1) 自签名证书 (客户端需开启 跳过证书验证/insecure)"
    echo "  2) 使用已有域名 + Let's Encrypt 自动申请证书 (需域名已解析到本机，且80端口未占用)"
    read -rp "请选择 [1-2, 默认1]: " cert_choice
    cert_choice=${cert_choice:-1}

    local tls_block sni insecure_flag
    if [[ "$cert_choice" == "2" ]]; then
        read -rp "请输入你的域名: " domain
        sni="$domain"
        insecure_flag="0"
        tls_block=$(cat <<EOF
    "tls": {
      "enabled": true,
      "server_name": "${domain}",
      "acme": {
        "domain": "${domain}",
        "data_directory": "${SB_DIR}/acme",
        "email": "admin@${domain}"
      }
    }
EOF
)
    else
        sni="www.bing.com"
        insecure_flag="1"
        mkdir -p "${SB_DIR}/cert"
        openssl ecparam -genkey -name prime256v1 -out "${SB_DIR}/cert/private.key" >/dev/null 2>&1
        openssl req -new -x509 -days 3650 -key "${SB_DIR}/cert/private.key" \
            -out "${SB_DIR}/cert/cert.pem" -subj "/CN=${sni}" >/dev/null 2>&1
        tls_block=$(cat <<EOF
    "tls": {
      "enabled": true,
      "server_name": "${sni}",
      "certificate_path": "${SB_DIR}/cert/cert.pem",
      "key_path": "${SB_DIR}/cert/private.key"
    }
EOF
)
    fi

    # listen "::" 为双栈监听地址，同时接受 IPv4 / IPv6 连接
    HY2_INBOUND_JSON=$(cat <<EOF
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": ${HY2_PORT},
      "users": [ { "password": "${password}" } ],
${tls_block}
    }
EOF
)

    open_firewall_port "$HY2_PORT" udp

    {
        echo "HY2_PORT=${HY2_PORT}"
        echo "HY2_PASSWORD=${password}"
        echo "HY2_SNI=${sni}"
        echo "HY2_INSECURE=${insecure_flag}"
    } >> "$SB_META"

    info "Hysteria2 配置完成 (端口: ${HY2_PORT})"
}

# ------------------------- 协议配置：Shadowsocks 2022 -------------------------
# 配置结果写入全局变量 SS_INBOUND_JSON，并将 meta 追加到 SB_META
configure_shadowsocks() {
    mkdir -p "$SB_DIR"
    echo "[Shadowsocks 2022] 请选择加密方式:"
    echo "  1) 2022-blake3-aes-128-gcm  (密钥16字节)"
    echo "  2) 2022-blake3-aes-256-gcm  (密钥32字节)"
    echo "  3) 2022-blake3-chacha20-poly1305 (密钥32字节)"
    read -rp "请选择 [1-3, 默认1]: " m
    m=${m:-1}
    local method keylen
    case "$m" in
        1) method="2022-blake3-aes-128-gcm"; keylen=16 ;;
        2) method="2022-blake3-aes-256-gcm"; keylen=32 ;;
        3) method="2022-blake3-chacha20-poly1305"; keylen=32 ;;
        *) method="2022-blake3-aes-128-gcm"; keylen=16 ;;
    esac

    read -rp "[Shadowsocks 2022] 请输入监听端口 (回车随机): " port
    [[ -z "$port" ]] && port=$(pick_free_port)
    SS_PORT="$port"

    local password
    password=$("$SB_BIN" generate rand "${keylen}" --base64 2>/dev/null)
    [[ -z "$password" ]] && password=$(openssl rand -base64 "${keylen}")

    # listen "::" 为双栈监听地址，同时接受 IPv4 / IPv6 连接
    SS_INBOUND_JSON=$(cat <<EOF
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": ${SS_PORT},
      "method": "${method}",
      "password": "${password}"
    }
EOF
)

    open_firewall_port "$SS_PORT" tcp
    open_firewall_port "$SS_PORT" udp

    {
        echo "SS_PORT=${SS_PORT}"
        echo "SS_PASSWORD=${password}"
        echo "SS_METHOD=${method}"
    } >> "$SB_META"

    info "Shadowsocks 2022 配置完成 (端口: ${SS_PORT})"
}

# ------------------------- 汇总生成最终配置文件 -------------------------
build_final_config() {
    local inbounds=()
    [[ -n "${HY2_INBOUND_JSON:-}" ]] && inbounds+=("$HY2_INBOUND_JSON")
    [[ -n "${SS_INBOUND_JSON:-}" ]] && inbounds+=("$SS_INBOUND_JSON")

    local joined
    joined=$(IFS=,; echo "${inbounds[*]}")

    cat > "$SB_CONF" <<EOF
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
${joined}
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
EOF
}

# ------------------------- 展示节点信息 -------------------------
show_node_info() {
    if [[ ! -f "$SB_META" ]]; then
        warn "未检测到已生成的配置信息"
        return
    fi
    # shellcheck disable=SC1090
    source "$SB_META"

    local ipv4 ipv6
    ipv4=$(get_public_ipv4)
    ipv6=$(get_public_ipv6)

    echo
    echo -e "${CYAN}================= 节点信息 =================${NC}"
    [[ -n "$ipv4" ]] && echo "IPv4 地址 : ${ipv4}"
    [[ -n "$ipv6" ]] && echo "IPv6 地址 : ${ipv6}"
    [[ -z "$ipv4" && -z "$ipv6" ]] && warn "未能自动获取公网 IP，请手动替换链接中的地址"
    echo "-----------------------------------------------"

    if [[ -n "${HY2_PORT:-}" ]]; then
        echo -e "${GREEN}[Hysteria2]${NC}"
        echo "端口     : ${HY2_PORT}"
        echo "密码     : ${HY2_PASSWORD}"
        echo "SNI      : ${HY2_SNI}"
        echo "跳过验证 : $([[ $HY2_INSECURE == 1 ]] && echo 是 || echo 否)"
        [[ -n "$ipv4" ]] && echo "IPv4 链接 : hysteria2://${HY2_PASSWORD}@${ipv4}:${HY2_PORT}/?sni=${HY2_SNI}&insecure=${HY2_INSECURE}#HY2-IPv4"
        [[ -n "$ipv6" ]] && echo "IPv6 链接 : hysteria2://${HY2_PASSWORD}@[${ipv6}]:${HY2_PORT}/?sni=${HY2_SNI}&insecure=${HY2_INSECURE}#HY2-IPv6"
        echo
    fi

    if [[ -n "${SS_PORT:-}" ]]; then
        local userinfo b64
        userinfo="${SS_METHOD}:${SS_PASSWORD}"
        b64=$(echo -n "$userinfo" | base64 -w0)
        echo -e "${GREEN}[Shadowsocks 2022]${NC}"
        echo "端口     : ${SS_PORT}"
        echo "密码     : ${SS_PASSWORD}"
        echo "加密方式 : ${SS_METHOD}"
        [[ -n "$ipv4" ]] && echo "IPv4 链接 : ss://${b64}@${ipv4}:${SS_PORT}#SS2022-IPv4"
        [[ -n "$ipv6" ]] && echo "IPv6 链接 : ss://${b64}@[${ipv6}]:${SS_PORT}#SS2022-IPv6"
        echo
    fi

    echo "提示: 服务端口以双栈 (::) 模式监听，IPv4/IPv6 均可直连；"
    echo "      如需切换协议族，直接把链接中的地址替换为对应的另一个即可，端口和密码不变。"
    echo -e "${CYAN}=============================================${NC}"
    echo
}

# ------------------------- 安装 -------------------------
do_install() {
    if [[ -f "$SB_BIN" ]] && systemctl list-unit-files | grep -q sing-box.service; then
        warn "检测到 sing-box 已安装"
        read -rp "是否重新安装并覆盖现有配置? [y/N]: " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return
    fi

    check_arch
    install_deps
    mkdir -p "$SB_DIR"
    rm -f "$SB_PORTS_FILE" "$SB_META"
    unset HY2_PORT HY2_INBOUND_JSON SS_PORT SS_INBOUND_JSON
    download_singbox
    check_ipv6_dualstack

    echo
    echo "请选择要安装的协议:"
    echo "  1) Hysteria2"
    echo "  2) Shadowsocks 2022"
    echo "  3) 同时安装 Hysteria2 + Shadowsocks 2022 (双协议)"
    read -rp "请选择 [1-3]: " proto_choice

    local protocols=""
    case "$proto_choice" in
        1)
            configure_hysteria2
            protocols="hysteria2"
            ;;
        2)
            configure_shadowsocks
            protocols="shadowsocks2022"
            ;;
        3)
            configure_hysteria2
            configure_shadowsocks
            protocols="hysteria2 shadowsocks2022"
            ;;
        *) err "无效选择"; return ;;
    esac

    echo "PROTOCOLS=\"${protocols}\"" >> "$SB_META"

    build_final_config
    write_systemd_service
    systemctl enable sing-box >/dev/null 2>&1
    systemctl restart sing-box

    sleep 1
    if systemctl is-active --quiet sing-box; then
        info "sing-box 启动成功！"
        show_node_info
    else
        err "sing-box 启动失败，请运行: journalctl -u sing-box -e 查看日志"
    fi
}

# ------------------------- 升级 -------------------------
do_upgrade() {
    if [[ ! -f "$SB_BIN" ]]; then
        err "尚未安装 sing-box，请先安装"
        return
    fi
    check_arch
    info "当前版本: $(${SB_BIN} version | head -n1)"
    download_singbox
    systemctl restart sing-box
    sleep 1
    if systemctl is-active --quiet sing-box; then
        info "升级完成，服务已重启并正常运行"
    else
        err "服务重启失败，请检查配置或运行: journalctl -u sing-box -e"
    fi
}

# ------------------------- 卸载（完全卸载，不留痕迹） -------------------------
do_uninstall() {
    read -rp "确认要完全卸载 sing-box 吗? 所有配置将被删除 [y/N]: " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { info "已取消"; return; }

    info "停止并禁用服务..."
    systemctl stop sing-box >/dev/null 2>&1
    systemctl disable sing-box >/dev/null 2>&1

    info "回收防火墙放行规则..."
    close_firewall_ports

    info "恢复系统 IPv6 相关设置（如有修改）..."
    revert_ipv6_dualstack

    info "删除 systemd 服务文件..."
    rm -f "$SB_SERVICE"
    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1

    info "删除二进制文件..."
    rm -f "$SB_BIN"

    info "删除配置目录、证书、日志等所有相关文件..."
    rm -rf "$SB_DIR"

    # 清理可能残留的日志（journal 中按 unit 归档，非明文文件，一并清除该 unit 的日志）
    journalctl --rotate >/dev/null 2>&1
    journalctl --vacuum-time=1s -u sing-box >/dev/null 2>&1

    info "sing-box 已完全卸载，未留下残余文件"
}

# ------------------------- 服务管理 -------------------------
manage_service() {
    if [[ ! -f "$SB_BIN" ]]; then
        err "尚未安装 sing-box"
        return
    fi
    echo
    echo "1) 查看节点信息"
    echo "2) 启动服务"
    echo "3) 停止服务"
    echo "4) 重启服务"
    echo "5) 查看运行状态"
    echo "6) 查看实时日志"
    echo "0) 返回"
    read -rp "请选择: " c
    case "$c" in
        1) show_node_info ;;
        2) systemctl start sing-box && info "已启动" ;;
        3) systemctl stop sing-box && info "已停止" ;;
        4) systemctl restart sing-box && info "已重启" ;;
        5) systemctl status sing-box --no-pager ;;
        6) journalctl -u sing-box -f ;;
        0) return ;;
        *) warn "无效选择" ;;
    esac
}

# ------------------------- 主菜单 -------------------------
main_menu() {
    while true; do
        echo
        echo -e "${CYAN}========== sing-box 管理脚本 ==========${NC}"
        if [[ -f "$SB_BIN" ]]; then
            local ver status
            ver=$(${SB_BIN} version 2>/dev/null | head -n1)
            if systemctl is-active --quiet sing-box; then
                status="${GREEN}运行中${NC}"
            else
                status="${RED}未运行${NC}"
            fi
            echo -e "当前状态: ${status}   ${ver}"
        else
            echo -e "当前状态: ${YELLOW}未安装${NC}"
        fi
        echo "----------------------------------------"
        echo "1) 安装 sing-box"
        echo "2) 升级 sing-box"
        echo "3) 卸载 sing-box"
        echo "4) 服务管理"
        echo "0) 退出"
        echo "========================================"
        read -rp "请输入选项: " choice
        case "$choice" in
            1) do_install ;;
            2) do_upgrade ;;
            3) do_uninstall ;;
            4) manage_service ;;
            0) exit 0 ;;
            *) warn "无效选项，请重新输入" ;;
        esac
    done
}

# ------------------------- 入口 -------------------------
main_menu
