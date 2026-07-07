#!/bin/bash

# Sing-box 一键安装脚本
# Debian AMD64

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

INSTALL_DIR="/etc/sing-box"
BIN="/usr/local/bin/sing-box"
SERVICE="/etc/systemd/system/sing-box.service"
CONFIG="$INSTALL_DIR/config.json"


check_root(){
    if [ "$EUID" != "0" ]; then
        echo -e "${RED}请使用root运行${RESET}"
        exit 1
    fi
}


install_dep(){
    apt update -y
    apt install -y curl wget jq unzip openssl
}


get_latest(){

    echo "获取最新sing-box版本..."

    VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest \
    | jq -r .tag_name)

    if [ -z "$VERSION" ];then
        echo "获取版本失败"
        exit 1
    fi

    echo "最新版本: $VERSION"
}


install_box(){

    install_dep
    get_latest


    mkdir -p $INSTALL_DIR


    URL="https://github.com/SagerNet/sing-box/releases/download/${VERSION}/sing-box-${VERSION#v}-linux-amd64.tar.gz"


    cd /tmp

    wget -O singbox.tar.gz $URL


    tar -xzf singbox.tar.gz


    BINFILE=$(find . -name sing-box -type f | head -1)


    cp $BINFILE $BIN
    chmod +x $BIN


    echo -e "${GREEN}sing-box安装完成${RESET}"


    create_config

    create_service

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl restart sing-box


}


create_config(){

echo
echo "选择协议:"
echo "1) Hysteria2"
echo "2) Shadowsocks 2022"

read -p "输入选择:" PROTOCOL


PORT=$(shuf -i 10000-60000 -n1)


mkdir -p $INSTALL_DIR



if [ "$PROTOCOL" = "1" ];then


PASSWORD=$(openssl rand -base64 18)


cat > $CONFIG <<EOF
{
  "log": {
    "level": "info"
  },

  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $PORT,

      "users": [
        {
          "password": "$PASSWORD"
        }
      ],

      "tls": {
        "enabled": true,
        "certificate_path": "/etc/sing-box/server.crt",
        "key_path": "/etc/sing-box/server.key"
      }
    }
  ]
}
EOF


openssl req -x509 -nodes \
-days 3650 \
-newkey rsa:2048 \
-keyout $INSTALL_DIR/server.key \
-out $INSTALL_DIR/server.crt \
-subj "/CN=bing.com"



echo
echo "=============================="
echo "Hysteria2配置"
echo "端口: $PORT"
echo "密码: $PASSWORD"
echo "证书: 自签名"
echo "=============================="


elif [ "$PROTOCOL" = "2" ];then


PASSWORD=$(openssl rand -hex 16)


cat > $CONFIG <<EOF
{
"log":{
"level":"info"
},

"inbounds":[
{
"type":"shadowsocks",
"tag":"ss2022",
"listen":"::",
"listen_port":$PORT,
"method":"2022-blake3-aes-256-gcm",
"password":"$PASSWORD"
}
]
}
EOF


echo
echo "=============================="
echo "Shadowsocks 2022"
echo "端口: $PORT"
echo "密码: $PASSWORD"
echo "加密: 2022-blake3-aes-256-gcm"
echo "=============================="



else

echo "错误选择"
exit

fi

}


create_service(){

cat > $SERVICE <<EOF

[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=$BIN run -c $CONFIG
Restart=always

[Install]
WantedBy=multi-user.target

EOF

}



upgrade_box(){

systemctl stop sing-box

rm -f $BIN

install_box

echo "升级完成"

}



uninstall_box(){

echo "正在完全卸载..."

systemctl stop sing-box 2>/dev/null
systemctl disable sing-box 2>/dev/null


rm -f $SERVICE
rm -rf $INSTALL_DIR
rm -f $BIN


systemctl daemon-reload


echo -e "${GREEN}sing-box 已完全删除${RESET}"

}



status_box(){

systemctl status sing-box --no-pager

}



menu(){

clear

echo "=============================="
echo " sing-box 一键管理脚本"
echo " Debian AMD64"
echo "=============================="

echo "1. 安装 sing-box"
echo "2. 升级 sing-box"
echo "3. 完全卸载"
echo "4. 查看状态"
echo "5. 重启服务"
echo "0. 退出"

echo

read -p "请选择:" NUM


case $NUM in

1)
install_box
;;

2)
upgrade_box
;;

3)
uninstall_box
;;

4)
status_box
;;

5)
systemctl restart sing-box
;;

0)
exit
;;

*)
echo "错误"
;;

esac

}


check_root


while true
do
menu
echo
read -p "按回车继续..."
done
