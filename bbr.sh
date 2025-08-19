#!/bin/bash
# ========================================================
# 极简版 BBR + fq_pie 一键启用脚本
# 功能：
#   1. 打印当前系统内核信息
#   2. 检查系统是否支持 BBR 和 fq_pie
#   3. 如果支持，则追加配置到 /etc/sysctl.d/99-sysctl.conf 和 /etc/sysctl.conf
#   4. 执行 sysctl --system 尝试立即生效
# ========================================================

# --------------------------
# 1. 判断是否 root 权限
# --------------------------
if [[ $EUID -ne 0 ]]; then
  echo "请以 root 权限运行: sudo bash $0"
  exit 1
fi

# --------------------------
# 2. 打印当前内核信息
# --------------------------
echo "=== 系统内核信息 ==="
echo "内核名称: $(uname -s)"
echo "内核版本: $(uname -r)"
echo "机器架构: $(uname -m)"
echo "操作系统: $(uname -o)"
echo "===================="
echo

# --------------------------
# 3. 检测 BBR 支持
# --------------------------
# 方法：
#   1. sysctl 查询可用的 TCP 拥塞控制算法列表
#   2. 如果 sysctl 没列出，再看 tcp_bbr 模块是否已加载
#   3. 如果都不满足，判定不支持
bbr=$(
  sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr \
    && echo 1 \
    || lsmod | grep -qw tcp_bbr && echo 1 \
    || echo 0
)

# --------------------------
# 4. 检测 fq_pie 支持
# --------------------------
# 方法：
#   1. 检查 sch_fq_pie 模块是否已加载
#   2. 如果没加载，再用 modinfo 查看内核是否存在该模块（可加载）
#   3. 如果都不满足，判定不支持
fqpie=$(
  lsmod | grep -qw sch_fq_pie \
    && echo 1 \
    || modinfo sch_fq_pie >/dev/null 2>&1 && echo 1 \
    || echo 0
)

# --------------------------
# 5. 输出检测结果
# --------------------------
echo "检测 BBR 支持: $( [ $bbr -eq 1 ] && echo YES || echo NO )"
echo "检测 fq_pie 支持: $( [ $fqpie -eq 1 ] && echo YES || echo NO )"
echo

# --------------------------
# 6. 如果支持，启用 BBR + fq_pie
# --------------------------
if [[ $bbr -eq 1 && $fqpie -eq 1 ]]; then
  echo "检测到系统支持 BBR + fq_pie，开始启用..."
  
  # 将配置追加到 /etc/sysctl.d/99-sysctl.conf
  echo "net.core.default_qdisc=fq_pie" >> /etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-sysctl.conf

  # 同时追加到 /etc/sysctl.conf，以确保传统 sysctl 加载方式也生效
  echo "net.core.default_qdisc=fq_pie" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

  # 尝试立即应用配置
  sysctl --system >/dev/null 2>&1 || true

  echo "BBR + fq_pie 已启用并写入配置文件，重启后依然生效！"
else
  echo "系统不支持 BBR + fq_pie，脚本未修改任何配置。"
  echo "请确认内核或模块是否可用，或考虑升级内核/安装相应模块后再运行此脚本。"
fi
