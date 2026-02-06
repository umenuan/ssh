#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}请使用 root 用户运行此脚本${NC}"
  exit 1
fi

is_xray_installed() {
  command -v xray >/dev/null 2>&1
}

get_installed_version() {
  if is_xray_installed; then
    xray version | head -n1 | awk '{print $2}'
  else
    echo ""
  fi
}

get_latest_version() {
  curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | head -n1 | awk -F'"' '{print $4}' | sed 's/^v//'
}

install_xray() {
  if is_xray_installed; then
    echo -e "${YELLOW}检测到已安装 Xray，跳过安装。如需更新请选择菜单2。${NC}"
    return
  fi
  echo -e "${BLUE}开始安装 Xray 最新版本...${NC}"
  download_and_install_xray
  start_xray
}

download_and_install_xray() {
  echo -e "${BLUE}开始下载并安装 Xray...${NC}"

  # 下载链接
  url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
  tmpdir=$(mktemp -d)

  # 下载 Xray 压缩包
  echo -e "${BLUE}下载 Xray 二进制包...${NC}"
  curl -L --progress-bar "$url" -o "$tmpdir/xray.zip"
  if [[ $? -ne 0 || ! -s "$tmpdir/xray.zip" ]]; then
    echo -e "${RED}下载失败或文件损坏，退出${NC}"
    rm -rf "$tmpdir"
    exit 1
  fi

  # 解压 Xray 压缩包
  echo -e "${BLUE}解压安装包...${NC}"
  unzip -o "$tmpdir/xray.zip" -d "$tmpdir" >/dev/null 2>&1

  # 检查解压后的 xray 文件是否存在
  if [[ ! -f "$tmpdir/xray" ]]; then
    echo -e "${RED}未找到 xray 可执行文件，安装失败${NC}"
    rm -rf "$tmpdir"
    exit 1
  fi

  # 安装 xray
  echo -e "${BLUE}安装 Xray...${NC}"
  install -m 755 "$tmpdir/xray" /usr/local/bin/xray

  # 创建必要的目录
  mkdir -p /usr/local/etc/xray
  mkdir -p /var/log/xray

  # 清理临时文件
  rm -rf "$tmpdir"

  # 创建 systemd 服务文件
  if [[ ! -f /etc/systemd/system/xray.service ]]; then
    cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/xray -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  fi

  # 启用并启动服务
  systemctl daemon-reload
  systemctl enable xray

  echo -e "${GREEN}Xray 安装完成${NC}"
}

config_xray() {
  echo -e "${CYAN}请输入以下配置参数，直接回车则使用默认值${NC}"

  read -p "监听端口（默认 80）: " port
  [[ -z "$port" ]] && port=80

  read -p "UUID（留空自动生成）: " uuid
  [[ -z "$uuid" ]] && uuid=$(cat /proc/sys/kernel/random/uuid)

  read -p "WebSocket 路径（默认空）: " ws_path
  [[ -z "$ws_path" ]] && ws_path="/"

  cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": $port,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "level": 0,
            "email": "vless-nontls"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$ws_path"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

  echo -e "${GREEN}配置文件已生成: /usr/local/etc/xray/config.json${NC}"
}


start_xray() {
  systemctl daemon-reload
  systemctl restart xray
  systemctl enable xray
  echo -e "${GREEN}Xray 服务已启动并设置开机自启${NC}"
}

generate_vless_link() {
  local ip
  ip=$(curl -s https://ipinfo.io/ip)
  local clean_path="${ws_path#/}"  # 去掉前导斜杠
  local vless_link="vless://${uuid}@${ip}:${port}?type=ws&security=none&path=/${clean_path}#vless-ws-nontls"

  echo -e "\n${YELLOW}========== VLESS 链接 ==========${NC}"
  echo -e "${CYAN}$vless_link${NC}"
  echo -e "${YELLOW}===============================${NC}\n"
}

update_xray() {
  if ! is_xray_installed; then
    echo -e "${RED}未检测到 Xray，请先安装（选项1）${NC}"
    return
  fi

  installed_version=$(get_installed_version)
  latest_version=$(get_latest_version)

  echo -e "${CYAN}当前已安装版本: ${YELLOW}${installed_version}${NC}"
  echo -e "${CYAN}官方最新版本: ${YELLOW}${latest_version}${NC}"

  if [[ "$installed_version" == "$latest_version" ]]; then
    echo -e "${GREEN}Xray 已是最新版本，无需更新。${NC}"
    return
  fi

  echo -e "${BLUE}开始更新 Xray 到最新版本...${NC}"
  download_and_install_xray
  systemctl restart xray
  echo -e "${GREEN}更新完成，当前版本: $(get_installed_version)${NC}"
}

uninstall_xray() {
  if ! is_xray_installed; then
    echo -e "${YELLOW}未检测到 Xray，无需卸载${NC}"
    return
  fi

  echo -e "${BLUE}停止 Xray 服务...${NC}"
  systemctl stop xray 2>/dev/null

  echo -e "${BLUE}禁用 Xray 服务...${NC}"
  systemctl disable xray 2>/dev/null

  echo -e "${BLUE}删除 Xray 服务文件...${NC}"
  rm -f /etc/systemd/system/xray.service
  rm -f /lib/systemd/system/xray.service
  rm -f /usr/lib/systemd/system/xray.service

  echo -e "${BLUE}重新加载 systemd 守护进程...${NC}"
  systemctl daemon-reload

  echo -e "${BLUE}删除 Xray 文件和配置...${NC}"
  rm -rf /usr/local/etc/xray
  rm -rf /usr/local/bin/xray
  rm -rf /usr/local/share/xray
  rm -rf /var/log/xray

  echo -e "${BLUE}删除 Xray 用户和组（如果存在）...${NC}"
  id xray &>/dev/null && userdel -r xray
  getent group xray && groupdel xray

  echo -e "${GREEN}Xray 已完全卸载${NC}"
}


main() {
  while true; do
    echo -e "${BLUE}========= Xray VLESS+WS 一键管理脚本 =========${NC}"
    echo -e "  ${YELLOW}请选择操作:${NC}"
    echo -e "  ${GREEN}1.${NC} 安装 VLESS+WS"
    echo -e "  ${GREEN}2.${NC} 更新 Xray"
    echo -e "  ${GREEN}3.${NC} 卸载 Xray"
    echo -e "  ${GREEN}0.${NC} 退出脚本"
    echo -e "${BLUE}===============================================${NC}"
    read -rp "请输入选项 [0-3]: " option

    case "$option" in
      1)
        install_xray
        config_xray
        start_xray
        generate_vless_link
        ;;	
      2)
        update_xray
        ;;
      3)
        uninstall_xray
        ;;
      0)
        echo -e "${GREEN}已退出脚本，再见！${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}无效选项，请重新输入！${NC}"
        ;;
    esac

    echo ""
    read -rp "按回车键返回菜单..."
    clear
  done
}


main
