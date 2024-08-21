#!/bin/bash

# 脚本用法
usage() {
    echo "Usage: $0 {-L|list|add|del|add|adds|del|dels|-N|-D|-F|-H|--help} [<set_name>] [<ip_address_or_file_path>]"
    echo "  -L                            List all IP sets"
    echo "  -L <set_name>                 List IPs in the specified set, with additional info"
    echo "  add <set_name> <ip_address>   Add IP address to the specified set"
    echo "  del <set_name> <ip_address>   Delete IP address from the specified set"
    echo "  adds <set_name> <file_path>   Batch add IPs from the specified file to the set"
    echo "  dels <set_name> <file_path>   Batch delete IPs from the specified file from the set"
    echo "  -N <set_name> <type>          Create a new set with the specified name and type"
    echo "  -D <set_name>                 Delete the specified set"
    echo "  -F <set_name>                 Flush all entries in the specified set"
    echo "  -H, --help                    Display this help message with supported set types"
    exit 1
}

# 支持的 set 类型，简化版
supported_set_types() {
    echo "Supported set types:"
    echo "  hash:ip, hash:net, list:set, hash:mac, bitmap:ip"
    echo "  For full support, please refer to nftables documentation."
    exit 1
}

# 检查参数
if [ "$#" -eq 1 ] && [ "$1" == "-L" ]; then
    nft list sets || { echo "Error listing sets"; exit 1; }
    exit 0
elif [ "$#" -eq 2 ] && [ "$1" == "-L" ]; then
    nft list set inet fw4 "$2" | awk '/set /{print; next} /elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//'
    echo "Number of entries: $(nft list set inet fw4 "$2" | grep -oP '(?<=elements = \{).*(?=})' | tr ',' '\n' | wc -l)"
    exit 0
elif [ "$#" -eq 1 ] && [[ "$1" == "-H" || "$1" == "--help" ]]; then
    usage
    supported_set_types
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
        nft list set inet fw4 "$SET_NAME" | awk '/set /{print; next} /elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//'
        echo "Number of entries: $(nft list set inet fw4 "$SET_NAME" | grep -oP '(?<=elements = \{).*(?=})' | tr ',' '\n' | wc -l)"
        ;;
    add)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_ADDRESS=$3
        if nft add element inet fw4 "$SET_NAME" { "$IP_ADDRESS" } 2>/dev/null; then
            echo "Added $IP_ADDRESS to $SET_NAME."
        else
            echo "Error adding IP address: $IP_ADDRESS may already exist in $SET_NAME."
        fi
        ;;
    del)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_ADDRESS=$3
        if nft delete element inet fw4 "$SET_NAME" { "$IP_ADDRESS" }; then
            echo "Deleted $IP_ADDRESS from $SET_NAME."
        else
            echo "Error deleting IP address: $IP_ADDRESS may not exist in $SET_NAME."
        fi
        ;;
    adds)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        FILE_PATH=$3
        if [[ ! "$FILE_PATH" == *"/"* ]]; then
            FILE_PATH="/etc/storage/$FILE_PATH"
        fi
        while IFS= read -r line; do
            line=$(echo "$line" | xargs)
            nft add element inet fw4 "$SET_NAME" { "$line" } || echo "Error adding $line to $SET_NAME."
        done < "$FILE_PATH"
        ;;
    dels)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        FILE_PATH=$3
        if [[ ! "$FILE_PATH" == *"/"* ]]; then
            FILE_PATH="/etc/storage/$FILE_PATH"
        fi
        while IFS= read -r line; do
            line=$(echo "$line" | xargs)
            nft delete element inet fw4 "$SET_NAME" { "$line" } || echo "Error deleting $line from $SET_NAME."
        done < "$FILE_PATH"
        ;;
    -N)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        TYPE=$3
        nft add set inet fw4 "$SET_NAME" { type $TYPE \; }
        ;;
    -D)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        nft delete set inet fw4 "$SET_NAME" || echo "Error deleting set $SET_NAME."
        ;;
    -F)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        nft flush set inet fw4 "$SET_NAME" || echo "Error flushing set $SET_NAME."
        ;;
    *)
        usage
        ;;
esac
