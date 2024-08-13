#!/bin/bash

# 脚本用法
usage() {
    echo "Usage: $0 {-L|list|add|del} [<set_name>] [<ip_address>]"
    echo "  -L                            List all IP sets"
    echo "  -L <set_name>               List IPs in the specified set"
    echo "  add <set_name> <ip_address>   Add IP address to the specified set"
    echo "  del <set_name> <ip_address>   Delete IP address from the specified set"
    exit 1
}

# 检查参数
if [ "$#" -eq 1 ] && [ "$1" == "-L" ]; then
    nft list sets || { echo "Error listing sets"; exit 1; }
    exit 0
elif [ "$#" -eq 2 ] && [ "$1" == "-L" ]; then
    nft list set inet fw4 "$2" | awk '/elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//'
    exit 0
elif [ "$#" -lt 2 ]; then
    usage
fi

ACTION=$1
SET_NAME=$2

# 执行命令
case "$ACTION" in
    list)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        # 显示指定集合的 IP 地址，每行一个
        nft list set inet fw4 "$SET_NAME" | awk '/elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//'
        ;;
    add)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_ADDRESS=$3
        nft add element inet fw4 "$SET_NAME" { "$IP_ADDRESS" } || { echo "Error adding IP address"; exit 1; }
        ;;
    del)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_ADDRESS=$3
        nft delete element inet fw4 "$SET_NAME" { "$IP_ADDRESS" } || { echo "Error deleting IP address"; exit 1; }
        ;;
    *)
        usage
        ;;
esac
