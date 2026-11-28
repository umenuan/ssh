#!/bin/bash

download() {
  v=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/SagerNet/sing-box/releases/latest | sed 's/.*\/v//')
  curl -fL --create-dirs -o /opt/sing-box/sb.tar.gz https://github.com/SagerNet/sing-box/releases/download/v$v/sing-box-$v-linux-amd64.tar.gz
  tar -xzf /opt/sing-box/sb.tar.gz -C /opt/sing-box --strip-components=1 --wildcards '*/sing-box'
  rm -f /opt/sing-box/sb.tar.gz
  chmod +x /opt/sing-box/sing-box
}

install() {
  vp=8443; hp=55555; sp=33333;
  sn=www.sony.com
  me="2022-blake3-aes-256-gcm"
  uu=$(cat /proc/sys/kernel/random/uuid)
  si=$(openssl rand -hex 8)
  hk=$(openssl rand -hex 16)
  sk=$(openssl rand -base64 32)
  ip=$(hostname -I | awk '{print $1}')

  read -rp "[$sn]: " x; sn=${x:-$sn}
  read -rp "[$vp]: " x; vp=${x:-$vp}
  read -rp "[$uu]: " x; uu=${x:-$uu}
  read -rp "[$hp]: " x; hp=${x:-$hp}
  read -rp "[$hk]: " x; hk=${x:-$hk}
  read -rp "[$sp]: " x; sp=${x:-$sp}
  read -rp "[$sk]: " x; sk=${x:-$sk}
  
  rm -rf /opt/sing-box

  ufw allow "$vp"/tcp >/dev/null 2>&1
  ufw allow "$hp"/udp >/dev/null 2>&1
  ufw allow "$sp"/tcp >/dev/null 2>&1

  download

  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /opt/sing-box/key.pem -out /opt/sing-box/cert.pem -subj "/CN=hy2.local" 2>/dev/null
    
  pinSHA256=$(openssl x509 -noout -fingerprint -sha256 -in /opt/sing-box/cert.pem | cut -d= -f2)
  
  pk=($(/opt/sing-box/sing-box generate reality-keypair | awk '{print $NF}'))

  cat > /opt/sing-box/config.json <<EOF
{
  "log": {"level": "warn"},
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $vp,
      "users": [{"uuid": "$uu", "flow": "xtls-rprx-vision"}],
      "tls": {
        "enabled": true,
        "server_name": "$sn",
        "reality": {
          "enabled": true,
          "handshake": {"server": "$sn", "server_port": 443},
          "private_key": "${pk[0]}",
          "short_id": ["$si"]
        }
      }
    },
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $hp,
      "users": [{"password": "$hk"}],
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "/opt/sing-box/cert.pem",
        "key_path": "/opt/sing-box/key.pem"
      }
    },
    {
      "type": "shadowsocks",
      "listen": "::",
      "listen_port": $sp,
      "method": "$me",
      "password": "$sk"
    }
  ],
  "outbounds": [{"type": "direct"}]
}
EOF
  cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target
[Service]
ExecStart=/opt/sing-box/sing-box run -c /opt/sing-box/config.json
Restart=on-failure
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now sing-box
  base=$(echo -n "$me:$sk" | base64 -w0)
  cat > /opt/sing-box/link.txt <<EOF
vless://$uu@$ip:$vp?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sn&fp=chrome&pbk=${pk[1]}&sid=$si&type=tcp#reality
hysteria2://$hk@$ip:$hp?insecure=1&pinSHA256=${pinSHA256}#hy2
ss://$base@$ip:$sp#ss2022
EOF
  cat /opt/sing-box/link.txt
}

upgrade() {
  systemctl stop sing-box
  download
  systemctl start sing-box
  /opt/sing-box/sing-box version | head -1
}

uninstall() {
  systemctl disable --now sing-box
  awk -F'[@:?#]' '{print "ufw delete allow " $4 ($1=="hysteria2"?"/udp":"/tcp")}' /opt/sing-box/link.txt 2>/dev/null | sh >/dev/null 2>&1
  rm -rf /etc/systemd/system/sing-box.service /opt/sing-box
  systemctl daemon-reload
}

while true; do
  clear
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Sing-box Vless/Hy2/SS2022"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 1. Install"
  echo " 2. Upgrade"
  echo " 3. Uninstall"
  echo " 4. Show"
  echo " 0. exit"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -rp "select : " select
  case $select in
    1) install ;;
    2) upgrade ;;
    3) uninstall ;;
    4) cat /opt/sing-box/link.txt ;;
    0) exit ;;
  esac
  read -rp "skip..."
done
