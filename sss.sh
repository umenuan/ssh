clear

# CPU
read cpu_info cpu_freq <<<$(awk -F': ' '/model name/&&!m{m=$2}/cpu MHz/&&!f{f=sprintf("%.0fMHz",$2)}END{print "\""m"\"" ,f}' /proc/cpuinfo)
cpu_cores=$(grep -c '^processor' /proc/cpuinfo)
cpu_usage_percent="$(top -bn1 | awk -F'[, %]+' '/Cpu\(s\)/{printf "%.2f",$2+$4}')%"

# 内存
read mem_used mem_total mem_percent cache_used swap_used swap_total <<<$(free -m | awk '
NR==2{mu=$3;mt=$2;mp=$3*100/$2;c=$6}
NR==3{su=$3;st=$2}
END{printf "%.2f %.2f %.2f %d %d %d",mu,mt,mp,c,su,st}')

mem_info="${mem_used}/${mem_total} MB (${mem_percent}%)"
cache_info="${cache_used}MB"
swap_percentage=0; [ "$swap_total" -gt 0 ] && swap_percentage=$((swap_used*100/swap_total))
swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

# 磁盘
disk_info=$(df -BG / | awk 'NR==2{gsub(/G/,"",$3);gsub(/G/,"",$2);printf "%d/%dGB (%s)",$3,$2,$5}')

# IP归属地
read country city isp_info <<<$(curl -s --connect-timeout 3 ipinfo.io/json | awk -F'"' '/"country"/{c=$4}/"city"/{ci=$4}/"org"/{o=$4}END{print c,ci,o}')

# 系统
hostname=$(cat /proc/sys/kernel/hostname)
cpu_arch=$(uname -m)
kernel_version=$(cat /proc/sys/kernel/osrelease)
congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
queue_algorithm=$(sysctl -n net.core.default_qdisc 2>/dev/null)

os_info=$(lsb_release -ds 2>/dev/null)
[ -z "$os_info" ] && os_info="Debian $(cat /etc/debian_version 2>/dev/null)"

virt_type=$(systemd-detect-virt 2>/dev/null); [ -z "$virt_type" ] && virt_type="Dedicated"
timezone=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||'); [ -z "$timezone" ] && timezone=$(cat /etc/timezone 2>/dev/null)
boot_time=$(uptime -s 2>/dev/null)

# 网卡速率
nic=$(ip route | awk '/default/{print $5;exit}')
[ -f "/sys/class/net/$nic/speed" ] && nic_speed=$(cat "/sys/class/net/$nic/speed" 2>/dev/null)
[ "$nic_speed" -gt 0 ] 2>/dev/null && nic_speed="${nic_speed}Mb/s"
[ -z "$nic_speed" ] && nic_speed="Unknown"

# 流量统计
output=$(awk '
function human(x){split("Bytes KB MB GB TB",u);for(i=1;x>=1024&&i<5;i++)x/=1024;return sprintf("%.2f %s",x,u[i])}
NR>2{rx+=$2;tx+=$10}
END{printf("总接收: %s\n总发送: %s\n",human(rx),human(tx))}
' /proc/net/dev)

current_time=$(date "+%Y-%m-%d %H:%M:%S")
runtime=$(awk -F. '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);if(d>0)printf("%d天 ",d);if(h>0)printf("%d小时 ",h);if(m>0)printf("%d分钟",m)}' /proc/uptime)

cat <<EOF

${white}系统信息${re}
------------------------
${white}主机名: ${purple}${hostname}${re}
${white}运营商: ${purple}${isp_info}${re}
------------------------
${white}系统版本: ${purple}${os_info}${re}
${white}Linux内核: ${purple}${kernel_version}${re}
${white}虚拟化类型: ${purple}${virt_type}${re}
------------------------
${white}CPU架构: ${purple}${cpu_arch}${re}
${white}CPU型号: ${purple}${cpu_info}${re}
${white}CPU频率: ${purple}${cpu_freq}${re}
${white}CPU核心数: ${purple}${cpu_cores}${re}
------------------------
${white}CPU占用: ${purple}${cpu_usage_percent}${re}
${white}物理内存: ${purple}${mem_info}${re}
${white}虚拟内存: ${purple}${swap_info}${re}
${white}缓存占用: ${purple}${cache_info}${re}
${white}硬盘占用: ${purple}${disk_info}${re}
------------------------
${purple}${output}${re}${white}网卡速率: ${purple}${nic_speed}${re}
------------------------
${white}网络拥堵算法: ${purple}${congestion_algorithm} ${queue_algorithm}${re}
------------------------
${white}公网IPv4地址: ${purple}${ipv4_address}${re}
${white}公网IPv6地址: ${purple}${ipv6_address}${re}
------------------------
${white}地理位置: ${purple}${country} ${city}${re}
${white}系统时区: ${purple}${timezone}${re}
${white}系统时间: ${purple}${current_time}${re}
------------------------
${white}启动时间: ${purple}${boot_time}${re}
${white}运行时长: ${purple}${runtime}${re}

${yellow}按任意键返回...${re}
EOF

read -rsn1
echo ""
;;
