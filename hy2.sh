#!/bin/bash

set -e

CONFIG_DIR="/etc/hysteria"
CERT_DIR="$CONFIG_DIR/certs"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_NAME="hysteria-server"
BINARY="/usr/local/bin/hysteria"

green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

gen_cert() {
  mkdir -p "$CERT_DIR"
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj "/CN=hy2.local" \
    -keyout "$CERT_DIR/self.key" \
    -out "$CERT_DIR/self.crt" >/dev/null 2>&1
}

gen_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

get_ip() {
  IP=$(curl -s https://ipinfo.io/ip)
  if [[ ! $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    red "❌ 获取 IP 失败，返回内容不是合法 IP：$IP"
    IP="0.0.0.0"
  fi
}

install() {
  yellow "🚀 安装 Hysteria 2..."
  bash <(curl -fsSL https://get.hy2.sh/)

  read -p "端口 (默认 443): " PORT
  read -p "密码 (默认随机 UUID): " PASSWORD
  PORT=${PORT:-443}
  if [ -z "$PASSWORD" ]; then
    PASSWORD=$(gen_uuid)
  fi

  gen_cert
  mkdir -p "$CONFIG_DIR"

  cat <<EOF > "$CONFIG_FILE"
listen: :$PORT
protocol: udp
auth:
  password: $PASSWORD
tls:
  cert: $CERT_DIR/self.crt
  key: $CERT_DIR/self.key
EOF

  systemctl restart $SERVICE_NAME
  systemctl enable $SERVICE_NAME
  green "✅ 安装完成！"
  show_link
  read -p "按回车返回主菜单..."
}

update() {
  yellow "🔄 正在更新 Hysteria 2..."
  bash <(curl -fsSL https://get.hy2.sh/) -- --update
  green "✅ 更新完成！"
  read -p "按回车返回主菜单..."
}

uninstall() {
  red "⚠️ 即将卸载并清理所有 Hysteria 文件..."
  read -p "确认卸载？(y/n): " confirm
  [[ $confirm != "y" ]] && echo "已取消" && read -p "按回车返回主菜单..." && return
  systemctl stop $SERVICE_NAME || true
  systemctl disable $SERVICE_NAME || true
  rm -f "$BINARY"
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -rf "$CONFIG_DIR"
  systemctl daemon-reload
  green "✅ 已彻底卸载"
  read -p "按回车返回主菜单..."
}

show_link() {
  [[ ! -f $CONFIG_FILE ]] && red "❌ 配置不存在" && read -p "按回车返回主菜单..." && return
  get_ip
  PORT=$(grep listen "$CONFIG_FILE" | grep -o '[0-9]\+')
  PASSWORD=$(grep password "$CONFIG_FILE" | awk '{print $2}')
  [[ -z $PORT || -z $PASSWORD ]] && red "❌ 配置缺失" && read -p "按回车返回主菜单..." && return
  green "📡 节点链接："
  echo "hy2://$PASSWORD@$IP:$PORT?insecure=1"
  read -p "按回车返回主菜单..."
}

menu() {
  while true; do
    echo -e "\n\033[32m=== Hy2 一键管理脚本 ===\033[0m"
    echo "1. 安装 Hy2"
    echo "2. 更新 Hy2"
    echo "3. 卸载 Hy2"
    echo "4. 显示节点链接"
    echo "0. 退出"
    read -p "选择操作 [0-4]: " opt
    case $opt in
      1) install ;;
      2) update ;;
      3) uninstall ;;
      4) show_link ;;
      0) exit ;;
      *) red "无效选项" ;;
    esac
  done
}

menu
