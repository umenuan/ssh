#!/bin/bash
# Debian/Ubuntu 一键管理 Hysteria2

set -euo pipefail

cmd_exists() { command -v "$1" &>/dev/null; }

rand_port() { shuf -i 20000-60000 -n 1; }
rand_hex() { openssl rand -hex 16; }

get_pub_ip() {
  local ip=""
  ip=$(curl -4fsS --max-time 4 https://ipv4.icanhazip.com || true)
  [[ -z "$ip" ]] && ip=$(curl -4fsS --max-time 4 https://ifconfig.me || true)
  [[ -z "$ip" ]] && ip=$(ip -4 addr show scope global | awk '/inet /{sub("/.*","",$2); print $2; exit}')
  echo "${ip//[[:space:]]/}"
}

BIN="/usr/local/bin/hysteria"
CONF_DIR="/etc/hysteria"
CONF_FILE="${CONF_DIR}/config.yaml"
CERT_FILE="${CONF_DIR}/cert.pem"
KEY_FILE="${CONF_DIR}/key.pem"
UNIT_FILE="/etc/systemd/system/hysteria2.service"
NODE_FILE="${CONF_DIR}/node.txt"

do_install() {
  apt update -y
  apt install -y curl openssl ca-certificates

  echo ">>> 正在使用官方脚本安装/更新 Hysteria2 ..."
  bash <(curl -fsSL https://get.hy2.sh/)

  mkdir -p "$CONF_DIR"

  if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
    echo ">>> 生成自签证书（无需域名）..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
      -keyout "$KEY_FILE" -out "$CERT_FILE" \
      -subj "/CN=hy2.local"
      -quiet
    chmod 600 "$KEY_FILE"
  fi

  # 随机端口和密码
  local PORT PASS OBFSPASS
  PORT=$(rand_port)
  PASS=$(rand_hex)
  OBFSPASS=$(rand_hex)

  # 用户自定义端口和密码
  read -rp "请输入服务器端口 [默认: $PORT]: " input_port
  PORT=${input_port:-$PORT}
  read -rp "请输入服务器密码 [默认: $PASS]: " input_pass
  PASS=${input_pass:-$PASS}

  # 是否启用 QUIC
  read -rp "是否启用 QUIC 参数? [y/N] " ENABLE_QUIC
  ENABLE_QUIC=${ENABLE_QUIC:-N}

  # 是否启用混淆
  read -rp "是否启用混淆（salamander）? [y/N] " ENABLE_OBFS
  ENABLE_OBFS=${ENABLE_OBFS:-N}

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

  if [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]]; then
    cat >> "$CONF_FILE" <<EOF

obfs:
  type: salamander
  password: "${OBFSPASS}"
EOF
  fi

  if [[ "$ENABLE_QUIC" =~ ^[Yy]$ ]]; then
    cat >> "$CONF_FILE" <<EOF

quic:
  initStreamReceiveWindow: 15728640
  maxStreamReceiveWindow: 15728640
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864
  disablePathMTUDiscovery: false
EOF
  fi

  # systemd 服务
  cat > "$UNIT_FILE" <<'EOF'
[Unit]
Description=Hysteria2 Server (via config.yaml)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now hysteria2.service

  # ufw 防火墙
  if ! command -v ufw &>/dev/null; then
    echo ">>> 安装 ufw 防火墙..."
    apt install -y ufw
  fi
  ufw allow "${PORT}/udp"

  # 生成节点链接
  local IP NAME LINK
  IP=$(get_pub_ip)
  NAME="HY2-${IP}-${PORT}"
  LINK="hysteria2://${PASS}@${IP}:${PORT}?insecure=1"
  [[ "$ENABLE_OBFS" =~ ^[Yy]$ ]] && LINK+="&obfs=salamander&obfs-password=${OBFSPASS}"
  LINK+="#${NAME}"
  echo "$LINK" | tee "$NODE_FILE"

  echo
  echo "=== 安装完成 ==="
  echo "配置文件:   $CONF_FILE"
  echo "服务单元:   $UNIT_FILE"
  echo "证书路径:   $CERT_FILE"
  echo "节点链接:   $LINK"
  echo "已保存到:   $NODE_FILE"
  echo "==============="
}

do_upgrade() {
  echo ">>> 正在使用官方脚本升级 Hysteria2 ..."
  bash <(curl -fsSL https://get.hy2.sh/)
  systemctl restart hysteria2.service || true
  echo ">>> 升级完成并已重启服务。"
}

show_node() {
  if [[ -f "$NODE_FILE" ]]; then
    echo ">>> 节点链接："
    cat "$NODE_FILE"
  else
    echo "未发现节点链接，请先执行安装。"
  fi
}

do_uninstall() {
  echo ">>> 正在使用官方脚本卸载 Hysteria2 ..."
  bash <(curl -fsSL https://get.hy2.sh/) --remove

  if systemctl list-units --full -all | grep -q "hysteria2.service"; then
    systemctl stop hysteria2.service
    systemctl disable hysteria2.service
    rm -f "$UNIT_FILE"
    userdel -r hysteria
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
    systemctl daemon-reload
  fi

  if [[ -d "$CONF_DIR" ]]; then
    rm -rf "$CONF_DIR"
    echo ">>> 已删除配置目录: $CONF_DIR"
  fi

  echo ">>> 卸载完成。"
}

#========== 菜单 ==========
menu() {
  clear
  echo "= Hysteria2 一键管理 ="
  echo "1) 安装hy2"
  echo "2) 升级hy2"
  echo "3) 节点链接"
  echo "4) 卸载hy2"
  echo "5) 退出"
  echo "======================"
  read -rp "请选择 [1-5]: " opt
  case "$opt" in
    1) do_install ;;
    2) do_upgrade ;;
    3) show_node ;;
    4) do_uninstall ;;
    5) exit 0 ;;
    *) echo "无效选择";;
  esac
  echo
  read -rp "按回车键返回菜单..." _
}

#========== 主入口 ==========

while true; do
  menu
done
