#!/bin/bash
# Debian 一键开启 BBR + fq

if [ "$EUID" -ne 0 ]; then
  echo "请用 root 用户运行"
  exit 1
fi

echo "=== 开始配置 BBR + fq ==="

# 写入配置
cat >> /etc/sysctl.conf <<EOF

# BBR + fq 优化
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# 立即生效
sysctl -p

echo
echo "=== 检查设置是否生效 ==="
qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)

echo "当前队列调度器: $qdisc"
echo "当前拥塞控制算法: $cc"

if [[ "$qdisc" == "fq" && "$cc" == "bbr" ]]; then
    if lsmod | grep -qw bbr; then
        echo "✅ BBR + fq 已成功启用"
    else
        echo "⚠️ 参数已设置，但未检测到 bbr 模块，建议重启后再确认"
    fi
else
    echo "❌ 设置未生效，可能需要重启或升级内核 (>=4.9)"
fi
