#!/usr/bin/env bash
# caddy-manager.sh
# 功能：
#   - 安装 Caddy（Debian 官方仓库 apt install caddy）
#   - 添加站点（支持多个域名 -> 同一后端，自动支持 WebSocket）
#   - 列出已管理站点
#   - 删除站点（支持单个/批量序号选择）
#   - 显示 Caddyfile 内容
#   - 一键卸载 Caddy（彻底清理）
set -euo pipefail

CADDYFILE="/etc/caddy/Caddyfile"
MANAGED_TAG="MANAGED-BY-CADDY-MANAGER"

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "请以 root 用户或 sudo 运行此脚本"
    exit 1
  fi
}

confirm() {
  read -rp "$1 [y/N]: " ans
  case "$ans" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

install_caddy() {
  echo "==> 安装 Caddy"
  apt update
  apt install -y caddy
  systemctl enable --now caddy
  echo "Caddy 安装完成"
}

generate_site_block() {
  local domains_raw="$1"
  local backend="$2"
  local id="${3:-$(echo "$domains_raw" | awk -F, '{print $1}' | tr -c '[:alnum:]' '-')}"
  local domains
  domains=$(echo "$domains_raw" | sed 's/[[:space:]]*,[[:space:]]*/,/g')
  local start="# BEGIN ${MANAGED_TAG} ${id}"
  local end="# END ${MANAGED_TAG} ${id}"

  cat <<EOF
$start
${domains} {
    reverse_proxy * $backend {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
$end

EOF
}

append_site_to_caddyfile() {
  local block="$1"
  mkdir -p "$(dirname "$CADDYFILE")"
  if [ ! -f "$CADDYFILE" ]; then
    echo "# Caddyfile - managed by caddy-manager" > "$CADDYFILE"
  fi
  printf "%s\n" "$block" >> "$CADDYFILE"
}

list_sites() {
  if [ ! -f "$CADDYFILE" ]; then
    echo "Caddyfile 不存在"
    return
  fi
  grep -n "^# BEGIN ${MANAGED_TAG}" "$CADDYFILE" | while IFS=: read -r ln rest; do
    id=$(echo "$rest" | sed -E "s/^# BEGIN ${MANAGED_TAG} //")
    domain_line=$(sed -n "$((ln+1))p" "$CADDYFILE" | sed 's/^[[:space:]]*//')
    echo "id: ${id}  ->  ${domain_line}"
  done
}

remove_site_by_id() {
  local id="$1"
  awk -v id="$id" -v tag="$MANAGED_TAG" '
    BEGIN {inside=0}
    {
      if ($0 ~ ("^# BEGIN " tag " " id)) { inside=1; next }
      if ($0 ~ ("^# END " tag " " id)) { inside=0; next }
      if (!inside) print $0
    }' "$CADDYFILE" > "${CADDYFILE}.tmp" && mv "${CADDYFILE}.tmp" "$CADDYFILE"
  systemctl reload caddy || systemctl restart caddy || true
}

validate_domain_input() {
  local s="$1"
  [[ -n "$s" && "$s" =~ ^[A-Za-z0-9\.\-\*\ ,]+$ ]]
}

validate_backend() {
  local b="$1"
  [[ "$b" =~ ^https?://.+ ]]
}

add_site_interactive() {
  read -rp "请输入域名（可逗号分隔）: " domains_raw
  if ! validate_domain_input "$domains_raw"; then
    echo "域名格式不合法"
    return
  fi
  read -rp "请输入后端地址（http(s)://...）: " backend
  if ! validate_backend "$backend"; then
    echo "后端地址不合法"
    return
  fi
  local first=$(echo "$domains_raw" | awk -F, '{print $1}' | tr -d '[:space:]')
  local id=$(echo "$first" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g;s/^-*//;s/-*$//')
  [ -z "$id" ] && id="site-$(date +%s)"
  local block=$(generate_site_block "$domains_raw" "$backend" "$id")
  append_site_to_caddyfile "$block"
  systemctl reload caddy || systemctl restart caddy || true
  echo "已添加：${domains_raw} -> ${backend} (id: ${id})"
}

# 支持批量删除（单个/范围/混合）
remove_site_interactive() {
  if [ ! -f "$CADDYFILE" ]; then
    echo "Caddyfile 不存在"
    return
  fi
  mapfile -t ids < <(grep "^# BEGIN ${MANAGED_TAG}" "$CADDYFILE" | sed -E "s/^# BEGIN ${MANAGED_TAG} //")
  mapfile -t domains < <(grep "^# BEGIN ${MANAGED_TAG}" -n "$CADDYFILE" | while IFS=: read -r ln rest; do
    sed -n "$((ln+1))p" "$CADDYFILE" | sed 's/^[[:space:]]*//'
  done)
  if [ ${#ids[@]} -eq 0 ]; then
    echo "没有找到已管理的站点"
    return
  fi
  echo "==== 已管理站点 ===="
  for i in "${!ids[@]}"; do
    echo "$((i+1)): ${domains[$i]}   (id: ${ids[$i]})"
  done
  echo "提示：可输入多个序号，用逗号分隔或范围（如 1,3-5,7）"
  read -rp "请输入要删除的站点序号: " input

  # 解析输入为序号列表
  selection=()
  IFS=',' read -ra parts <<< "$input"
  for part in "${parts[@]}"; do
    if [[ "$part" =~ ^[0-9]+$ ]]; then
      selection+=("$part")
    elif [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
      start=${part%-*}
      end=${part#*-}
      for ((n=start; n<=end; n++)); do
        selection+=("$n")
      done
    else
      echo "无效输入: $part"
      return
    fi
  done

  # 去重排序
  mapfile -t selection < <(printf "%s\n" "${selection[@]}" | sort -n | uniq)

  # 检查有效性
  for num in "${selection[@]}"; do
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt ${#ids[@]} ]; then
      echo "无效序号: $num"
      return
    fi
  done

  echo "即将删除以下站点："
  for num in "${selection[@]}"; do
    echo " - ${domains[$((num-1))]} (id=${ids[$((num-1))]})"
  done

  if confirm "确认删除以上站点吗？"; then
    for num in "${selection[@]}"; do
      remove_site_by_id "${ids[$((num-1))]}"
      echo "已删除 ${domains[$((num-1))]}"
    done
  else
    echo "已取消"
  fi
}

show_caddyfile_contents() {
  [ -f "$CADDYFILE" ] && cat "$CADDYFILE" || echo "Caddyfile 不存在"
}

uninstall_caddy() {
  if ! confirm "确定要卸载并删除所有 Caddy 文件吗？"; then
    return
  fi
  systemctl stop caddy 2>/dev/null || true
  systemctl disable caddy 2>/dev/null || true
  apt purge -y caddy
  apt autoremove -y
  rm -rf /etc/caddy /var/lib/caddy /var/log/caddy /var/run/caddy
  id -u caddy &>/dev/null && userdel -r caddy 2>/dev/null || true
  getent group caddy &>/dev/null && groupdel caddy 2>/dev/null || true
  systemctl daemon-reload || true
  echo "Caddy 已卸载并清理完成"
}

menu_loop() {
  while true; do
    cat <<EOF

=====================================
 Caddy 管理脚本
 1) 安装 Caddy
 2) 添加站点
 3) 列出已管理站点
 4) 删除站点（支持批量序号）
 5) 显示 Caddyfile 内容
 6) 一键卸载 Caddy
 0) 退出
=====================================

EOF
    read -rp "请选择操作 [0-6]: " choice
    case "$choice" in
      1) install_caddy ;;
      2) add_site_interactive ;;
      3) list_sites ;;
      4) remove_site_interactive ;;
      5) show_caddyfile_contents ;;
      6) uninstall_caddy ;;
      0) exit 0 ;;
      *) echo "无效选择" ;;
    esac
  done
}

ensure_root
menu_loop
