apt update && apt upgrade -y
apt autoremove --purge -y && apt clean && apt autoclean
apt install -y curl wget unzip sudo ufw openssl jq tar xz-utils nload
echo "net.core.default_qdisc=fq" > /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl --system >/dev/null 2>&1
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 2001:4860:4860::8888\nnameserver 2001:4860:4860::8844" > /etc/resolv.conf
#echo -e "nameserver 1.1.1.1\nnameserver 1.0.0.1\nnameserver 2606:4700:4700::1111\nnameserver 2606:4700:4700::1001" > /etc/resolv.conf
