#!/bin/bash
# ======================================================
# SOCKS5 一键安装脚本 (Dante-server)
# 交互式输入端口/用户名/密码 & 输出节点链接
# 适用系统: Debian/Ubuntu
# ======================================================

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请用 root 权限运行！"
  exit 1
fi

# 用户输入
read -p "请输入 SOCKS5 端口 [默认1080]: " SOCKS_PORT
SOCKS_PORT=${SOCKS_PORT:-1080}

read -p "请输入用户名 [默认user1]: " SOCKS_USER
SOCKS_USER=${SOCKS_USER:-user1}

read -sp "请输入密码 [默认password123]: " SOCKS_PASS
echo
SOCKS_PASS=${SOCKS_PASS:-password123}

# 安装 dante-server
apt update -y
apt install -y dante-server

# 获取出口网卡
EXT_IF=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

# 生成配置文件
cat > /etc/danted.conf <<EOF
logoutput: syslog
internal: 0.0.0.0 port = $SOCKS_PORT
external: $EXT_IF

method: username none
user.notprivileged: nobody

client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: connect disconnect
}

socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  command: connect udpassociate bind
  log: connect disconnect
}
EOF

# 创建 socks 用户
id -u $SOCKS_USER >/dev/null 2>&1 || useradd -M -s /usr/sbin/nologin $SOCKS_USER
echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd

# 启动并开机自启
systemctl enable danted
systemctl restart danted

# 放行防火墙端口（如有 ufw）
if command -v ufw >/dev/null 2>&1; then
    ufw allow $SOCKS_PORT/tcp
fi

# 获取公网 IP
SERVER_IP=$(curl -s ipv4.icanhazip.com)

# 输出信息
echo "===================================="
echo "SOCKS5 安装完成！"
echo "服务器地址: $SERVER_IP"
echo "端口: $SOCKS_PORT"
echo "账号: $SOCKS_USER"
echo "密码: $SOCKS_PASS"
echo "配置文件: /etc/danted.conf"
echo "------------------------------------"
echo "节点链接:"
echo "socks5://$SOCKS_USER:$SOCKS_PASS@$SERVER_IP:$SOCKS_PORT"
echo "===================================="
