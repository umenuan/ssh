while true; do
    clear
    echo "━━━━━━━━━━━━"
    echo "   MY VPS"
    echo "━━━━━━━━━━━━"
    echo " 1. vps"
    echo " 2. abc"
    echo " 3. sss"
    echo " 4. xre"
    echo " 5. hys"
    echo " 6. ipt"
    echo " 7. opt"
    echo " 8. sbx"
    echo " 9. okk"
    echo "────────────"
    echo " 0. exit "
    echo "━━━━━━━━━━━━"
    read -p "select : " select

    case $select in
        1)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/1.sh) ;;
        2)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/2.sh) ;;
        3)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/3.sh) ;;
        4)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/4.sh) ;;
        5)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/5.sh) ;;
        6)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/6.sh) ;;
        7)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/7.sh) ;;
        8)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/8.sh) ;;
        9)  bash <(curl -Ls https://raw.githubusercontent.com/umenuan/ssh/main/9.sh) ;;
        0)  exit ;;
        *)  ;;
    esac
    read -rp "skip..."
done
