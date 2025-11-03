#!/bin/bash

# Log Analyzer - Advanced Log File Analysis Tool
# Uses awk, sed, and grep for powerful text processing

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Common log paths
declare -A LOG_PATHS=(
    ["/var/log/syslog"]="System Log"
    ["/var/log/auth.log"]="Authentication Log"
    ["/var/log/kern.log"]="Kernel Log"
    ["/var/log/dmesg"]="Boot Messages"
    ["./logs/dashboard.log"]="Dashboard Log"
    ["./logs/process_manager.log"]="Process Manager Log"
)

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    LOG ANALYZER                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# List available log files
list_log_files() {
    display_header
    echo -e "${YELLOW}Available Log Files:${NC}"
    echo ""
    
    local index=1
    local -a available_logs=()
    
    for log_path in "${!LOG_PATHS[@]}"; do
        if [[ -f "$log_path" && -r "$log_path" ]]; then
            echo -e "  ${CYAN}[$index]${NC} ${LOG_PATHS[$log_path]} - $log_path"
            available_logs[$index]="$log_path"
            ((index++))
        fi
    done
    
    if [[ $index -eq 1 ]]; then
        echo -e "${RED}No accessible log files found${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    echo ""
    echo -e "  ${CYAN}[C]${NC} Custom log file path"
    echo -e "  ${CYAN}[0]${NC} Back to menu"
    echo ""
    read -p "Select log file: " choice
    
    if [[ "$choice" == "0" ]]; then
        return 1
    elif [[ "$choice" =~ ^[Cc]$ ]]; then
        read -p "Enter log file path: " custom_path
        if [[ -f "$custom_path" && -r "$custom_path" ]]; then
            echo "$custom_path"
            return 0
        else
            echo -e "${RED}File not found or not readable${NC}"
            sleep 2
            return 1
        fi
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ -n "${available_logs[$choice]:-}" ]]; then
        echo "${available_logs[$choice]}"
        return 0
    else
        echo -e "${RED}Invalid selection${NC}"
        sleep 1
        return 1
    fi
}

# View log file with tail
view_log_tail() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Last 50 lines of: ${WHITE}$log_file${NC}"
        echo ""
        tail -n 50 "$log_file" | nl -w 3 -s ': '
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Search in log file
search_log() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Search in: ${WHITE}$log_file${NC}"
        echo ""
        read -p "Enter search term or regex: " search_term
        
        if [[ -z "$search_term" ]]; then
            echo -e "${RED}No search term provided${NC}"
            sleep 1
            return
        fi
        
        echo ""
        echo -e "${CYAN}Search results:${NC}"
        echo ""
        
        local count=$(grep -c "$search_term" "$log_file" 2>/dev/null || echo "0")
        echo -e "${GREEN}Found $count matches${NC}"
        echo ""
        
        if [[ $count -gt 0 ]]; then
            grep --color=always -n "$search_term" "$log_file" | head -n 50
            
            if [[ $count -gt 50 ]]; then
                echo ""
                echo -e "${BLUE}(Showing first 50 of $count matches)${NC}"
            fi
        fi
        
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Analyze error patterns
analyze_errors() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Error Analysis: ${WHITE}$log_file${NC}"
        echo ""
        
        # Count error levels
        echo -e "${CYAN}═══ Error Level Statistics ═══${NC}"
        echo ""
        
        local errors=$(grep -ci "error" "$log_file" 2>/dev/null || echo "0")
        local warnings=$(grep -ci "warning\|warn" "$log_file" 2>/dev/null || echo "0")
        local critical=$(grep -ci "critical\|crit\|fatal" "$log_file" 2>/dev/null || echo "0")
        
        printf "  ${RED}Critical/Fatal:${NC} %5d\n" "$critical"
        printf "  ${YELLOW}Errors:${NC}         %5d\n" "$errors"
        printf "  ${BLUE}Warnings:${NC}       %5d\n" "$warnings"
        echo ""
        
        # Most common errors
        echo -e "${CYAN}═══ Top 10 Error Messages ═══${NC}"
        echo ""
        grep -i "error" "$log_file" 2>/dev/null | \
            sed 's/^.*error[: ]*/ERROR: /I' | \
            awk '{$1=""; print $0}' | \
            sort | uniq -c | sort -rn | head -n 10 | \
            awk '{printf "  %3d × %s\n", $1, substr($0, index($0,$2))}'
        
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Time-based analysis
time_analysis() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Time-Based Analysis: ${WHITE}$log_file${NC}"
        echo ""
        
        # Extract and analyze timestamps
        echo -e "${CYAN}═══ Activity by Hour ═══${NC}"
        echo ""
        
        # Try to extract hours from common log formats
        awk '
        {
            # Try to match common timestamp formats
            if (match($0, /[0-9]{2}:[0-9]{2}:[0-9]{2}/)) {
                hour = substr($0, RSTART, 2)
                hours[hour]++
            }
        }
        END {
            for (h in hours) {
                printf "  Hour %s: %5d entries\n", h, hours[h]
            }
        }
        ' "$log_file" | sort
        
        echo ""
        
        # Recent activity (last hour patterns)
        echo -e "${CYAN}═══ Recent Activity Patterns ═══${NC}"
        echo ""
        
        local total_lines=$(wc -l < "$log_file")
        local recent_lines=$(tail -n 100 "$log_file" | wc -l)
        
        echo -e "  Total log entries: ${WHITE}$total_lines${NC}"
        echo -e "  Recent entries (last 100): ${WHITE}$recent_lines${NC}"
        
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# IP address analysis (for auth/access logs)
analyze_ips() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}IP Address Analysis: ${WHITE}$log_file${NC}"
        echo ""
        
        echo -e "${CYAN}═══ Top 15 IP Addresses ═══${NC}"
        echo ""
        
        # Extract IP addresses and count occurrences
        grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" "$log_file" 2>/dev/null | \
            sort | uniq -c | sort -rn | head -n 15 | \
            awk '{printf "  %5d × %s\n", $1, $2}'
        
        echo ""
        
        # Failed login attempts (if auth log)
        if [[ "$log_file" =~ auth ]]; then
            echo -e "${CYAN}═══ Failed Authentication Attempts ═══${NC}"
            echo ""
            
            grep -i "failed\|failure" "$log_file" 2>/dev/null | \
                grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | \
                sort | uniq -c | sort -rn | head -n 10 | \
                awk '{printf "  %5d × %s\n", $1, $2}'
            echo ""
        fi
        
        read -p "Press Enter to continue..."
    fi
}

# Generate statistics report
generate_stats() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Log Statistics: ${WHITE}$log_file${NC}"
        echo ""
        
        local total_lines=$(wc -l < "$log_file")
        local file_size=$(du -h "$log_file" | cut -f1)
        local oldest=$(head -n 1 "$log_file" | awk '{print $1, $2, $3}')
        local newest=$(tail -n 1 "$log_file" | awk '{print $1, $2, $3}')
        
        echo -e "${CYAN}═══ General Statistics ═══${NC}"
        printf "  Total Lines:     %'d\n" "$total_lines"
        printf "  File Size:       %s\n" "$file_size"
        printf "  Oldest Entry:    %s\n" "$oldest"
        printf "  Newest Entry:    %s\n" "$newest"
        echo ""
        
        echo -e "${CYAN}═══ Content Analysis ═══${NC}"
        local unique_lines=$(sort "$log_file" | uniq | wc -l)
        local blank_lines=$(grep -c "^$" "$log_file" 2>/dev/null || echo "0")
        
        printf "  Unique Lines:    %'d\n" "$unique_lines"
        printf "  Blank Lines:     %'d\n" "$blank_lines"
        echo ""
        
        echo -e "${CYAN}═══ Top 10 Most Common Lines ═══${NC}"
        echo ""
        awk '{count[$0]++} END {for (line in count) print count[line], line}' "$log_file" | \
            sort -rn | head -n 10 | awk '{$1=$1; printf "  %3d × %s\n", $1, substr($0, index($0,$2))}'
        
        echo ""
        
        # Export option
        read -p "Export statistics to file? (y/n): " export_choice
        if [[ "$export_choice" =~ ^[Yy]$ ]]; then
            local export_file="log_stats_$(basename "$log_file")_$(date +%Y%m%d_%H%M%S).txt"
            {
                echo "Log Statistics Report"
                echo "Generated: $(date)"
                echo "Log File: $log_file"
                echo ""
                echo "Total Lines: $total_lines"
                echo "File Size: $file_size"
                echo "Unique Lines: $unique_lines"
            } > "$export_file"
            echo -e "${GREEN}Statistics exported to: $export_file${NC}"
        fi
        
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Custom analysis with awk
custom_awk_analysis() {
    local log_file
    if log_file=$(list_log_files); then
        display_header
        echo -e "${YELLOW}Custom AWK Analysis: ${WHITE}$log_file${NC}"
        echo ""
        echo -e "${CYAN}Enter AWK pattern (or press Enter for examples):${NC}"
        read -p "> " awk_pattern
        
        if [[ -z "$awk_pattern" ]]; then
            echo ""
            echo -e "${BLUE}AWK Examples:${NC}"
            echo '  {print $1, $2}              - Print first two fields'
            echo '  /error/ {print}             - Print lines containing "error"'
            echo '  {count++} END {print count} - Count total lines'
            echo '  NF > 5 {print}              - Lines with more than 5 fields'
            echo ""
            read -p "Press Enter to continue..."
            return
        fi
        
        echo ""
        echo -e "${CYAN}Results:${NC}"
        echo ""
        
        if awk "$awk_pattern" "$log_file" 2>/dev/null | head -n 50; then
            echo ""
            echo -e "${GREEN}Analysis complete${NC}"
        else
            echo -e "${RED}AWK error - check your pattern${NC}"
        fi
        
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ LOG ANALYZER MENU ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} View Log Tail          - Last 50 lines"
    echo -e "  ${CYAN}[2]${NC} Search Log             - Search by keyword/regex"
    echo -e "  ${CYAN}[3]${NC} Analyze Errors         - Error pattern analysis"
    echo -e "  ${CYAN}[4]${NC} Time Analysis          - Activity by time"
    echo -e "  ${CYAN}[5]${NC} IP Analysis            - IP address statistics"
    echo -e "  ${CYAN}[6]${NC} Generate Statistics    - Comprehensive stats"
    echo -e "  ${CYAN}[7]${NC} Custom AWK Analysis    - Run custom AWK patterns"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-7]: " choice
    
    case $choice in
        1) view_log_tail ; show_menu ;;
        2) search_log ; show_menu ;;
        3) analyze_errors ; show_menu ;;
        4) time_analysis ; show_menu ;;
        5) analyze_ips ; show_menu ;;
        6) generate_stats ; show_menu ;;
        7) custom_awk_analysis ; show_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    show_menu
}

# Handle interrupt
trap 'echo -e "\n${YELLOW}Exiting Log Analyzer${NC}"; exit 0' INT TERM

main
