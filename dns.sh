#!/bin/bash
echo -e "1) Cloudflare\n2) Google"
read -rp "Pick [1-2]: " c
case $c in
  1) dns="1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001";;
  2) dns="8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844";;
  *) exit 1;;
esac
: >/etc/resolv.conf; for i in $dns; do echo "nameserver $i" >> /etc/resolv.conf; done
cat /etc/resolv.conf
