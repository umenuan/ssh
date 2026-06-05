#!/bin/bash

echo "net.core.default_qdisc=fq" > /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

sysctl --system >/dev/null 2>&1

sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc
