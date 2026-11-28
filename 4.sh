#!/bin/bash

download() {
  curl -fsSL --create-dirs -o /opt/vless/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip -oq /opt/vless/xray.zip xray -d /opt/vless
  rm -f /opt/vless/xray.zip
  chmod +x /opt/vless/xray
}

install() {
  p=8443; u=$(cat /proc/sys/kernel/random/uuid); sn=www.sony.com
  read -rp "port [$p]: " x; p=${x:-$p}
  read -rp "uuid [$u]: " x; u=${x:-$u}
  read -rp "sni [$sn]: " x; sn=${x:-$sn}
  download
  k=($(/opt/vless/xray x25519 | awk '{print $NF}'))
  s=$(openssl rand -hex 8)
  cat > /opt/vless/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": $p,
    "protocol": "vless",
    "settings": {
      "clients": [{"id": "$u", "flow": "xtls-rprx-vision"}],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "dest": "$sn:443",
        "serverNames": ["$sn"],
        "privateKey": "${k[0]}",
        "shortIds": ["$s"]
      }
    }
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
  cat > /etc/systemd/system/vless.service <<EOF
[Unit]
After=network.target
[Service]
ExecStart=/opt/vless/xray run -c /opt/vless/config.json
Restart=on-failure
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now vless
  ufw allow "$p"/tcp >/dev/null 2>&1
  ip=$(hostname -I | awk '{print $1}')
  echo "vless://$u@$ip:$p?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sn&fp=chrome&pbk=${k[1]}&sid=$s&type=tcp#vless-reality" > /opt/vless/link.txt
  cat /opt/vless/link.txt
}

upgrade() {
  systemctl stop vless
  download
  systemctl start vless
}

uninstall() {
  systemctl disable --now vless
  awk -F'[@:?#]' '{print "ufw delete allow " $4 "/tcp"}' /opt/vless/link.txt 2>/dev/null | sh >/dev/null 2>&1
  rm -rf /etc/systemd/system/vless.service /opt/vless
  systemctl daemon-reload
}

while true; do
  clear
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "    Vless + Reality"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 1. Install"
  echo " 2. Upgrade"
  echo " 3. Uninstall"
  echo " 4. Show"
  echo " 0. exit"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -rp "select : " select
  case $select in
    1) install ;;
    2) upgrade ;;
    3) uninstall ;;
    4) cat /opt/vless/link.txt ;;
    0) exit ;;
  esac
  read -rp "skip..."
done
