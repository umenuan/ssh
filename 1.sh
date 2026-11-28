printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s\n" "OS:" "$(. /etc/os-release && echo "$PRETTY_NAME")"
printf "%-12s%s\n" "Kernel:" "$(uname -r)"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s\n" "CPU:" "$(awk -F': *' '/model name/{print $2; exit}' /proc/cpuinfo)"
printf "%-12s%-9s • %-12s • %s\n" "" "$(uname -m)" "$(nproc) cores" "$(awk '/cpu MHz/{printf "%.1f GHz", $4/1000; exit}' /proc/cpuinfo)"
printf "%-12s%s\n" "CPU%:" "$(vmstat 1 2 | awk 'END{print 100-$15 "%"}')"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s • %4s\n" "Mem:"  "$(free -b | awk 'NR==2{printf "%9.2f / %9.2f MB",$3/1048576,$2/1048576}')"  "$(free -b | awk 'NR==2{printf "%.0f%%",$2?$3*100/$2:0}')"
printf "%-12s%s • %4s\n" "Swap:" "$(free -b | awk '/Swap:/{printf "%9.2f / %9.2f MB",$3/1048576,$2/1048576}')" "$(free -b | awk '/Swap:/{printf "%.0f%%",$2?$3*100/$2:0}')"
printf "%-12s%s • %4s\n" "Disk:" "$(df -B1 / | awk 'NR==2{printf "%9.2f / %9.2f MB",$3/1048576,$2/1048576}')" "$(df -h / | awk 'NR==2{printf "%d%%",$5+0}')"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s\n" "Down:" "$(awk 'NR>2{rx+=$2} END {u=0; while(rx>1024&&u<3){rx/=1024;u++}; split("Bytes KB MB GB",a);printf "%.2f %s",rx,a[u+1]}' /proc/net/dev)"
printf "%-12s%s\n" "Up:" "$(awk 'NR>2{tx+=$10} END {u=0; while(tx>1024&&u<3){tx/=1024;u++}; split("Bytes KB MB GB",a);printf "%.2f %s",tx,a[u+1]}' /proc/net/dev)"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s %s\n" "BBR:" "$(sysctl -n net.ipv4.tcp_congestion_control)" "$(sysctl -n net.core.default_qdisc)"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf "%-12s%s\n" "IPv4:" "$(hostname -I | awk '{print $1}')"
printf "%-12s%s\n" "IPv6:" "$(hostname -I | tr ' ' '\n' | grep ':' | head -n 1)"
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
awk '/^nameserver/{printf "%-12s%s\n",(n++?"":"DNS:"),$2}' /etc/resolv.conf
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
uptime
