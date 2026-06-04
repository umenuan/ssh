clear
eval $(curl -s ipinfo.io/json | awk -F'"' '/"ip"/{ip=$4} /"city"/{city=$4} /"country"/{country=$4} /"org"/{org=$4} END{print "ipv4_address=\""ip"\";city=\""city"\";country=\""country"\";isp_info=\""org"\""}')
cpu_info=$(awk -F: '/model name/ {sub(/^ */,"",$2); print $2; exit}' /proc/cpuinfo)
cpu_usage_percent=$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.2f%%", $2+$4}')
eval $(free -m | awk 'NR==2{printf "mem_info=\"%d/%d MB (%.2f%%)\"", $3,$2,$3*100/$2} NR==3{printf "swap_info=\"%d/%d MB (%.2f%%)\"", $3,$2,$2?$3*100/$2:0}')
disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3,$2,$5}')
os_info=$(lsb_release -ds 2>/dev/null || echo "Debian $(cat /etc/debian_version 2>/dev/null)")
runtime=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); printf "%s%s%s", d?d"天 ":"", h?h"小时 ":"", m?m"分钟":""}' /proc/uptime)
net_traffic=$(awk 'NR>2{rx+=$2; tx+=$10} END {split("Bytes KB MB GB", u); while(rx>1024&&r<3){rx/=1024; r++}; while(tx>1024&&t<3){tx/=1024; t++}; printf "总接收: %.2f %s\n总发送: %.2f %s", rx, u[r+1], tx, u[t+1]}' /proc/net/dev)
echo -e "
${white}系统信息详情${re}
------------------------
${white}主机名: ${purple}$(hostname)${re}
${white}运营商: ${purple}${isp_info}${re}
------------------------
${white}系统版本: ${purple}${re}${purple}${os_info}${re}
${white}Linux内核: ${purple}$(uname -r)${re}
------------------------
${white}CPU架构: ${purple}$(uname -m)${re}
${white}CPU型号: ${purple}${cpu_info}${re}
${white}CPU核心数: ${purple}$(nproc)${re}
------------------------
${white}CPU占用: ${purple}${cpu_usage_percent}${re}
${white}物理内存: ${purple}${mem_info}${re}
${white}虚拟内存: ${purple}${swap_info}${re}
${white}硬盘占用: ${purple}${disk_info}${re}
------------------------
${purple}${net_traffic}${re}
------------------------
${white}网络拥堵算法: ${purple}$(sysctl -n net.ipv4.tcp_congestion_control) $(sysctl -n net.core.default_qdisc)${re}
------------------------
${white}公网IPv4地址: ${purple}${ipv4_address}${re}
${white}公网IPv6地址: ${purple}${ipv6_address}${re}
------------------------
${white}地理位置: ${purple}${country} ${city}${re}
${white}系统时间: ${purple}$(date "+%Y-%m-%d %I:%M %p")${re}
------------------------
${white}系统运行时长: ${purple}${runtime}${re}

${yellow}按任意键返回...${re}"
read -n 1 -s -r -p ""
echo ""
;;
