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
if [ "$(id -u)" -ne 0 ]; then
  echo "请以 root 权限运行: sudo sh $0"
  exit 1
fi

# --------------------------
# 2. 打印当前系统内核信息
# --------------------------
echo
echo "===== 系统内核信息 ====="
echo "内核名称: $(uname -s)"
echo "内核版本: $(uname -r)"
echo "机器架构: $(uname -m)"
echo "操作系统: $(uname -o)"
echo "========================"
echo

# --------------------------
# 3. 检测 BBR 支持
# --------------------------
# 初始化变量
bbr=0
modprobe tcp_bbr

# 方法1: 查询可用的 TCP 拥塞控制算法
# sysctl 输出类似: cubic reno bbr
# grep -qw bbr 检查 bbr 是否存在，存在则 bbr=1
sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr && bbr=1

# 方法2: 如果模块已经加载，也算支持
# lsmod | grep tcp_bbr 检查 tcp_bbr 模块是否已加载
lsmod | grep -qw tcp_bbr && bbr=1

# --------------------------
# 4. 检测 fq_pie 支持
# --------------------------
# 初始化变量
fqpie=0

# 方法1: 检查 sch_fq_pie 模块是否已经加载
lsmod | grep -qw sch_fq_pie && fqpie=1

# 方法2: 如果内核存在该模块（可加载），也算支持
# modinfo 成功则 fqpie=1
modinfo sch_fq_pie >/dev/null 2>&1 && fqpie=1

# --------------------------
# 5. 输出检测结果
# --------------------------
# 根据变量值打印是否支持
echo "检测 BBR 支持: $( [ $bbr -eq 1 ] && echo YES || echo NO )"
echo "检测 fq_pie 支持: $( [ $fqpie -eq 1 ] && echo YES || echo NO )"
echo

# --------------------------
# 6. 如果支持，启用 BBR + fq_pie
# --------------------------
if [ $bbr -eq 1 ] && [ $fqpie -eq 1 ]; then
  echo "检测到系统支持 BBR + fq_pie，开始启用..."

  # 将配置追加到 /etc/sysctl.d/99-sysctl.conf
  # net.core.default_qdisc=fq_pie 表示默认队列调度器使用 fq_pie
  # net.ipv4.tcp_congestion_control=bbr 表示 TCP 拥塞控制使用 BBR
  echo "net.core.default_qdisc=fq_pie" > /etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.d/99-sysctl.conf

  # 同时追加到 /etc/sysctl.conf，以确保传统 sysctl 加载方式也生效
  echo "net.core.default_qdisc=fq_pie" > /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" > /etc/sysctl.conf

  # 尝试立即应用配置
  # 如果某些条目无法生效，忽略错误继续
  sysctl --system >/dev/null 2>&1 || true

  echo -e "/etc/sysctl.d/99-sysctl.conf\n/etc/sysctl.conf"
  echo "BBR + fq_pie 已启用并写入配置文件，重启后依然生效！"

else
  # 如果不支持，则提示用户
  echo "系统不支持 BBR + fq_pie，脚本未修改配置。"
  echo "请确认内核或模块是否可用，或考虑升级内核/安装相应模块后再运行此脚本。"
fi

  echo "=============================================="
  echo "当前 TCP 拥塞控制算法和默认队列调度器"
  echo -n "TCP 拥塞控制算法: "
  sysctl net.ipv4.tcp_congestion_control 2>/dev/null
  echo -n "队列调度器: "
  sysctl net.core.default_qdisc 2>/dev/null
  echo "==============================================="
