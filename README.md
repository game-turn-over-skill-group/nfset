# nfset
* ### nftables 防火墙 移植 iptables 中 ipset 使用习惯 而设计
<br>

```
【nfset】：
	-L <set_name>                            List IPs in the specified set, with additional info
	add <set_name> <ip_address>              Add IP address to the specified set
	del <set_name> <ip_address>              Delete IP address from the specified set
	adds <set_name> <file_path>              Batch add IPs from the specified file to the set
	dels <set_name> <file_path>              Batch delete IPs from the specified file from the set
	-N <set_name> <type> [<comment>] [<flags>] Create a new set with the specified name and type
	-D <set_name>                            Delete the specified set
	-F <set_name>                            Flush all entries in the specified set
	-H, --help                               Display this help message with supported set types

	-L <set_name> 列出指定集中的 IP，并提供附加信息
	add <set_name> <ip_address> Add IP 地址/网段 添加到指定集
	del <set_name> <ip_address> 从指定集中删除 IP 地址/网段
	adds <set_name> <file_path> 指定文件中的批量添加 IP 添加到集合中
	dels <set_name> <file_path> 从集合中 批量删除 指定文件中的 IP
	-N <set_name> <type> [<comment>] [<flags>] 使用指定的名称和类型创建一个新集
	-D <set_name> 删除指定的集合表单
	-F <set_name> 清空指定集合中的所有IP条目
	-H， --help 使用帮助支持 设置类型 显示此帮助消息
```

<br>

①. 使用 [Winscp] 上传脚本到你的脚本文件夹（例如：文件夹路径/脚本）
>     /etc/storage/nft_ipset.sh

②. 创建命令行快捷方式： 
```
ln -s /etc/storage/nft_ipset.sh /usr/bin/nfset
```

③. 添加可执行权限：
```
chmod +x /etc/storage/nft_ipset.sh
```


<br>

```
查看所有 IP 集合：
nfset -L

查看指定 IP 集合的内容：
nfset -L <set_name>
例子：
nfset -L hip6

添加 IP 地址到集合：
nfset add <set_name> <ip_address>
从集合中删除 IP 地址：
nfset del <set_name> <ip_address>

例子：
nfset add hip6 2001:b011:1234:5678::/64
nfset del hip6 2001:b011:1234:5678::/64
```

```
创建 IP 合集：
nfset -N cfnet ipv4
nfset -N cfnet ipv6

创建说明：
nfset -N 名称(name) 协议(ipv4/ipv6) 备注(Note) timeout(?d?h?m?s)
nfset -N cfnet ipv4 CF网段 timeout 7d
```

```
删除 IP合集
nfset -D cfnet

批量添加/删除（设置好默认路径 才能用文件名模式）
nfset adds cfnet /etc/storage/cfnet.txt
nfset dels cfnet /etc/storage/cfnet.txt
nfset adds cfnet cfnet.txt
nfset dels cfnet cfnet.txt

一键清空合集
nfset -F cfnet
```



<br>

##### 项目发起人：rer
##### 项目协作者：ChatGPT















