#!/bin/bash

D=/etc/sing-box
B=/usr/local/bin/sing-box
S=/etc/systemd/system/sing-box.service
C=$D/config.json

[ $EUID != 0 ]&&exit

install(){
apt update -y >/dev/null
apt install -y curl jq wget openssl >/dev/null

V=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest|jq -r .tag_name)

wget -qO /tmp/s.tar.gz \
https://github.com/SagerNet/sing-box/releases/download/$V/sing-box-${V#v}-linux-amd64.tar.gz

tar xf /tmp/s.tar.gz -C /tmp
cp $(find /tmp -name sing-box -type f|head -1) $B
chmod +x $B

mkdir -p $D

echo "1 Hysteria2"
echo "2 SS2022"
read -p ">" P

IP4=$(curl -s4 ip.sb)
IP6=$(curl -s6 ip.sb)

PORT=$(shuf -i20000-60000 -n1)
PASS=$(openssl rand -hex 16)


if [ $P = 1 ];then

openssl req -x509 -nodes -newkey rsa:2048 \
-keyout $D/key.pem -out $D/cert.pem \
-days 3650 -subj /CN=$IP4 >/dev/null 2>&1


cat >$C <<EOF
{
"inbounds":[{
"type":"hysteria2",
"listen":"::",
"listen_port":$PORT,
"users":[{"password":"$PASS"}],
"tls":{
"enabled":true,
"certificate_path":"$D/cert.pem",
"key_path":"$D/key.pem"
}
}]
}
EOF


echo
echo "HY2:"
echo "hysteria2://$PASS@$IP4:$PORT/?sni=$IP4"
echo
echo "IPv6:"
echo "hysteria2://$PASS@[${IP6}]:$PORT/?sni=$IP4"


else


cat >$C <<EOF
{
"inbounds":[{
"type":"shadowsocks",
"listen":"::",
"listen_port":$PORT,
"method":"2022-blake3-aes-256-gcm",
"password":"$PASS"
}]
}
EOF


SS4=$(echo -n "2022-blake3-aes-256-gcm:$PASS@$IP4:$PORT"|base64 -w0)

SS6=$(echo -n "2022-blake3-aes-256-gcm:$PASS@[$IP6]:$PORT"|base64 -w0)


echo
echo "SS2022:"
echo "ss://$SS4"
echo
echo "IPv6:"
echo "ss://$SS6"

fi


cat >$S <<EOF
[Unit]
After=network.target
[Service]
ExecStart=$B run -c $C
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sing-box

}


upgrade(){
rm -f $B
install
}


remove(){
systemctl disable --now sing-box 2>/dev/null
rm -rf $D $B $S
systemctl daemon-reload
echo done
}


while :

do
clear
echo "
1 安装
2 升级
3 卸载
4 状态
0 退出
"

read -p "> " X

case $X in
1)install;;
2)upgrade;;
3)remove;;
4)systemctl status sing-box --no-pager;;
0)exit;;
esac

read -p "Enter..."
done
