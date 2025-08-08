#!/bin/bash
# Nginx 多站点反代 + Let's Encrypt 管理脚本

set -e

NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
CERT_DIR="/etc/letsencrypt/live"

function install_packages() {
    apt update && apt upgrade -y
    apt install -y nginx certbot python3-certbot-nginx
    systemctl enable nginx
    systemctl start nginx
}

function add_site() {
    read -p "请输入域名 (例如 example.com): " DOMAIN
    read -p "请输入后端地址 (例如 http://127.0.0.1:5000): " BACKEND

    CONF_PATH="$NGINX_CONF_DIR/$DOMAIN"

    if [ -f "$CONF_PATH" ]; then
        echo "❌ 域名 $DOMAIN 已存在，请先删除再添加。"
        return
    fi

    cat > $CONF_PATH <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass $BACKEND;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    ln -sf $CONF_PATH $NGINX_ENABLED_DIR/
    nginx -t && systemctl reload nginx

    echo "📜 正在申请 SSL..."
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN --redirect

    echo "✅ 站点 $DOMAIN 添加完成"
}

function delete_site() {
    read -p "请输入要删除的域名: " DOMAIN

    CONF_PATH="$NGINX_CONF_DIR/$DOMAIN"
    ENABLED_PATH="$NGINX_ENABLED_DIR/$DOMAIN"
    CERT_PATH="$CERT_DIR/$DOMAIN"

    if [ ! -f "$CONF_PATH" ]; then
        echo "❌ 域名 $DOMAIN 不存在"
        return
    fi

    echo "⚠ 正在删除 $DOMAIN ..."
    rm -f "$CONF_PATH"
    rm -f "$ENABLED_PATH"

    if [ -d "$CERT_PATH" ]; then
        certbot delete --cert-name $DOMAIN -n || true
    fi

    nginx -t && systemctl reload nginx
    echo "✅ 域名 $DOMAIN 删除完成"
}

function list_sites() {
    echo "📋 已配置站点："
    ls $NGINX_CONF_DIR
}

function uninstall_all() {
    echo "⚠ 警告：将卸载 Nginx、Certbot 及所有站点配置和证书！"
    read -p "确定继续吗？[y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        systemctl stop nginx || true
        systemctl stop certbot || true
        apt purge -y nginx certbot python3-certbot-nginx
        apt autoremove -y
        apt clean
        rm -rf /etc/nginx
        rm -rf /var/log/nginx
        rm -rf /var/www/html
        rm -rf /etc/letsencrypt
        rm -rf /var/lib/letsencrypt
        rm -rf /var/log/letsencrypt
        echo "✅ 已彻底卸载"
    else
        echo "已取消"
    fi
}

echo "=================================="
echo "   Nginx 多站点反代管理脚本"
echo "=================================="
echo "1) 安装依赖（第一次运行必选）"
echo "2) 添加站点（反代 + SSL）"
echo "3) 删除站点（指定域名）"
echo "4) 查看所有站点"
echo "5) 卸载所有服务和配置（彻底删除）"
read -p "请选择操作 [1-5]: " ACTION

case $ACTION in
    1) install_packages ;;
    2) add_site ;;
    3) delete_site ;;
    4) list_sites ;;
    5) uninstall_all ;;
    *) echo "无效选择" ;;
esac
