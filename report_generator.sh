#!/bin/bash

# Report Generator - System Reports in Multiple Formats
# Generate HTML and text reports

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly REPORT_DIR="reports"

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  REPORT GENERATOR                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Collect system information
collect_system_info() {
    declare -gA SYSTEM_INFO
    
    SYSTEM_INFO[hostname]=$(hostname)
    SYSTEM_INFO[kernel]=$(uname -r)
    SYSTEM_INFO[os]=$(uname -o)
    SYSTEM_INFO[arch]=$(uname -m)
    SYSTEM_INFO[uptime]=$(uptime -p 2>/dev/null || uptime | awk '{print $3,$4}')
    SYSTEM_INFO[cpu_model]=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    SYSTEM_INFO[cpu_count]=$(nproc)
    SYSTEM_INFO[total_mem]=$(free -h | awk 'NR==2 {print $2}')
    SYSTEM_INFO[timestamp]=$(date '+%Y-%m-%d %H:%M:%S')
}

# Get current metrics
get_current_metrics() {
    declare -gA METRICS
    
    METRICS[cpu_usage]=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    METRICS[mem_usage]=$(free | awk 'NR==2 {printf "%.1f", $3/$2*100}')
    METRICS[disk_usage]=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    METRICS[load_avg]=$(uptime | awk -F'load average:' '{print $2}')
    METRICS[process_count]=$(ps aux | wc -l)
}

# Generate text report
generate_text_report() {
    local filename="$REPORT_DIR/system_report_$(date +%Y%m%d_%H%M%S).txt"
    
    collect_system_info
    get_current_metrics
    
    cat > "$filename" << EOF
================================================================================
                         SYSTEM STATUS REPORT
================================================================================

Report Generated: ${SYSTEM_INFO[timestamp]}

--------------------------------------------------------------------------------
SYSTEM INFORMATION
--------------------------------------------------------------------------------
Hostname:          ${SYSTEM_INFO[hostname]}
Operating System:  ${SYSTEM_INFO[os]}
Kernel Version:    ${SYSTEM_INFO[kernel]}
Architecture:      ${SYSTEM_INFO[arch]}
Uptime:            ${SYSTEM_INFO[uptime]}

CPU Model:         ${SYSTEM_INFO[cpu_model]}
CPU Cores:         ${SYSTEM_INFO[cpu_count]}
Total Memory:      ${SYSTEM_INFO[total_mem]}

--------------------------------------------------------------------------------
CURRENT METRICS
--------------------------------------------------------------------------------
CPU Usage:         ${METRICS[cpu_usage]}%
Memory Usage:      ${METRICS[mem_usage]}%
Disk Usage (/):    ${METRICS[disk_usage]}%
Load Average:      ${METRICS[load_avg]}
Process Count:     ${METRICS[process_count]}

--------------------------------------------------------------------------------
DISK USAGE
--------------------------------------------------------------------------------
$(df -h | grep -E '^/dev/')

--------------------------------------------------------------------------------
TOP 10 CPU PROCESSES
--------------------------------------------------------------------------------
$(ps aux --sort=-%cpu | head -n 11 | tail -n 10 | awk '{printf "%-8s %-12s %5s%% %s\n", $2, $1, $3, $11}')

--------------------------------------------------------------------------------
TOP 10 MEMORY PROCESSES
--------------------------------------------------------------------------------
$(ps aux --sort=-%mem | head -n 11 | tail -n 10 | awk '{printf "%-8s %-12s %5s%% %s\n", $2, $1, $4, $11}')

--------------------------------------------------------------------------------
NETWORK CONNECTIONS
--------------------------------------------------------------------------------
$(ss -tuln 2>/dev/null | head -n 20 || netstat -tuln 2>/dev/null | head -n 20 || echo "Network info not available")

================================================================================
                            END OF REPORT
================================================================================
EOF
    
    echo "$filename"
}

# Generate HTML report
generate_html_report() {
    local filename="$REPORT_DIR/system_report_$(date +%Y%m%d_%H%M%S).html"
    
    collect_system_info
    get_current_metrics
    
    # Determine status colors
    local cpu_color="green"
    [[ ${METRICS[cpu_usage]%.*} -gt 70 ]] && cpu_color="orange"
    [[ ${METRICS[cpu_usage]%.*} -gt 85 ]] && cpu_color="red"
    
    local mem_color="green"
    [[ ${METRICS[mem_usage]%.*} -gt 70 ]] && mem_color="orange"
    [[ ${METRICS[mem_usage]%.*} -gt 85 ]] && mem_color="red"
    
    local disk_color="green"
    [[ ${METRICS[disk_usage]} -gt 70 ]] && disk_color="orange"
    [[ ${METRICS[disk_usage]} -gt 85 ]] && disk_color="red"
    
    cat > "$filename" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Status Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .content {
            padding: 30px;
        }
        .metric-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .metric-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .metric-card h3 {
            margin: 0 0 10px 0;
            color: #333;
            font-size: 0.9em;
            text-transform: uppercase;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            margin: 10px 0;
        }
        .status-green { color: #28a745; }
        .status-orange { color: #fd7e14; }
        .status-red { color: #dc3545; }
        .section {
            margin: 30px 0;
        }
        .section h2 {
            color: #667eea;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #dee2e6;
        }
        th {
            background-color: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 200px 1fr;
            gap: 10px;
            margin: 20px 0;
        }
        .info-label {
            font-weight: 600;
            color: #495057;
        }
        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #6c757d;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>System Status Report</h1>
            <p>REPORT_TIMESTAMP</p>
        </div>
        
        <div class="content">
            <div class="section">
                <h2>Current Metrics</h2>
                <div class="metric-grid">
                    <div class="metric-card">
                        <h3>CPU Usage</h3>
                        <div class="metric-value CPU_COLOR">CPU_USAGE%</div>
                    </div>
                    <div class="metric-card">
                        <h3>Memory Usage</h3>
                        <div class="metric-value MEM_COLOR">MEM_USAGE%</div>
                    </div>
                    <div class="metric-card">
                        <h3>Disk Usage</h3>
                        <div class="metric-value DISK_COLOR">DISK_USAGE%</div>
                    </div>
                    <div class="metric-card">
                        <h3>Process Count</h3>
                        <div class="metric-value status-green">PROCESS_COUNT</div>
                    </div>
                </div>
            </div>
            
            <div class="section">
                <h2>System Information</h2>
                <div class="info-grid">
                    <div class="info-label">Hostname:</div>
                    <div>HOSTNAME</div>
                    
                    <div class="info-label">Operating System:</div>
                    <div>OS_NAME</div>
                    
                    <div class="info-label">Kernel Version:</div>
                    <div>KERNEL_VERSION</div>
                    
                    <div class="info-label">Architecture:</div>
                    <div>ARCHITECTURE</div>
                    
                    <div class="info-label">Uptime:</div>
                    <div>UPTIME</div>
                    
                    <div class="info-label">CPU Model:</div>
                    <div>CPU_MODEL</div>
                    
                    <div class="info-label">CPU Cores:</div>
                    <div>CPU_COUNT</div>
                    
                    <div class="info-label">Total Memory:</div>
                    <div>TOTAL_MEM</div>
                    
                    <div class="info-label">Load Average:</div>
                    <div>LOAD_AVG</div>
                </div>
            </div>
            
            <div class="section">
                <h2>Top CPU Processes</h2>
                TOP_CPU_TABLE
            </div>
            
            <div class="section">
                <h2>Top Memory Processes</h2>
                TOP_MEM_TABLE
            </div>
        </div>
        
        <div class="footer">
            Generated by System Monitoring Toolkit
        </div>
    </div>
</body>
</html>
EOF
    
    # Generate process tables
    local cpu_table="<table><tr><th>PID</th><th>User</th><th>CPU%</th><th>Command</th></tr>"
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local user=$(echo "$line" | awk '{print $1}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local cmd=$(echo "$line" | awk '{print $11}')
        cpu_table+="<tr><td>$pid</td><td>$user</td><td>$cpu%</td><td>$cmd</td></tr>"
    done < <(ps aux --sort=-%cpu | head -n 11 | tail -n 10)
    cpu_table+="</table>"
    
    local mem_table="<table><tr><th>PID</th><th>User</th><th>MEM%</th><th>Command</th></tr>"
    while IFS= read -r line; do
        local pid=$(echo "$line" | awk '{print $2}')
        local user=$(echo "$line" | awk '{print $1}')
        local mem=$(echo "$line" | awk '{print $4}')
        local cmd=$(echo "$line" | awk '{print $11}')
        mem_table+="<tr><td>$pid</td><td>$user</td><td>$mem%</td><td>$cmd</td></tr>"
    done < <(ps aux --sort=-%mem | head -n 11 | tail -n 10)
    mem_table+="</table>"
    
    # Replace placeholders
    sed -i "s/REPORT_TIMESTAMP/${SYSTEM_INFO[timestamp]}/g" "$filename"
    sed -i "s/CPU_USAGE/${METRICS[cpu_usage]}/g" "$filename"
    sed -i "s/MEM_USAGE/${METRICS[mem_usage]}/g" "$filename"
    sed -i "s/DISK_USAGE/${METRICS[disk_usage]}/g" "$filename"
    sed -i "s/PROCESS_COUNT/${METRICS[process_count]}/g" "$filename"
    sed -i "s/CPU_COLOR/status-$cpu_color/g" "$filename"
    sed -i "s/MEM_COLOR/status-$mem_color/g" "$filename"
    sed -i "s/DISK_COLOR/status-$disk_color/g" "$filename"
    sed -i "s/HOSTNAME/${SYSTEM_INFO[hostname]}/g" "$filename"
    sed -i "s/OS_NAME/${SYSTEM_INFO[os]}/g" "$filename"
    sed -i "s/KERNEL_VERSION/${SYSTEM_INFO[kernel]}/g" "$filename"
    sed -i "s/ARCHITECTURE/${SYSTEM_INFO[arch]}/g" "$filename"
    sed -i "s/UPTIME/${SYSTEM_INFO[uptime]}/g" "$filename"
    sed -i "s/CPU_MODEL/${SYSTEM_INFO[cpu_model]}/g" "$filename"
    sed -i "s/CPU_COUNT/${SYSTEM_INFO[cpu_count]}/g" "$filename"
    sed -i "s/TOTAL_MEM/${SYSTEM_INFO[total_mem]}/g" "$filename"
    sed -i "s|LOAD_AVG|${METRICS[load_avg]}|g" "$filename"
    sed -i "s|TOP_CPU_TABLE|$cpu_table|g" "$filename"
    sed -i "s|TOP_MEM_TABLE|$mem_table|g" "$filename"
    
    echo "$filename"
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ REPORT GENERATOR ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Generate Text Report    - Plain text format"
    echo -e "  ${CYAN}[2]${NC} Generate HTML Report    - Web format"
    echo -e "  ${CYAN}[3]${NC} Generate Both Formats   - Text + HTML"
    echo -e "  ${CYAN}[4]${NC} View Recent Reports     - List generated reports"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-4]: " choice
    
    case $choice in
        1)
            echo ""
            echo -e "${CYAN}Generating text report...${NC}"
            local file=$(generate_text_report)
            echo -e "${GREEN}Report generated: $file${NC}"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        2)
            echo ""
            echo -e "${CYAN}Generating HTML report...${NC}"
            local file=$(generate_html_report)
            echo -e "${GREEN}Report generated: $file${NC}"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        3)
            echo ""
            echo -e "${CYAN}Generating reports...${NC}"
            local txt_file=$(generate_text_report)
            local html_file=$(generate_html_report)
            echo -e "${GREEN}Text report: $txt_file${NC}"
            echo -e "${GREEN}HTML report: $html_file${NC}"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        4)
            display_header
            echo -e "${YELLOW}Recent Reports:${NC}"
            echo ""
            ls -lht "$REPORT_DIR" 2>/dev/null || echo "No reports found"
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    mkdir -p "$REPORT_DIR"
    show_menu
}

trap 'echo -e "\n${YELLOW}Exiting Report Generator${NC}"; exit 0' INT TERM

main
