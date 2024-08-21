#!/bin/sh

# 目标集合名称和表
TABLE="inet"
CHAIN="fw4"
SET_NAME="hip"

# 导入文件路径
FILE_PATH="/etc/storage/hip.txt"

# 逐行读取文件内容并添加到集合中
while IFS= read -r line; do
    # 去除行首尾的空白字符
    line=$(echo "$line" | xargs) # xargs命令可能造成分割位置错乱的BUG
    # 输出调试信息
    echo "Running command: nft add element ${TABLE} ${CHAIN} ${SET_NAME} { ${line} }"
    # 执行命令
    nft add element ${TABLE} ${CHAIN} ${SET_NAME} { ${line} }
done < "$FILE_PATH"
