while true; do
    clear
    echo "━━━━━━━━━━━━━━━━━"
    echo "   Toggle IP"
    echo "━━━━━━━━━━━━━━━━━"
    nft list table ip  blk >/dev/null 2>&1 && echo "IPv4: disabled" || echo "IPv4: enabled"
    nft list table ip6 blk >/dev/null 2>&1 && echo "IPv6: disabled" || echo "IPv6: enabled"
    echo "━━━━━━━━━━━━━━━━━"
    echo "1. Toggle IPv4"
    echo "2. Toggle IPv6"
    echo "0. exit"
    echo "━━━━━━━━━━━━━━━━━"
    read -p "select : " select
    case "$select" in
        1) f=ip ;;
        2) f=ip6 ;;
        0) exit ;;
        *) continue ;;
    esac
    nft list table $f blk >/dev/null 2>&1 && nft delete table $f blk || nft "add table $f blk; add chain $f blk o { type filter hook output priority 0; }; add rule $f blk o oifname != lo ct state new reject"
done
