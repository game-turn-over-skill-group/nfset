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

# 设置默认文件路径
Default_Path="/etc/storage"

# 检查参数
if [ "$#" -eq 1 ] && [ "$1" == "-L" ]; then
    nft list sets || { echo "Error listing sets"; exit 1; }
    exit 0
elif [ "$#" -eq 2 ] && [ "$1" == "-L" ]; then
    # 检查集合是否存在
    if nft list set inet fw4 "$2" >/dev/null 2>&1; then
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
    else
        echo "Error: Set $2 does not exist."
        exit 1
    fi
    exit 0
elif [ "$#" -eq 1 ] && [[ "$1" == "-H" || "$1" == "--help" ]]; then
    usage
elif [ "$#" -lt 2 ]; then
    usage
fi

# Function to compress IPv6 addresses (压缩 IPv6 地址的函数)
compress_ipv6() {
    local ip=$1
    # echo "Original IP: $ip"  # 调试信息
    # 移除每块前导的零
    ip=$(echo "$ip" | sed -e 's/:0\{1,4\}/:/g')
    # 用 "::" 压缩最长的连续的零块
    ip=$(echo "$ip" | sed -e 's/\(:0\)\{2,\}/::/')
    # echo "Compressed IP: $ip"  # 调试信息，显示压缩后的IP
    echo "$ip"  # 返回压缩后的IP地址
}

ACTION=$1
SET_NAME=$2

# 执行命令
case "$ACTION" in
    list)
        if [ "$#" -ne 2 ]; then
            usage
        fi
        # 检查集合是否存在
        if nft list set inet fw4 "$SET_NAME" >/dev/null 2>&1; then
            nft list set inet fw4 "$SET_NAME" | awk '/set /{print; next} /elements = \{/,/}/ { if ($0 ~ /^[^ ]/) print }' | sed -e 's/^[^=]*= {//' -e 's/}.*$//' | sed -E 's/ (expires[^,]*),?/\n/g' | tr -d ' ' | tr ',' '\n' | sed '/^$/d' | sed 's/^[[:space:]]*//'
            echo "Number of entries: $(nft list set inet fw4 "$SET_NAME" | grep -oP '(?<=elements = \{).*(?=})' | tr ',' '\n' | wc -l)"
        else
            echo "Error: Set $SET_NAME does not exist."
        fi
        ;;
    add)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_ADDRESS=$3
        COMPRESSED_IP=$(compress_ipv6 "$IP_ADDRESS")
        # 检查集合是否存在
        if nft list set inet fw4 "$SET_NAME" >/dev/null 2>&1; then
            # 检查（压缩后的）IP 地址是否在集合中
            if nft list set inet fw4 "$SET_NAME" | grep -q "$COMPRESSED_IP"; then
                echo "Error: IP address $COMPRESSED_IP exist in $SET_NAME."
            else
                # 尝试添加 IP 地址/网段
                if nft add element inet fw4 "$SET_NAME" { "$IP_ADDRESS" } 2>/dev/null; then
                    # 如果希望在添加成功时显示提示信息，请取消以下行的注释
                    # echo "Added $IP_ADDRESS to $SET_NAME."
                    true
                else
                    # 如果添加失败并且错误是因为 IP 地址已存在，输出相应的错误信息
                    echo "Error adding IP address: $IP_ADDRESS may already exist in $SET_NAME."
                fi
            fi
        else
            echo "Error: Set $SET_NAME does not exist."
        fi
        ;;
    del)
		if [ "$#" -ne 3 ]; then
			usage
		fi
		IP_ADDRESS=$3
		COMPRESSED_IP=$(compress_ipv6 "$IP_ADDRESS")
		# echo "Attempting to delete: $COMPRESSED_IP from set $SET_NAME"  # 调试信息
		# 检查集合是否存在
		if nft list set inet fw4 "$SET_NAME" >/dev/null 2>&1; then
			# 检查(压缩后的)IP地址是否在集合中
			if nft list set inet fw4 "$SET_NAME" | grep -q "$COMPRESSED_IP"; then
				# 尝试删除 IP地址/网段
				if nft delete element inet fw4 "$SET_NAME" { "$IP_ADDRESS" } 2>/dev/null; then
					# echo "Deleted $IP_ADDRESS from $SET_NAME."  # 删除成功提示
					true
				else
					echo "Error deleting IP address: $COMPRESSED_IP may not exist in $SET_NAME."  # 删除失败提示
				fi
			else
				echo "Error: IP address $COMPRESSED_IP does not exist in $SET_NAME."  # IP地址不存在提示
			fi
		else
			echo "Error: Set $SET_NAME does not exist."  # 集合不存在提示
		fi
		;;
    adds)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_List=$3
        if [[ ! "$IP_List" == *"/"* ]]; then
            FILE_PATH="$Default_Path/$IP_List"
        fi
        # echo "Processing file: $FILE_PATH"
        while IFS= read -r line || [ -n "$line" ]; do
            # 去除前后空白字符
            line=$(echo "$line" | tr -d '[:space:]')
            if [ -n "$line" ]; then
                #if nft list set inet fw4 "$SET_NAME" | grep -q "$line" 2>/dev/null; then
                #	echo "$SET_NAME： Exist Repeat add $line "
                #else
                	# 显示即将执行的 nft 命令（调试）
                	# echo "nft add element inet fw4 \"$SET_NAME\" { \"$line\" }"
                	# 添加 IP 地址到集合中
                	nft add element inet fw4 "$SET_NAME" { "$line" }
                	# echo "Successfully added $line to $SET_NAME"
                #fi
            fi
        done < "$FILE_PATH"
        ;;
    dels)
        if [ "$#" -ne 3 ]; then
            usage
        fi
        IP_List=$3
        if [[ ! "$IP_List" == *"/"* ]]; then
            FILE_PATH="$Default_Path/$IP_List"
        fi
        # echo "Processing file: $FILE_PATH"
        while IFS= read -r line || [ -n "$line" ]; do
            # 去除前后空白字符
            line=$(echo "$line" | tr -d '[:space:]')
            if [ -n "$line" ]; then
            	if nft delete element inet fw4 "$SET_NAME" { "$line" } 2>/dev/null; then
                	# 显示即将执行的 nft 命令（调试）
                	# echo "nft delete element inet fw4 \"$SET_NAME\" { \"$line\" }"
                    # echo "Successfully deleted $line from $SET_NAME" # 删除成功
                    true
                else
                	echo "$SET_NAME : does not exist $line " # 删除失败
                fi
            fi
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
