#!/bin/bash

# Alert System - Configure and manage system alerts
# Email notifications and alert thresholds

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly CONFIG_FILE="config/alerts.conf"
readonly LOG_FILE="logs/alerts.log"

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   ALERT SYSTEM                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# View current configuration
view_config() {
    display_header
    echo -e "${YELLOW}Current Alert Configuration${NC}"
    echo ""
    
    echo -e "${CYAN}═══ Alert Thresholds ═══${NC}"
    echo ""
    echo -e "  CPU Usage Threshold:     ${WHITE}80%${NC}"
    echo -e "  Memory Usage Threshold:  ${WHITE}85%${NC}"
    echo -e "  Disk Usage Threshold:    ${WHITE}90%${NC}"
    echo -e "  Load Average Threshold:  ${WHITE}4.0${NC}"
    echo ""
    
    echo -e "${CYAN}═══ Notification Settings ═══${NC}"
    echo ""
    echo -e "  Email Notifications:     ${YELLOW}Not Configured${NC}"
    echo -e "  Log File Alerts:         ${GREEN}Enabled${NC}"
    echo -e "  Alert Frequency:         ${WHITE}Every 5 minutes${NC}"
    echo ""
    
    read -p "Press Enter to continue..."
}

# Configure thresholds
configure_thresholds() {
    display_header
    echo -e "${YELLOW}Configure Alert Thresholds${NC}"
    echo ""
    
    echo -e "${CYAN}Current Thresholds:${NC}"
    echo "  1. CPU Usage: 80%"
    echo "  2. Memory Usage: 85%"
    echo "  3. Disk Usage: 90%"
    echo "  4. Load Average: 4.0"
    echo ""
    
    read -p "Enter threshold number to modify [1-4] or 0 to cancel: " choice
    
    case $choice in
        1) read -p "Enter new CPU threshold (0-100): " value ;;
        2) read -p "Enter new Memory threshold (0-100): " value ;;
        3) read -p "Enter new Disk threshold (0-100): " value ;;
        4) read -p "Enter new Load Average threshold: " value ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; return ;;
    esac
    
    echo -e "${GREEN}✓ Threshold updated (simulation)${NC}"
    sleep 2
}

# Test alerts
test_alerts() {
    display_header
    echo -e "${YELLOW}Test Alert System${NC}"
    echo ""
    
    echo -e "${CYAN}Checking system metrics...${NC}"
    echo ""
    
    # Simulate checks
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | awk 'NR==2 {printf "%.1f", $3/$2*100}')
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    echo -e "  CPU Usage:    ${WHITE}${cpu_usage}%${NC}"
    [[ ${cpu_usage%.*} -gt 80 ]] && echo -e "    ${RED}⚠ Would trigger alert!${NC}"
    
    echo -e "  Memory Usage: ${WHITE}${mem_usage}%${NC}"
    [[ ${mem_usage%.*} -gt 85 ]] && echo -e "    ${RED}⚠ Would trigger alert!${NC}"
    
    echo -e "  Disk Usage:   ${WHITE}${disk_usage}%${NC}"
    [[ $disk_usage -gt 90 ]] && echo -e "    ${RED}⚠ Would trigger alert!${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Alert test complete${NC}"
    echo ""
    
    read -p "Press Enter to continue..."
}

# View alert history
view_history() {
    display_header
    echo -e "${YELLOW}Alert History${NC}"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${CYAN}Recent alerts:${NC}"
        echo ""
        tail -n 20 "$LOG_FILE" || echo "No alerts logged"
    else
        echo "No alert history available"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ ALERT SYSTEM MENU ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} View Configuration     - Current settings"
    echo -e "  ${CYAN}[2]${NC} Configure Thresholds   - Set alert limits"
    echo -e "  ${CYAN}[3]${NC} Test Alerts            - Run alert check"
    echo -e "  ${CYAN}[4]${NC} View Alert History     - Past alerts"
    echo -e "  ${CYAN}[5]${NC} Configure Email        - Email notifications"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-5]: " choice
    
    case $choice in
        1) view_config ; show_menu ;;
        2) configure_thresholds ; show_menu ;;
        3) test_alerts ; show_menu ;;
        4) view_history ; show_menu ;;
        5) echo -e "\n${YELLOW}Email configuration coming soon...${NC}" ; sleep 2 ; show_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$CONFIG_FILE")"
    show_menu
}

trap 'echo -e "\n${YELLOW}Exiting Alert System${NC}"; exit 0' INT TERM

main
