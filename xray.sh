#!/bin/bash
#############################################################
#  Xray 一键管理脚本 (Debian / amd64)
#  支持协议: VLESS+Reality / VLESS+WS+TLS
#  功能菜单: 1安装 2升级 3卸载(不留痕迹) 4查看节点 5退出
#############################################################

set -o pipefail

# ------------------------- 基础变量 -------------------------
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[36m"; NC="\033[0m"

XRAY_BIN="/usr/local/bin/xray"
XRAY_ETC="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_ETC}/config.json"
XRAY_LOG_DIR="/var/log/xray"
CERT_DIR="${XRAY_ETC}/cert"
INFO_FILE="${XRAY_ETC}/node_info.txt"
ACME_HOME="/root/.acme.sh"
SERVICE_FILE="/etc/systemd/system/xray.service"
XRAY_INSTALL_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

log_info()  { echo -e "${GREEN}[信息]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[警告]${NC} $1"; }
log_err()   { echo -e "${RED}[错误]${NC} $1"; }

install_deps() {
    log_info "安装依赖组件..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y >/dev/null 2>&1
    apt install -y curl wget unzip socat cron jq openssl uuid-runtime >/dev/null 2>&1
    systemctl enable cron >/dev/null 2>&1
    systemctl start cron >/dev/null 2>&1
}

get_ip() {
    IP=$(curl -s4 --max-time 5 https://api.ipify.org)
    if [[ -z "$IP" ]]; then
        IP=$(curl -s4 --max-time 5 https://ip.sb)
    fi
    if [[ -z "$IP" ]]; then
        log_err "无法获取服务器公网 IP，请检查网络"
        exit 1
    fi
}

# ------------------------- 防火墙放行 -------------------------
open_port() {
    local port=$1
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${port}" >/dev/null 2>&1
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port="${port}/tcp" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    if command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport "${port}" -j ACCEPT >/dev/null 2>&1
    fi
}

# ------------------------- 安装 Xray 内核 -------------------------
install_xray_core() {
    log_info "正在安装/更新 Xray 内核..."
    bash -c "$(curl -L ${XRAY_INSTALL_URL})" @ install -u root
    if [[ $? -ne 0 ]] || [[ ! -f "$XRAY_BIN" ]]; then
        log_err "Xray 内核安装失败"
        exit 1
    fi
    mkdir -p "$XRAY_ETC" "$CERT_DIR" "$XRAY_LOG_DIR"
}

gen_uuid() {
    "$XRAY_BIN" uuid
}

# ------------------------- Reality 配置 -------------------------
config_reality() {
    get_ip
    echo ""
    read -rp "请输入监听端口 (回车随机 10000-60000): " PORT
    [[ -z "$PORT" ]] && PORT=$(shuf -i 10000-60000 -n 1)

    echo ""
    echo "请选择用于伪装的目标网站 (SNI)，建议使用可正常访问 TLS1.3 的站点:"
    echo "  1) www.microsoft.com"
    echo "  2) www.apple.com"
    echo "  3) addons.mozilla.org"
    echo "  4) 自定义"
    read -rp "请选择 [默认1]: " sni_choice
    case "$sni_choice" in
        2) SNI="www.apple.com" ;;
        3) SNI="addons.mozilla.org" ;;
        4) read -rp "请输入自定义 SNI 域名: " SNI ;;
        *) SNI="www.microsoft.com" ;;
    esac

    UUID=$(gen_uuid)
    KEY_PAIR=$("$XRAY_BIN" x25519)
    PRIVATE_KEY=$(echo "$KEY_PAIR" | awk -F': ' '/PrivateKey/{print $2}')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | awk -F': ' '/PublicKey/{print $2}')
    SHORT_ID=$(openssl rand -hex 8)

    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        log_err "x25519 密钥生成失败，请检查 Xray 版本输出格式: 
${KEY_PAIR}"
        exit 1
    fi

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${XRAY_LOG_DIR}/access.log",
    "error": "${XRAY_LOG_DIR}/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": ["${SNI}"],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

    open_port "$PORT"

    NODE_NAME="Reality-$(hostname)"
    LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#${NODE_NAME}"

    cat > "$INFO_FILE" <<EOF
协议类型: VLESS + Reality
服务器IP: ${IP}
端口:     ${PORT}
UUID:     ${UUID}
Flow:     xtls-rprx-vision
SNI:      ${SNI}
PublicKey: ${PUBLIC_KEY}
ShortId:  ${SHORT_ID}
--------------------------------------------------
节点链接:
${LINK}
EOF
}

# ------------------------- WS+TLS 配置 -------------------------
config_ws_tls() {
    echo ""
    read -rp "请输入已解析到本机 IP 的域名(必须提前将域名 A 记录指向本服务器): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        log_err "域名不能为空"
        exit 1
    fi

    get_ip
    RESOLVED_IP=$(getent ahostsv4 "$DOMAIN" | awk '{print $1; exit}')
    if [[ "$RESOLVED_IP" != "$IP" ]]; then
        log_warn "检测到域名解析 IP ($RESOLVED_IP) 与本机公网 IP ($IP) 不一致"
        read -rp "是否继续申请证书? (y/n): " cont
        [[ "$cont" != "y" && "$cont" != "Y" ]] && exit 1
    fi

    read -rp "请输入 WebSocket 路径 (回车随机生成): " WSPATH
    if [[ -z "$WSPATH" ]]; then
        WSPATH="/$(openssl rand -hex 6)"
    else
        [[ "${WSPATH:0:1}" != "/" ]] && WSPATH="/${WSPATH}"
    fi

    # 临时放行 80/443 用于签发证书
    open_port 80
    open_port 443
    systemctl stop xray >/dev/null 2>&1

    if [[ ! -f "${ACME_HOME}/acme.sh" ]]; then
        log_info "安装 acme.sh..."
        curl -s https://get.acme.sh | sh -s email="admin@${DOMAIN}" >/dev/null 2>&1
    fi

    "${ACME_HOME}/acme.sh" --set-default-ca --server letsencrypt >/dev/null 2>&1
    "${ACME_HOME}/acme.sh" --issue -d "${DOMAIN}" --standalone -k ec-256 --force
    if [[ $? -ne 0 ]]; then
        log_err "证书申请失败，请确认 80 端口未被占用，且域名已正确解析"
        exit 1
    fi

    mkdir -p "$CERT_DIR"
    "${ACME_HOME}/acme.sh" --install-cert -d "${DOMAIN}" --ecc \
        --key-file "${CERT_DIR}/private.key" \
        --fullchain-file "${CERT_DIR}/cert.crt" \
        --reloadcmd "systemctl restart xray"

    UUID=$(gen_uuid)

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${XRAY_LOG_DIR}/access.log",
    "error": "${XRAY_LOG_DIR}/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${UUID}" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "${CERT_DIR}/cert.crt",
              "keyFile": "${CERT_DIR}/private.key"
            }
          ]
        },
        "wsSettings": {
          "path": "${WSPATH}",
          "headers": { "Host": "${DOMAIN}" }
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

    NODE_NAME="WS-TLS-$(hostname)"
    LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$WSPATH" 2>/dev/null || echo "$WSPATH")&sni=${DOMAIN}#${NODE_NAME}"

    cat > "$INFO_FILE" <<EOF
协议类型: VLESS + WS + TLS
域名:     ${DOMAIN}
端口:     443
UUID:     ${UUID}
WS路径:   ${WSPATH}
--------------------------------------------------
节点链接:
${LINK}
EOF
}

# ------------------------- systemd 服务 -------------------------
restart_service() {
    systemctl daemon-reload
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray
    sleep 1
    if systemctl is-active --quiet xray; then
        log_info "Xray 服务启动成功"
    else
        log_err "Xray 服务启动失败，请执行 journalctl -u xray -e 查看日志"
    fi
}

# ------------------------- 安装流程 -------------------------
do_install() {
    if [[ -f "$XRAY_BIN" ]] && systemctl list-unit-files | grep -q xray.service; then
        log_warn "检测到 Xray 已安装，如需重新配置请先卸载"
        read -rp "是否仍要继续覆盖安装? (y/n): " ov
        [[ "$ov" != "y" && "$ov" != "Y" ]] && return
    fi

    install_deps
    install_xray_core

    echo ""
    echo "请选择要安装的协议:"
    echo "  1) VLESS + Reality  (推荐，无需域名，抗封锁能力强)"
    echo "  2) VLESS + WS + TLS (需要一个已解析的域名)"
    read -rp "请输入选项 [1/2]: " proto

    case "$proto" in
        1) config_reality ;;
        2) config_ws_tls ;;
        *) log_err "无效选项"; return ;;
    esac

    restart_service
    echo ""
    log_info "安装完成！节点信息如下:"
    echo "--------------------------------------------------"
    cat "$INFO_FILE"
    echo "--------------------------------------------------"
}

# ------------------------- 升级流程 -------------------------
do_upgrade() {
    if [[ ! -f "$XRAY_BIN" ]]; then
        log_err "未检测到 Xray，请先安装"
        return
    fi
    log_info "正在升级 Xray 内核至最新版本..."
    bash -c "$(curl -L ${XRAY_INSTALL_URL})" @ install -u root
    restart_service
    log_info "升级完成，当前版本:"
    "$XRAY_BIN" version
}

# ------------------------- 查看节点 -------------------------
do_view() {
    if [[ ! -f "$INFO_FILE" ]]; then
        log_err "未找到节点信息，请先安装"
        return
    fi
    echo "--------------------------------------------------"
    cat "$INFO_FILE"
    echo "--------------------------------------------------"
    echo ""
    if systemctl is-active --quiet xray; then
        log_info "Xray 运行状态: 运行中"
    else
        log_warn "Xray 运行状态: 未运行"
    fi
}

# ------------------------- 完全卸载 -------------------------
do_uninstall() {
    read -rp "确定要完全卸载 Xray 并清除所有相关数据吗? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "已取消卸载"
        return
    fi

    log_info "停止并禁用 Xray 服务..."
    systemctl stop xray >/dev/null 2>&1
    systemctl disable xray >/dev/null 2>&1

    log_info "调用官方脚本卸载 Xray 内核..."
    bash -c "$(curl -L ${XRAY_INSTALL_URL})" @ remove --purge >/dev/null 2>&1

    log_info "清理残留文件与目录..."
    rm -rf "$XRAY_ETC"
    rm -rf "$XRAY_LOG_DIR"
    rm -f "$XRAY_BIN"
    rm -f "$SERVICE_FILE"
    rm -f /etc/systemd/system/xray@*.service
    rm -rf /usr/local/share/xray
    rm -rf /etc/systemd/system/xray.service.d

    if [[ -d "$ACME_HOME" ]]; then
        read -rp "是否同时卸载 acme.sh 及证书数据 (若其他服务在用请选n)? (y/n): " rm_acme
        if [[ "$rm_acme" == "y" || "$rm_acme" == "Y" ]]; then
            "${ACME_HOME}/acme.sh" --uninstall >/dev/null 2>&1
            rm -rf "$ACME_HOME"
            crontab -l 2>/dev/null | grep -v 'acme.sh' | crontab - 2>/dev/null
        fi
    fi

    systemctl daemon-reload
    systemctl reset-failed >/dev/null 2>&1

    log_info "清理日志痕迹..."
    journalctl --rotate >/dev/null 2>&1
    journalctl --vacuum-time=1s >/dev/null 2>&1
    rm -f /var/log/syslog.* 2>/dev/null

    log_info "Xray 已完全卸载，相关文件与运行痕迹已清除"
}

# ------------------------- 主菜单 -------------------------
main_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}=========================================${NC}"
        echo -e "${BLUE}      Xray 一键管理脚本 (Debian/amd64)   ${NC}"
        echo -e "${BLUE}=========================================${NC}"
        echo "  1. 安装 Xray (Reality / WS+TLS)"
        echo "  2. 升级 Xray 内核"
        echo "  3. 完全卸载 Xray (清除所有痕迹)"
        echo "  4. 查看当前节点信息"
        echo "  5. 退出脚本"
        echo -e "${BLUE}=========================================${NC}"
        read -rp "请输入选项 [1-5]: " choice
        case "$choice" in
            1) do_install ;;
            2) do_upgrade ;;
            3) do_uninstall ;;
            4) do_view ;;
            5) echo "已退出"; exit 0 ;;
            *) log_err "无效选项，请重新输入" ;;
        esac
    done
}

main_menu
