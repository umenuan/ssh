```
bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/univel.sh)
```
```
apt update && apt upgrade -y && apt install curl -y
```
```
echo "net.core.default_qdisc=fq" > /etc/sysctl.conf && echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf && sysctl --system >/dev/null 2>&1
```
```
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4\nnameserver 2001:4860:4860::8888\nnameserver 2001:4860:4860::8844" > /etc/resolv.conf
```
