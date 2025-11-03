#!/bin/bash

# System Monitor - Real-time Resource Monitoring
# Monitors CPU, Memory, Disk, and Network usage

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Thresholds (configurable)
readonly CPU_THRESHOLD=80
readonly MEMORY_THRESHOLD=85
readonly DISK_THRESHOLD=90

# Get CPU usage
get_cpu_usage() {
    local cpu_usage
    if command -v top &> /dev/null; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    else
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    fi
    printf "%.1f" "$cpu_usage"
}

# Get memory usage
get_memory_usage() {
    local total used percent
    if command -v free &> /dev/null; then
        read total used <<< $(free -m | awk 'NR==2 {print $2, $3}')
        percent=$(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")
    else
        # Fallback to /proc/meminfo
        total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        used=$((total - available))
        percent=$(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")
    fi
    echo "$percent|$used|$total"
}

# Get disk usage
get_disk_usage() {
    df -h / | awk 'NR==2 {print $5"|"$3"|"$2"|"$4}'
}

# Get system load
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//'
}

# Get number of processes
get_process_count() {
    ps aux | wc -l
}

# Get top processes by CPU
get_top_cpu_processes() {
    local count=${1:-5}
    ps aux --sort=-%cpu | awk 'NR>1 && NR<='$((count+1))' {printf "%-20s %5s%%  %s\n", substr($11,1,20), $3, $2}'
}

# Get top processes by memory
get_top_mem_processes() {
    local count=${1:-5}
    ps aux --sort=-%mem | awk 'NR>1 && NR<='$((count+1))' {printf "%-20s %5s%%  %s\n", substr($11,1,20), $4, $2}'
}

# Color code based on threshold
color_value() {
    local value=$1
    local threshold=$2
    local warning_threshold=$((threshold - 10))
    
    if (( $(echo "$value >= $threshold" | bc -l) )); then
        echo -e "${RED}${value}%${NC}"
    elif (( $(echo "$value >= $warning_threshold" | bc -l) )); then
        echo -e "${YELLOW}${value}%${NC}"
    else
        echo -e "${GREEN}${value}%${NC}"
    fi
}

# Draw progress bar
draw_bar() {
    local percent=$1
    local width=40
    local filled=$(printf "%.0f" $(echo "$percent * $width / 100" | bc -l))
    local empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "]"
}

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              SYSTEM RESOURCE MONITOR                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Hostname: ${GREEN}$(hostname)${NC} | ${WHITE}Time: ${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${WHITE}Uptime: ${GREEN}$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')${NC}"
    echo ""
}

# Main monitoring display
display_monitor() {
    # CPU Usage
    local cpu_usage=$(get_cpu_usage)
    echo -e "${YELLOW}═══ CPU Usage ═══${NC}"
    echo -ne "  CPU: $(color_value $cpu_usage $CPU_THRESHOLD) "
    draw_bar $cpu_usage
    echo ""
    echo ""
    
    # Memory Usage
    IFS='|' read -r mem_percent mem_used mem_total <<< "$(get_memory_usage)"
    echo -e "${YELLOW}═══ Memory Usage ═══${NC}"
    echo -ne "  RAM: $(color_value $mem_percent $MEMORY_THRESHOLD) "
    draw_bar $mem_percent
    echo ""
    echo -e "  Used: ${WHITE}${mem_used}MB${NC} / Total: ${WHITE}${mem_total}MB${NC}"
    echo ""
    
    # Disk Usage
    IFS='|' read -r disk_percent disk_used disk_total disk_available <<< "$(get_disk_usage)"
    disk_percent_num=${disk_percent%\%}
    echo -e "${YELLOW}═══ Disk Usage (/) ═══${NC}"
    echo -ne "  Disk: $(color_value $disk_percent_num $DISK_THRESHOLD) "
    draw_bar $disk_percent_num
    echo ""
    echo -e "  Used: ${WHITE}${disk_used}${NC} / Total: ${WHITE}${disk_total}${NC} / Available: ${WHITE}${disk_available}${NC}"
    echo ""
    
    # System Load
    echo -e "${YELLOW}═══ System Load ═══${NC}"
    echo -e "  Load Average: ${WHITE}$(get_load_average)${NC}"
    echo -e "  Processes: ${WHITE}$(get_process_count)${NC}"
    echo ""
    
    # Top CPU Processes
    echo -e "${YELLOW}═══ Top 5 CPU Processes ═══${NC}"
    echo -e "${CYAN}  Process              CPU%   PID${NC}"
    get_top_cpu_processes 5
    echo ""
    
    # Top Memory Processes
    echo -e "${YELLOW}═══ Top 5 Memory Processes ═══${NC}"
    echo -e "${CYAN}  Process              MEM%   PID${NC}"
    get_top_mem_processes 5
    echo ""
}

# Real-time monitoring mode
realtime_monitor() {
    local interval=${1:-2}
    
    while true; do
        display_header
        display_monitor
        
        echo -e "${CYAN}Refreshing every ${interval} seconds... (Press Ctrl+C to stop)${NC}"
        sleep $interval
    done
}

# Single snapshot mode
snapshot_mode() {
    display_header
    display_monitor
    
    echo ""
    read -p "Press Enter to return to dashboard..."
}

# Export to file
export_snapshot() {
    local output_file="monitor_snapshot_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "System Monitor Snapshot"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Hostname: $(hostname)"
        echo ""
        echo "CPU Usage: $(get_cpu_usage)%"
        echo "Memory Usage: $(get_memory_usage | cut -d'|' -f1)%"
        echo "Disk Usage: $(get_disk_usage | cut -d'|' -f1)"
        echo "Load Average: $(get_load_average)"
        echo ""
        echo "Top CPU Processes:"
        get_top_cpu_processes 10
        echo ""
        echo "Top Memory Processes:"
        get_top_mem_processes 10
    } > "$output_file"
    
    echo -e "${GREEN}Snapshot exported to: $output_file${NC}"
    read -p "Press Enter to continue..."
}

# Menu
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              SYSTEM MONITOR - OPTIONS                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} View Snapshot         - Single snapshot view"
    echo -e "  ${CYAN}[2]${NC} Real-time Monitor     - Continuous monitoring (2s refresh)"
    echo -e "  ${CYAN}[3]${NC} Real-time Monitor     - Continuous monitoring (5s refresh)"
    echo -e "  ${CYAN}[4]${NC} Export Snapshot       - Save snapshot to file"
    echo -e "  ${RED}[0]${NC} Back to Dashboard"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) snapshot_mode ;;
        2) realtime_monitor 2 ;;
        3) realtime_monitor 5 ;;
        4) export_snapshot ;;
        0) exit 0 ;;
        *) echo "Invalid option" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    # Check if running with sufficient permissions
    if [[ $EUID -ne 0 ]] && ! command -v ps &> /dev/null; then
        echo -e "${RED}Warning: Some features may require root privileges${NC}"
        sleep 2
    fi
    
    show_menu
}

# Handle interrupt
trap 'echo -e "\n${YELLOW}Monitoring stopped.${NC}"; exit 0' INT TERM

main
