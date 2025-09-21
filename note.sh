#!/bin/bash

DB_FILE="/root/notifications.db"

send_tg() {
    local token="$1"
    local chat_id="$2"
    local msg="$3"
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d chat_id="$chat_id" \
        -d text="$msg" > /dev/null
}

add_notify() {
    read -p "请输入通知名称: " name
    read -p "请输入到期日期 (格式: YYYY-MM-DD): " date
    read -p "请输入 Telegram Bot Token: " token
    read -p "请输入 Telegram Chat ID: " chat_id

    if ! date -d "$date" >/dev/null 2>&1; then
        echo "❌ 日期格式错误，请使用 YYYY-MM-DD"
        return
    fi

    echo "$name|$date|$token|$chat_id" >> "$DB_FILE"
    echo "✅ 通知已添加: $name | $date"
}

delete_notify() {
    read -p "请输入要删除的通知名称: " name
    if grep -q "^$name|" "$DB_FILE" 2>/dev/null; then
        new_content=$(grep -v "^$name|" "$DB_FILE")
        echo "$new_content" > "$DB_FILE"
        echo "🗑 已彻底删除通知: $name"
    else
        echo "未找到通知: $name"
    fi
}

modify_notify() {
    read -p "请输入要修改的通知名称: " name
    if ! grep -q "^$name|" "$DB_FILE" 2>/dev/null; then
        echo "未找到通知: $name"
        return
    fi

    old_line=$(grep "^$name|" "$DB_FILE")
    IFS="|" read -r old_name old_date old_token old_chat <<< "$old_line"

    echo "当前信息: 名称=$old_name, 到期=$old_date, Token=$old_token, ChatID=$old_chat"
    read -p "新到期日期 (YYYY-MM-DD, 回车保留不变): " new_date
    read -p "新的 Telegram Bot Token (回车保留不变): " new_token
    read -p "新的 Telegram Chat ID (回车保留不变): " new_chat

    [ -z "$new_date" ] && new_date="$old_date"
    [ -z "$new_token" ] && new_token="$old_token"
    [ -z "$new_chat" ] && new_chat="$old_chat"

    if ! date -d "$new_date" >/dev/null 2>&1; then
        echo "❌ 日期格式错误，修改失败"
        return
    fi

    new_line="$name|$new_date|$new_token|$new_chat"

    new_content=$(grep -v "^$name|" "$DB_FILE")
    echo "$new_content" > "$DB_FILE"
    echo "$new_line" >> "$DB_FILE"

    echo "✏️ 已更新通知: $name | $new_date"
}

list_notify() {
    if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
        echo "暂无通知"
        return
    fi

    echo "📋 当前通知列表:"
    echo "--------------------------------"
    while IFS="|" read -r name date token chat_id; do
        now=$(date +%s)
        expire=$(date -d "$date" +%s)
        days=$(( (expire - now) / 86400 ))
        echo "$name | $date | 剩余 $days 天"
    done < "$DB_FILE"
    echo "--------------------------------"
}

check_notify() {
    if [ ! -f "$DB_FILE" ] || [ ! -s "$DB_FILE" ]; then
        return
    fi

    new_content=""
    while IFS="|" read -r name date token chat_id; do
        now=$(date +%s)
        expire=$(date -d "$date" +%s)
        days=$(( (expire - now) / 86400 ))

        # 到期前提醒
        if [ "$days" -ge 0 ] && [ "$days" -le 3 ]; then
            if [ "$days" -eq 0 ]; then
                msg="
                🚨 最后提醒
                名称: $name
                到期日: $date
                剩余天数: 0 天"
            elif [ "$days" -eq 1 ]; then
                msg="
                ⚠️ 到期提醒
                名称: $name
                到期日: $date
                剩余天数: 1 天"
            else
                msg="
                ⏰ 提醒通知
                名称: $name
                到期日: $date
                剩余天数: $days 天"
            fi
            send_tg "$token" "$chat_id" "$msg"
        fi

        # 已过期，自动删除并通知
        if [ "$days" -lt 0 ]; then
            del_msg="🗑 通知已过期并删除\n名称: $name\n到期日: $date"
            send_tg "$token" "$chat_id" "$del_msg"
            continue
        fi

        # 保存未过期的通知
        new_content+="$name|$date|$token|$chat_id"$'\n'
    done < "$DB_FILE"

    echo -n "$new_content" > "$DB_FILE"
}

setup_cron() {
    SCRIPT_PATH=$(realpath "$0")
    CRON_JOB="0 9 * * * $SCRIPT_PATH check"

    if crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH check"; then
        echo "✅ 已存在定时任务 (每天09:00检查通知)"
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "✅ 已添加定时任务 (每天09:00执行通知检查)"
    fi
}

menu() {
    while true; do
        echo
        echo "========== 通知管理 =========="
        echo "1) 添加通知"
        echo "2) 删除通知"
        echo "3) 修改通知"
        echo "4) 列出通知"
        echo "5) 检查并发送TG提醒"
        echo "6) 设置每日自动检查 (cron)"
        echo "7) 退出"
        echo "=============================="
        read -p "请选择操作 [1-7]: " choice

        case "$choice" in
            1) add_notify ;;
            2) delete_notify ;;
            3) modify_notify ;;
            4) list_notify ;;
            5) check_notify ;;
            6) setup_cron ;;
            7) echo "退出程序"; exit 0 ;;
            *) echo "无效选择，请重新输入" ;;
        esac
    done
}

# ============ 主程序入口 ============
if [ "$1" = "check" ]; then
    check_notify
    exit 0
fi

menu
