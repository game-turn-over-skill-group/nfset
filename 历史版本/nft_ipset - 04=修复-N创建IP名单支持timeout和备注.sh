#!/bin/bash

# 脚本用法
usage() {
    echo "Usage: $0 {-L|list|add|del|adds|dels|-N|-D|-F|-H|--help} [<set_name>] [<ip_address_or_file_path>]"
    echo "  -L <set_name>                            List IPs in the specified set, with additional info"
    echo "  add <set_name> <ip_address>              Add IP address to the specified set"
    echo "  del <set_name> <ip_address>              Delete IP address from the specified set"
    echo "  adds <set_name> <file_path>              Batch add IPs from the specified file to the set"
    echo "  dels <set_name> <file_path>              Batch delete IPs from the specified file from the set"
    echo "  -N <set_name> <type> [<comment>] [<flags>] Create a new set with the specified name and type"
    echo "  -D <set_name>                            Delete the specified set"
    echo "  -F <set_name>                            Flush all entries in the specified set"
    echo "  -H, --help                               Display this help message with supported set types"
    echo ""
    exit 1
}

# 支持的 set 类型，简化版
Nusage() {
    echo "Usage: $0 -N <set_name> <type> [<comment>] [<flags>]"
    echo "       <type> can be 'ipv4' or 'ipv6'."
    echo "       <comment> is optional and will be added as a comment."
    echo "       <flags> can include 'timeout', 'interval', etc."
    exit 1
}

# 检查参数
if [ "$#" -eq 1 ] && [ "$1" == "-L" ]; then
    nft list sets || { echo "Error listing sets"; exit 1; }
    exit 0
elif [ "$#" -eq 2 ] && [ "$1" == "-L" ]; then
    nft_output=$(nft list set inet fw4 "$2")
    echo "$nft_output" | awk '
        /type|flags|comment|auto-merge/ {
            gsub(/^[ \t]+/, "", $0)
            print
        }
    '
    ip_count=$(echo "$nft_output" | awk '/elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//' | wc -l)
    echo "Number of entries: $ip_count"
    echo "Members:"
    echo "$nft_output" | awk '/elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//' | sort -u
    exit 0
elif [ "$#" -eq 1 ] && [[ "$1" == "-H" || "$1" == "--help" ]]; then
    usage
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
        if [ "$#" -lt 3 ]; then
            Nusage
        fi
        SET_NAME=$2
        TYPE=$3
        COMMENT=""
        FLAGS=""
        # 检查是否有附加参数
        shift 3
        while [ "$#" -gt 0 ]; do
            case $1 in
                timeout)
                    FLAGS+="timeout $2; "
                    shift 2
                    ;;
                interval)
                    FLAGS+="interval; "
                    shift
                    ;;
                *)
                    COMMENT="$1"
                    shift
                    ;;
            esac
        done
        # 自动转换类型
        case $TYPE in
            ipv4)
                TYPE="ipv4_addr"
                ;;
            ipv6)
                TYPE="ipv6_addr"
                ;;
            *)
                Nusage
                ;;
        esac
        # 构建 nft 命令，自动包含 auto-merge
        CMD="nft add set inet fw4 $SET_NAME '{ type $TYPE; auto-merge; "
        if [ -n "$COMMENT" ]; then
            CMD+="comment \"$COMMENT\"; "
        fi
        CMD+="flags interval; $FLAGS }'"
        # 执行命令
        echo "Executing: $CMD"
        eval $CMD || Nusage
        ;;
    -D)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        SET_NAME=$2
        nft delete set inet fw4 "$SET_NAME" || echo "Error deleting set $SET_NAME."
        ;;
    -F)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        SET_NAME=$2
        nft flush set inet fw4 "$SET_NAME" || echo "Error flushing set $SET_NAME."
        ;;
    *)
        usage
        ;;
esac
