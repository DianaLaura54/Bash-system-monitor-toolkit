#!/bin/bash

# Process Manager - Advanced Process Management Tool
# Search, monitor, and control system processes

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Log file
readonly LOG_FILE="logs/process_manager.log"

# Logging function
log_action() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 PROCESS MANAGER                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# List all processes
list_all_processes() {
    display_header
    echo -e "${YELLOW}All Running Processes:${NC}"
    echo ""
    echo -e "${CYAN}PID      USER         %CPU  %MEM  COMMAND${NC}"
    ps aux | awk 'NR>1 {printf "%-8s %-12s %5s %5s %s\n", $2, $1, $3, $4, $11}' | head -n 30
    echo ""
    echo -e "${BLUE}Showing top 30 processes. Use search for specific processes.${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Search processes
search_processes() {
    display_header
    echo -e "${YELLOW}Search Processes${NC}"
    echo ""
    read -p "Enter process name or keyword: " search_term
    
    if [[ -z "$search_term" ]]; then
        echo -e "${RED}No search term provided${NC}"
        sleep 1
        return
    fi
    
    echo ""
    echo -e "${CYAN}Search results for: ${WHITE}$search_term${NC}"
    echo ""
    echo -e "${CYAN}PID      USER         %CPU  %MEM  COMMAND${NC}"
    
    local results=$(ps aux | grep -i "$search_term" | grep -v grep)
    
    if [[ -z "$results" ]]; then
        echo -e "${RED}No processes found matching '$search_term'${NC}"
    else
        echo "$results" | awk '{printf "%-8s %-12s %5s %5s %s\n", $2, $1, $3, $4, $11}'
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# View process details
view_process_details() {
    display_header
    echo -e "${YELLOW}Process Details${NC}"
    echo ""
    read -p "Enter PID: " pid
    
    if [[ -z "$pid" ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid PID${NC}"
        sleep 1
        return
    fi
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${RED}Process with PID $pid not found${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${CYAN}═══ Process Information ═══${NC}"
    ps -p "$pid" -o pid,ppid,user,%cpu,%mem,etime,cmd | tail -n +2
    
    echo ""
    echo -e "${CYAN}═══ Process Status ═══${NC}"
    if [[ -f "/proc/$pid/status" ]]; then
        cat "/proc/$pid/status" | grep -E "^(Name|State|Threads|VmSize|VmRSS):"
    fi
    
    echo ""
    echo -e "${CYAN}═══ Open Files ═══${NC}"
    lsof -p "$pid" 2>/dev/null | head -n 10 || echo "Unable to list open files (may require root)"
    
    echo ""
    read -p "Press Enter to continue..."
}

# Kill process
kill_process() {
    display_header
    echo -e "${YELLOW}Kill Process${NC}"
    echo ""
    echo -e "${RED}WARNING: This will terminate a process!${NC}"
    echo ""
    read -p "Enter PID to kill: " pid
    
    if [[ -z "$pid" ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid PID${NC}"
        sleep 1
        return
    fi
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${RED}Process with PID $pid not found${NC}"
        sleep 2
        return
    fi
    
    # Show process info before killing
    echo ""
    echo -e "${CYAN}Process to be killed:${NC}"
    ps -p "$pid" -o pid,user,cmd | tail -n +2
    echo ""
    
    read -p "Are you sure you want to kill this process? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        sleep 1
        return
    fi
    
    echo ""
    echo -e "Select signal:"
    echo -e "  ${CYAN}[1]${NC} SIGTERM (15) - Graceful termination (default)"
    echo -e "  ${CYAN}[2]${NC} SIGKILL (9)  - Force kill"
    echo -e "  ${CYAN}[3]${NC} SIGHUP (1)   - Hangup"
    echo ""
    read -p "Select signal [1-3]: " signal_choice
    
    case $signal_choice in
        1) signal="SIGTERM" ;;
        2) signal="SIGKILL" ;;
        3) signal="SIGHUP" ;;
        *) signal="SIGTERM" ;;
    esac
    
    if kill -s "$signal" "$pid" 2>/dev/null; then
        echo -e "${GREEN}Process $pid killed successfully with $signal${NC}"
        log_action "Killed process $pid with $signal"
    else
        echo -e "${RED}Failed to kill process $pid (may require root privileges)${NC}"
        log_action "Failed to kill process $pid"
    fi
    
    sleep 2
}

# Kill processes by name
kill_by_name() {
    display_header
    echo -e "${YELLOW}Kill Processes by Name${NC}"
    echo ""
    echo -e "${RED}WARNING: This will terminate all matching processes!${NC}"
    echo ""
    read -p "Enter process name: " process_name
    
    if [[ -z "$process_name" ]]; then
        echo -e "${RED}No process name provided${NC}"
        sleep 1
        return
    fi
    
    local pids=$(pgrep -f "$process_name")
    
    if [[ -z "$pids" ]]; then
        echo -e "${RED}No processes found matching '$process_name'${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${CYAN}Found processes:${NC}"
    ps -p $pids -o pid,user,cmd 2>/dev/null || echo "Error listing processes"
    echo ""
    
    local count=$(echo "$pids" | wc -w)
    read -p "Kill all $count process(es)? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        sleep 1
        return
    fi
    
    local killed=0
    for pid in $pids; do
        if kill "$pid" 2>/dev/null; then
            ((killed++))
        fi
    done
    
    echo -e "${GREEN}Successfully killed $killed out of $count processes${NC}"
    log_action "Killed $killed processes matching '$process_name'"
    sleep 2
}

# Show top processes
show_top_processes() {
    display_header
    echo -e "${YELLOW}Top Processes by Resource Usage${NC}"
    echo ""
    
    echo -e "${CYAN}═══ Top 10 CPU Consumers ═══${NC}"
    echo -e "${BLUE}PID      USER         %CPU  COMMAND${NC}"
    ps aux --sort=-%cpu | awk 'NR>1 && NR<=11 {printf "%-8s %-12s %5s  %s\n", $2, $1, $3, $11}'
    echo ""
    
    echo -e "${CYAN}═══ Top 10 Memory Consumers ═══${NC}"
    echo -e "${BLUE}PID      USER         %MEM  COMMAND${NC}"
    ps aux --sort=-%mem | awk 'NR>1 && NR<=11 {printf "%-8s %-12s %5s  %s\n", $2, $1, $4, $11}'
    echo ""
    
    read -p "Press Enter to continue..."
}

# Process tree
show_process_tree() {
    display_header
    echo -e "${YELLOW}Process Tree${NC}"
    echo ""
    read -p "Enter PID (or press Enter for full tree): " pid
    
    echo ""
    if [[ -z "$pid" ]]; then
        if command -v pstree &> /dev/null; then
            pstree -p | head -n 40
            echo ""
            echo -e "${BLUE}(Showing first 40 lines)${NC}"
        else
            ps axjf | head -n 40
            echo ""
            echo -e "${BLUE}(pstree not available, showing ps tree format)${NC}"
        fi
    else
        if command -v pstree &> /dev/null; then
            pstree -p "$pid"
        else
            ps --forest -o pid,cmd -g "$pid"
        fi
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Monitor specific process
monitor_process() {
    display_header
    echo -e "${YELLOW}Monitor Specific Process${NC}"
    echo ""
    read -p "Enter PID to monitor: " pid
    
    if [[ -z "$pid" ]] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid PID${NC}"
        sleep 1
        return
    fi
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${RED}Process with PID $pid not found${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${CYAN}Monitoring PID $pid (Press Ctrl+C to stop)${NC}"
    echo ""
    
    while ps -p "$pid" > /dev/null 2>&1; do
        clear
        echo -e "${CYAN}Monitoring PID: $pid${NC}"
        echo -e "${CYAN}Time: $(date '+%H:%M:%S')${NC}"
        echo ""
        ps -p "$pid" -o pid,ppid,user,%cpu,%mem,etime,cmd
        sleep 2
    done
    
    echo ""
    echo -e "${RED}Process $pid has terminated${NC}"
    sleep 2
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ PROCESS MANAGER MENU ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} List All Processes      - View all running processes"
    echo -e "  ${CYAN}[2]${NC} Search Processes        - Search by name/keyword"
    echo -e "  ${CYAN}[3]${NC} View Process Details    - Detailed info by PID"
    echo -e "  ${CYAN}[4]${NC} Top Processes           - Top CPU/Memory consumers"
    echo -e "  ${CYAN}[5]${NC} Process Tree            - View process hierarchy"
    echo -e "  ${CYAN}[6]${NC} Monitor Process         - Real-time monitor by PID"
    echo ""
    echo -e "  ${RED}[7]${NC} Kill Process by PID     - Terminate specific process"
    echo -e "  ${RED}[8]${NC} Kill Processes by Name  - Terminate all matching"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-8]: " choice
    
    case $choice in
        1) list_all_processes ; show_menu ;;
        2) search_processes ; show_menu ;;
        3) view_process_details ; show_menu ;;
        4) show_top_processes ; show_menu ;;
        5) show_process_tree ; show_menu ;;
        6) monitor_process ; show_menu ;;
        7) kill_process ; show_menu ;;
        8) kill_by_name ; show_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log_action "Process Manager started"
    show_menu
}

# Handle interrupt
trap 'echo -e "\n${YELLOW}Exiting Process Manager${NC}"; exit 0' INT TERM

main
