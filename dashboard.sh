#!/bin/bash

# System Monitoring & Admin Toolkit
# Main Dashboard - Interactive Menu System
# Author: System Admin
# Version: 1.0

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly REPORT_DIR="${SCRIPT_DIR}/reports"
readonly CONFIG_DIR="${SCRIPT_DIR}/config"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$CONFIG_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "${LOG_DIR}/dashboard.log"
}

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║        SYSTEM MONITORING & ADMIN TOOLKIT                   ║"
    echo "║                                                            ║"
    echo "║                    Version 1.0                             ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# Display system info header
show_system_info() {
    local hostname=$(hostname)
    local uptime=$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')
    local current_user=$(whoami)
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${WHITE}System: ${GREEN}$hostname${NC} | ${WHITE}User: ${GREEN}$current_user${NC} | ${WHITE}Uptime: ${GREEN}$uptime${NC}"
    echo -e "${WHITE}Time: ${GREEN}$current_time${NC}"
    echo ""
}

# Main menu
show_menu() {
    echo -e "${YELLOW}═══════════════════ MAIN MENU ═══════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} System Monitor         - Real-time resource monitoring"
    echo -e "  ${CYAN}[2]${NC} Process Manager        - Manage running processes"
    echo -e "  ${CYAN}[3]${NC} Log Analyzer           - Analyze system logs"
    echo -e "  ${CYAN}[4]${NC} Health Checker         - Check service health"
    echo -e "  ${CYAN}[5]${NC} Report Generator       - Generate system reports"
    echo -e "  ${CYAN}[6]${NC} Backup Manager         - Manage backups"
    echo -e "  ${CYAN}[7]${NC} Alert System           - Configure alerts"
    echo -e "  ${CYAN}[8]${NC} System Information     - Detailed system info"
    echo ""
    echo -e "  ${MAGENTA}[9]${NC} Settings               - Configure toolkit"
    echo -e "  ${RED}[0]${NC} Exit                   - Exit the toolkit"
    echo ""
    echo -e "${YELLOW}═════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if script exists and is executable
check_script() {
    local script="$1"
    if [[ ! -f "$script" ]]; then
        echo -e "${RED}Error: Script not found: $script${NC}"
        log "ERROR" "Script not found: $script"
        return 1
    fi
    if [[ ! -x "$script" ]]; then
        chmod +x "$script"
        log "INFO" "Made script executable: $script"
    fi
    return 0
}

# Execute script with error handling
execute_script() {
    local script="$1"
    local script_name=$(basename "$script")
    
    if check_script "$script"; then
        log "INFO" "Executing: $script_name"
        echo ""
        echo -e "${CYAN}Starting $script_name...${NC}"
        echo ""
        
        if "$script"; then
            log "INFO" "Successfully executed: $script_name"
        else
            local exit_code=$?
            echo -e "${RED}Error: $script_name exited with code $exit_code${NC}"
            log "ERROR" "$script_name exited with code $exit_code"
        fi
        
        echo ""
        read -p "Press Enter to continue..."
    else
        read -p "Press Enter to continue..."
    fi
}

# Settings menu
show_settings() {
    clear
    show_banner
    echo -e "${YELLOW}═══════════════════ SETTINGS ═══════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} View Configuration"
    echo -e "  ${CYAN}[2]${NC} Edit Alert Thresholds"
    echo -e "  ${CYAN}[3]${NC} Configure Email Notifications"
    echo -e "  ${CYAN}[4]${NC} View Logs"
    echo -e "  ${CYAN}[5]${NC} Clear Old Logs"
    echo -e "  ${RED}[0]${NC} Back to Main Menu"
    echo ""
    echo -e "${YELLOW}═════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option: " settings_choice
    
    case $settings_choice in
        1) view_configuration ;;
        2) echo "Feature coming soon..." ; read -p "Press Enter..." ;;
        3) echo "Feature coming soon..." ; read -p "Press Enter..." ;;
        4) view_logs ;;
        5) clear_old_logs ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}" ; read -p "Press Enter..." ;;
    esac
}

# View configuration
view_configuration() {
    clear
    echo -e "${CYAN}Current Configuration:${NC}"
    echo ""
    echo "Script Directory: $SCRIPT_DIR"
    echo "Log Directory: $LOG_DIR"
    echo "Report Directory: $REPORT_DIR"
    echo "Config Directory: $CONFIG_DIR"
    echo ""
    read -p "Press Enter to continue..."
}

# View logs
view_logs() {
    clear
    echo -e "${CYAN}Recent Log Entries:${NC}"
    echo ""
    if [[ -f "${LOG_DIR}/dashboard.log" ]]; then
        tail -n 20 "${LOG_DIR}/dashboard.log"
    else
        echo "No logs found."
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# Clear old logs
clear_old_logs() {
    echo ""
    read -p "Delete logs older than 7 days? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        find "$LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true
        echo -e "${GREEN}Old logs cleared.${NC}"
        log "INFO" "Old logs cleared by user"
    else
        echo "Cancelled."
    fi
    read -p "Press Enter to continue..."
}

# System information display
show_detailed_info() {
    clear
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           DETAILED SYSTEM INFORMATION              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Hostname:${NC} $(hostname)"
    echo -e "${YELLOW}Kernel:${NC} $(uname -r)"
    echo -e "${YELLOW}OS:${NC} $(uname -o)"
    echo -e "${YELLOW}Architecture:${NC} $(uname -m)"
    echo ""
    
    if command -v lsb_release &> /dev/null; then
        echo -e "${YELLOW}Distribution:${NC} $(lsb_release -d | cut -f2)"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    log "INFO" "Dashboard started"
    
    while true; do
        show_banner
        show_system_info
        show_menu
        
        read -p "Select option [0-9]: " choice
        
        case $choice in
            1) execute_script "${SCRIPT_DIR}/monitor.sh" ;;
            2) execute_script "${SCRIPT_DIR}/process_manager.sh" ;;
            3) execute_script "${SCRIPT_DIR}/log_analyzer.sh" ;;
            4) execute_script "${SCRIPT_DIR}/health_check.sh" ;;
            5) execute_script "${SCRIPT_DIR}/report_generator.sh" ;;
            6) execute_script "${SCRIPT_DIR}/backup_manager.sh" ;;
            7) execute_script "${SCRIPT_DIR}/alert_system.sh" ;;
            8) show_detailed_info ;;
            9) show_settings ;;
            0)
                echo ""
                echo -e "${GREEN}Thank you for using System Monitoring Toolkit!${NC}"
                log "INFO" "Dashboard exited normally"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 0-9.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Trap signals for cleanup
trap 'log "INFO" "Dashboard interrupted"; exit 130' INT TERM

# Run main function
main
