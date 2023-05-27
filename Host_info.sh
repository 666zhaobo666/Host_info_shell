#!/bin/bash

echo "-------------- 磁盘信息 ------------------------"
#获取磁盘空间
disk_free=$(df -h / | awk 'NR==2 {print $4}')
echo "剩余存储：${disk_free}"
# 判断根目录空间是否小于30G
if [ ${disk_free%G} -lt 30 ]; then
    echo "Warning: 剩余存储空间小于30G!!目前为${disk_free}"
fi
echo "-----------------------------------------------"
echo "  "
echo "-------------- 内存信息 -----------------------"
#获取内存情况
mem_free=$(free -m | awk 'NR==2 {print $4}')
echo "剩余内存：${mem_free}MB"
# 判断内存剩余是否小于300M
if [ ${mem_free} -lt 300 ]; then
    echo "Warning: 内存小于300MB!!目前为${mem_free}MB"
fi
# 获取内存占用进程信息并按照内存占用率排序，只取前5个进程
ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -n 6 | awk '{printf "%-6s %-8s %-6s %-6s %s\n", $1, $2, $3, $4, $5}'
echo "-----------------------------------------------"
echo "  "
echo "-------------- CPU信息 ------------------------"
#获取CPU情况
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
echo "CPU 总利用率: $cpu_usage%"
cpu_N=${cpu_usage/.*}
if [ $cpu_N -gt 90 ]; then
    echo "Warning: CPU占用率高于90%!!目前为${cpu}%"
fi
# 获取CPU占用进程信息并按照CPU占用率排序，取前5
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n 6 | awk '{printf "%-6s %-8s %-6s %-6s %s\n", $1, $2, $3, $4, $5}'
echo "-----------------------------------------------"
echo "  "
echo "-------------- 网络信息 -----------------------"
# 设置网络总带宽
echo -n "请输入您主机网络的总带宽(单位：Mbps)："
read read_bandwidth
total_bandwidth=$(echo "${read_bandwidth}*1024/8" | bc)
# 计算总占比
total_usage=$(iftop -t -s 1 -n -N -P | awk '/Total send rate:/ {print $4}')
total_usage_alpha=$(echo $total_usage | tr -cd "[a-zA-Z]")
total_usage_num=$(echo $total_usage | grep -oP '\d*\.\d+' | bc -l)
mb="Mb"
b="b"
echo "总带宽：${total_bandwidth}Kb/s"
echo "当前带宽：${total_usage}/s"
if [ "$total_usage_alpha" = "$mb" ]; then
	total_usage=$(echo "scale=2;${total_usage_num} * 1024 / ${total_bandwidth} * 100" | bc -l)
	echo "带宽占用: ${total_usage}%"
elif [ "$total_usage_alpha" = "$b" ]; then
		total_usage=$(echo "scale=2;${total_usage_num}/ 1024 /  ${total_bandwidth} * 100" | bc -l)
	echo "带宽占用: ${total_usage}%"
else
	total_usage=$(echo "scale=2;${total_usage_num} / ${total_bandwidth} * 100" | bc -l)
	echo "带宽占用: ${total_usage}%"
fi
total_usage_N=${total_usage/.*}
# 判断网络带宽占比是否大于90%
if [ $total_usage_N -gt 90 ]; then
    echo "Warning: 网络带宽占用率高于90%!!目前为${total_usage}%"
fi
################  显示网络信息进程  ##################
# 存储进程网络带宽信息的数组
declare -A bandwidths
# 获取当前时间戳
current_timestamp=$(date +%s)
# 遍历每个进程的网络统计信息
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
  # 检查是否存在相关的网络统计文件
  if [[ -f "/proc/$pid/net/dev" ]]; then
    # 提取进程的服务名
    service=$(ps -p $pid -o comm=)
    # 获取上一次记录的时间戳和字节数
    last_timestamp=$(cat "/proc/$pid/net/dev_timestamp" 2>/dev/null || echo 0)
    last_bytes=$(cat "/proc/$pid/net/dev" 2>/dev/null | awk 'NR==3 {print $2+$10}' || echo 0)
    # 计算时间间隔和字节数差值
    time_interval=$((current_timestamp - last_timestamp))
    byte_diff=$((last_bytes - last_byte_counts[$pid]))
    # 计算当前速率（以字节为单位）
    if [[ $time_interval -gt 0 ]]; then
      bandwidth=$((byte_diff / time_interval))   
      # 转换带宽单位为 KB/s
      bandwidth_kbps=$(awk "BEGIN {printf \"%.2f\", $bandwidth/1024}")    
      # 存储进程带宽信息到数组中
      bandwidths[$pid]="$pid $service $bandwidth_kbps KB/s"
    fi
    # 存储当前字节数
    last_byte_counts[$pid]=$last_bytes
  fi
done
# 排序并取前5个带宽最高的进程
sorted_bandwidths=$(printf "%s\n" "${bandwidths[@]}" | sort -k3 -rn | head -n 5)
# 输出表头
printf "%-10s %-20s %-10s\n" "PID" "Service" "Bandwidth"
printf "%-10s %-20s %-10s\n" "========" "====================" "=========="
# 输出前5个进程的带宽信息
while read -r line; do
  pid=$(echo "$line" | awk '{print $1}')
  service=$(echo "$line" | awk '{print $2}')
  bandwidth=$(echo "$line" | awk '{print $3}')
  printf "%-10s %-20s %-10s\n" "$pid" "$service" "$bandwidth"
done <<< "$sorted_bandwidths"
echo "----------------------------------------------"



