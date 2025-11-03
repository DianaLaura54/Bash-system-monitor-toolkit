#!/bin/bash

# Health Check - Service and System Health Monitoring
# Monitor services, ports, and system health

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Configuration file
readonly CONFIG_FILE="config/health_check.conf"
readonly LOG_FILE="logs/health_check.log"

# Default services to monitor
declare -a SERVICES_TO_MONITOR=(
    "sshd:SSH Server"
    "cron:Cron Daemon"
)

# Default ports to monitor
declare -a PORTS_TO_MONITOR=(
    "22:SSH"
    "80:HTTP"
)

# Logging function
log_check() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  HEALTH CHECK MONITOR                      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if service is running
check_service() {
    local service=$1
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        return 0
    elif pgrep -x "$service" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check port availability
check_port() {
    local port=$1
    local host=${2:-localhost}
    
    if command -v nc &> /dev/null; then
        nc -z -w2 "$host" "$port" 2>/dev/null
        return $?
    elif command -v timeout &> /dev/null; then
        timeout 2 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null
        return $?
    else
        return 2  # Unable to check
    fi
}

# Check disk space
check_disk_space() {
    local threshold=${1:-90}
    local issues=0
    
    echo -e "${CYAN}═══ Disk Space Check ═══${NC}"
    echo ""
    
    while IFS= read -r line; do
        local usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        local mount=$(echo "$line" | awk '{print $6}')
        local used=$(echo "$line" | awk '{print $3}')
        local available=$(echo "$line" | awk '{print $4}')
        
        if [[ $usage -ge $threshold ]]; then
            echo -e "  ${RED}✗ $mount: ${usage}% (${used} used, ${available} free)${NC}"
            ((issues++))
        elif [[ $usage -ge $((threshold - 10)) ]]; then
            echo -e "  ${YELLOW}⚠ $mount: ${usage}% (${used} used, ${available} free)${NC}"
        else
            echo -e "  ${GREEN}✓ $mount: ${usage}% (${used} used, ${available} free)${NC}"
        fi
    done < <(df -h | grep -E '^/dev/')
    
    echo ""
    return $issues
}

# Check memory usage
check_memory() {
    local threshold=${1:-85}
    
    echo -e "${CYAN}═══ Memory Check ═══${NC}"
    echo ""
    
    local total=$(free -m | awk 'NR==2 {print $2}')
    local used=$(free -m | awk 'NR==2 {print $3}')
    local free_mem=$(free -m | awk 'NR==2 {print $4}')
    local percent=$(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")
    
    if (( $(echo "$percent >= $threshold" | bc -l) )); then
        echo -e "  ${RED}✗ Memory: ${percent}% used (${used}MB/${total}MB)${NC}"
        return 1
    elif (( $(echo "$percent >= $((threshold - 10))" | bc -l) )); then
        echo -e "  ${YELLOW}⚠ Memory: ${percent}% used (${used}MB/${total}MB)${NC}"
        return 0
    else
        echo -e "  ${GREEN}✓ Memory: ${percent}% used (${used}MB/${total}MB)${NC}"
        return 0
    fi
    
    echo ""
}

# Check CPU load
check_cpu_load() {
    local threshold=${1:-80}
    
    echo -e "${CYAN}═══ CPU Load Check ═══${NC}"
    echo ""
    
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
    local cpu_count=$(nproc)
    local load_percent=$(awk "BEGIN {printf \"%.1f\", ($load_avg/$cpu_count)*100}")
    
    echo -e "  Load Average: ${WHITE}$load_avg${NC} (${cpu_count} CPUs)"
    
    if (( $(echo "$load_percent >= $threshold" | bc -l) )); then
        echo -e "  ${RED}✗ CPU Load: ${load_percent}% of capacity${NC}"
        return 1
    elif (( $(echo "$load_percent >= $((threshold - 20))" | bc -l) )); then
        echo -e "  ${YELLOW}⚠ CPU Load: ${load_percent}% of capacity${NC}"
        return 0
    else
        echo -e "  ${GREEN}✓ CPU Load: ${load_percent}% of capacity${NC}"
        return 0
    fi
    
    echo ""
}

# Check services
check_services() {
    display_header
    echo -e "${YELLOW}Service Health Check${NC}"
    echo ""
    
    local total=0
    local running=0
    
    echo -e "${CYAN}═══ Service Status ═══${NC}"
    echo ""
    
    for service_info in "${SERVICES_TO_MONITOR[@]}"; do
        IFS=':' read -r service description <<< "$service_info"
        ((total++))
        
        if check_service "$service"; then
            echo -e "  ${GREEN}✓ $description ($service) - Running${NC}"
            ((running++))
            log_check "Service OK: $service"
        else
            echo -e "  ${RED}✗ $description ($service) - Not Running${NC}"
            log_check "Service DOWN: $service"
        fi
    done
    
    echo ""
    echo -e "${WHITE}Services: ${GREEN}$running${NC}/${WHITE}$total running${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Check ports
check_ports() {
    display_header
    echo -e "${YELLOW}Port Availability Check${NC}"
    echo ""
    
    local total=0
    local open_ports=0
    
    echo -e "${CYAN}═══ Port Status ═══${NC}"
    echo ""
    
    for port_info in "${PORTS_TO_MONITOR[@]}"; do
        IFS=':' read -r port description <<< "$port_info"
        ((total++))
        
        if check_port "$port"; then
            echo -e "  ${GREEN}✓ Port $port ($description) - Open${NC}"
            ((open_ports++))
            log_check "Port OK: $port"
        else
            echo -e "  ${RED}✗ Port $port ($description) - Closed${NC}"
            log_check "Port CLOSED: $port"
        fi
    done
    
    echo ""
    echo -e "${WHITE}Ports: ${GREEN}$open_ports${NC}/${WHITE}$total open${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

# Full system health check
full_health_check() {
    display_header
    echo -e "${YELLOW}Complete System Health Check${NC}"
    echo ""
    echo -e "${WHITE}Starting comprehensive health check...${NC}"
    echo ""
    
    local issues=0
    
    # Disk space
    check_disk_space 90
    issues=$((issues + $?))
    
    # Memory
    check_memory 85
    issues=$((issues + $?))
    
    # CPU Load
    check_cpu_load 80
    issues=$((issues + $?))
    
    # Services
    echo -e "${CYAN}═══ Critical Services ═══${NC}"
    echo ""
    for service_info in "${SERVICES_TO_MONITOR[@]}"; do
        IFS=':' read -r service description <<< "$service_info"
        if check_service "$service"; then
            echo -e "  ${GREEN}✓ $description${NC}"
        else
            echo -e "  ${RED}✗ $description${NC}"
            ((issues++))
        fi
    done
    echo ""
    
    # Ports
    echo -e "${CYAN}═══ Network Ports ═══${NC}"
    echo ""
    for port_info in "${PORTS_TO_MONITOR[@]}"; do
        IFS=':' read -r port description <<< "$port_info"
        if check_port "$port"; then
            echo -e "  ${GREEN}✓ $description (Port $port)${NC}"
        else
            echo -e "  ${YELLOW}⚠ $description (Port $port)${NC}"
        fi
    done
    echo ""
    
    # Summary
    echo -e "${CYAN}═══ Health Check Summary ═══${NC}"
    echo ""
    if [[ $issues -eq 0 ]]; then
        echo -e "  ${GREEN}✓ System Status: HEALTHY${NC}"
        echo -e "  ${GREEN}No critical issues found${NC}"
        log_check "Health check PASSED - No issues"
    elif [[ $issues -le 2 ]]; then
        echo -e "  ${YELLOW}⚠ System Status: WARNING${NC}"
        echo -e "  ${YELLOW}$issues issue(s) found${NC}"
        log_check "Health check WARNING - $issues issues"
    else
        echo -e "  ${RED}✗ System Status: CRITICAL${NC}"
        echo -e "  ${RED}$issues issue(s) found${NC}"
        log_check "Health check CRITICAL - $issues issues"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Monitor continuously
continuous_monitor() {
    local interval=${1:-30}
    
    echo -e "${CYAN}Starting continuous monitoring (${interval}s interval)${NC}"
    echo -e "${CYAN}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}═══ Continuous Health Monitor ═══${NC}"
        echo -e "${WHITE}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        # Quick checks
        local cpu=$(get_cpu_usage 2>/dev/null || echo "N/A")
        local mem=$(free | awk 'NR==2 {printf "%.1f", $3/$2*100}')
        local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
        
        echo -e "CPU Usage:    ${WHITE}${cpu}%${NC}"
        echo -e "Memory Usage: ${WHITE}${mem}%${NC}"
        echo -e "Load Average: ${WHITE}${load}${NC}"
        echo ""
        
        echo -e "${CYAN}Services:${NC}"
        for service_info in "${SERVICES_TO_MONITOR[@]}"; do
            IFS=':' read -r service description <<< "$service_info"
            if check_service "$service"; then
                echo -e "  ${GREEN}✓${NC} $description"
            else
                echo -e "  ${RED}✗${NC} $description"
            fi
        done
        
        sleep $interval
    done
}

# Add custom service
add_service() {
    display_header
    echo -e "${YELLOW}Add Service to Monitor${NC}"
    echo ""
    read -p "Enter service name: " service_name
    read -p "Enter description: " description
    
    if [[ -n "$service_name" && -n "$description" ]]; then
        SERVICES_TO_MONITOR+=("$service_name:$description")
        echo -e "${GREEN}Service added: $description${NC}"
        log_check "Added service: $service_name"
    else
        echo -e "${RED}Invalid input${NC}"
    fi
    
    sleep 2
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ HEALTH CHECK MENU ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Full Health Check      - Complete system scan"
    echo -e "  ${CYAN}[2]${NC} Check Services         - Monitor services"
    echo -e "  ${CYAN}[3]${NC} Check Ports            - Check port availability"
    echo -e "  ${CYAN}[4]${NC} Check Disk Space       - Disk usage analysis"
    echo -e "  ${CYAN}[5]${NC} Check Memory           - Memory usage"
    echo -e "  ${CYAN}[6]${NC} Check CPU Load         - CPU load analysis"
    echo -e "  ${CYAN}[7]${NC} Continuous Monitor     - Real-time monitoring"
    echo -e "  ${CYAN}[8]${NC} Add Service            - Add service to monitor"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-8]: " choice
    
    case $choice in
        1) full_health_check ; show_menu ;;
        2) check_services ; show_menu ;;
        3) check_ports ; show_menu ;;
        4) display_header ; check_disk_space 90 ; echo "" ; read -p "Press Enter..." ; show_menu ;;
        5) display_header ; check_memory 85 ; echo "" ; read -p "Press Enter..." ; show_menu ;;
        6) display_header ; check_cpu_load 80 ; echo "" ; read -p "Press Enter..." ; show_menu ;;
        7) continuous_monitor 30 ;;
        8) add_service ; show_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Helper function for CPU usage (if needed)
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$CONFIG_FILE")"
    log_check "Health Check started"
    show_menu
}

# Handle interrupt
trap 'echo -e "\n${YELLOW}Exiting Health Check${NC}"; exit 0' INT TERM

main
