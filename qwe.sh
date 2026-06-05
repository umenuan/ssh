#!/bin/bash
# ========================================================
# 极简优化版 BBR + fq_pie 一键启用脚本
# ========================================================

# 1. 权限检查
[ "$(id -u)" -ne 0 ] && { echo "错误: 请以 root 权限运行 (sudo sh $0)"; exit 1; }

# 2. 打印内核信息
echo -e "\n===== 系统内核信息 ====="
uname -srpm
echo -e "========================\n"

# 3. 检查并加载模块 (如果加载失败，说明系统不支持)
modprobe tcp_bbr 2>/dev/null
modprobe sch_fq_pie 2>/dev/null

# 4. 验证系统是否真正支持这两项配置
sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr
BBR_SUPPORT=$?

lsmod | grep -qw sch_fq_pie
FQ_PIE_SUPPORT=$?

# 5. 条件判断与配置写入
if [ $BBR_SUPPORT -eq 0 ] && [ $FQ_PIE_SUPPORT -eq 0 ]; then
    echo "检测到系统支持 BBR + fq_pie，正在配置..."

    # 清除旧的冲突配置（防止重复追加）
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

    # 安全地追加新配置到 /etc/sysctl.conf
    cat << EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq_pie
net.ipv4.tcp_congestion_control=bbr
EOF

    # 立即应用配置
    sysctl -p >/dev/null 2>&1

    echo "优化配置已成功写入 /etc/sysctl.conf 并立即生效！"
else
    echo "提示: 当前系统环境不完全支持 BBR + fq_pie，未做任何修改。"
fi

# 6. 打印当前最终状态
echo -e "\n=============================================="
echo "验证当前生效的配置："
sysctl net.ipv4.tcp_congestion_control net.core.default_qdisc 2>/dev/null
echo "=============================================="
