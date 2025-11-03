#!/bin/bash

# Backup Manager - File and Directory Backup System
# Create, manage, and restore backups

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly BACKUP_DIR="backups"
readonly CONFIG_FILE="config/backup.conf"
readonly LOG_FILE="logs/backup.log"

# Logging
log_backup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Display header
display_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  BACKUP MANAGER                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Create backup
create_backup() {
    display_header
    echo -e "${YELLOW}Create New Backup${NC}"
    echo ""
    
    read -p "Enter path to backup: " source_path
    
    if [[ ! -e "$source_path" ]]; then
        echo -e "${RED}Path does not exist: $source_path${NC}"
        sleep 2
        return
    fi
    
    local basename=$(basename "$source_path")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${basename}_${timestamp}"
    
    echo ""
    echo -e "Backup options:"
    echo -e "  ${CYAN}[1]${NC} Standard backup (.tar)"
    echo -e "  ${CYAN}[2]${NC} Compressed backup (.tar.gz)"
    echo -e "  ${CYAN}[3]${NC} Highly compressed (.tar.bz2)"
    echo ""
    read -p "Select compression [1-3]: " compress_choice
    
    case $compress_choice in
        1) 
            local extension=".tar"
            local tar_opts="-cf"
            ;;
        2) 
            local extension=".tar.gz"
            local tar_opts="-czf"
            ;;
        3) 
            local extension=".tar.bz2"
            local tar_opts="-cjf"
            ;;
        *) 
            local extension=".tar.gz"
            local tar_opts="-czf"
            ;;
    esac
    
    local backup_file="$BACKUP_DIR/${backup_name}${extension}"
    
    echo ""
    echo -e "${CYAN}Creating backup...${NC}"
    echo -e "Source: ${WHITE}$source_path${NC}"
    echo -e "Destination: ${WHITE}$backup_file${NC}"
    echo ""
    
    if tar $tar_opts "$backup_file" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>/dev/null; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "${GREEN}✓ Backup created successfully${NC}"
        echo -e "  Size: ${WHITE}$size${NC}"
        echo -e "  Location: ${WHITE}$backup_file${NC}"
        log_backup "Created backup: $backup_file"
    else
        echo -e "${RED}✗ Backup failed${NC}"
        log_backup "Backup failed: $source_path"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# List backups
list_backups() {
    display_header
    echo -e "${YELLOW}Available Backups${NC}"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo -e "${RED}No backups found${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${CYAN}Filename                                    Size      Date${NC}"
    echo "─────────────────────────────────────────────────────────────────────"
    
    ls -lh "$BACKUP_DIR" | grep -v "^total" | awk '{printf "%-43s %6s    %s %s %s\n", $9, $5, $6, $7, $8}'
    
    echo ""
    read -p "Press Enter to continue..."
}

# Restore backup
restore_backup() {
    display_header
    echo -e "${YELLOW}Restore Backup${NC}"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo -e "${RED}No backups found${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available backups:${NC}"
    echo ""
    local -a backups=()
    local index=1
    
    for backup in "$BACKUP_DIR"/*; do
        echo -e "  ${CYAN}[$index]${NC} $(basename "$backup")"
        backups[$index]="$backup"
        ((index++))
    done
    
    echo ""
    read -p "Select backup to restore [1-$((index-1))]: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ -z "${backups[$choice]:-}" ]]; then
        echo -e "${RED}Invalid selection${NC}"
        sleep 2
        return
    fi
    
    local backup_file="${backups[$choice]}"
    
    echo ""
    read -p "Enter destination path: " dest_path
    
    if [[ ! -d "$dest_path" ]]; then
        read -p "Directory doesn't exist. Create it? (y/n): " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$dest_path"
        else
            echo "Cancelled."
            sleep 1
            return
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}⚠ Warning: This will extract files to: $dest_path${NC}"
    read -p "Continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Cancelled."
        sleep 1
        return
    fi
    
    echo ""
    echo -e "${CYAN}Restoring backup...${NC}"
    
    if tar -xf "$backup_file" -C "$dest_path" 2>/dev/null; then
        echo -e "${GREEN}✓ Backup restored successfully${NC}"
        echo -e "  Location: ${WHITE}$dest_path${NC}"
        log_backup "Restored backup: $backup_file to $dest_path"
    else
        echo -e "${RED}✗ Restore failed${NC}"
        log_backup "Restore failed: $backup_file"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Delete backup
delete_backup() {
    display_header
    echo -e "${YELLOW}Delete Backup${NC}"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo -e "${RED}No backups found${NC}"
        sleep 2
        return
    fi
    
    echo -e "${CYAN}Available backups:${NC}"
    echo ""
    local -a backups=()
    local index=1
    
    for backup in "$BACKUP_DIR"/*; do
        local size=$(du -h "$backup" | cut -f1)
        echo -e "  ${CYAN}[$index]${NC} $(basename "$backup") (${size})"
        backups[$index]="$backup"
        ((index++))
    done
    
    echo ""
    read -p "Select backup to delete [1-$((index-1))]: " choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ -z "${backups[$choice]:-}" ]]; then
        echo -e "${RED}Invalid selection${NC}"
        sleep 2
        return
    fi
    
    local backup_file="${backups[$choice]}"
    
    echo ""
    echo -e "${RED}⚠ Warning: This will permanently delete: $(basename "$backup_file")${NC}"
    read -p "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        rm -f "$backup_file"
        echo -e "${GREEN}✓ Backup deleted${NC}"
        log_backup "Deleted backup: $backup_file"
    else
        echo "Cancelled."
    fi
    
    sleep 2
}

# Backup statistics
show_statistics() {
    display_header
    echo -e "${YELLOW}Backup Statistics${NC}"
    echo ""
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        echo -e "${RED}No backups found${NC}"
        echo ""
        read -p "Press Enter to continue..."
        return
    fi
    
    local count=$(ls -1 "$BACKUP_DIR" | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local oldest=$(ls -lt "$BACKUP_DIR" | tail -n 1 | awk '{print $6, $7, $8}')
    local newest=$(ls -lt "$BACKUP_DIR" | head -n 2 | tail -n 1 | awk '{print $6, $7, $8}')
    
    echo -e "${CYAN}═══ Backup Statistics ═══${NC}"
    echo ""
    printf "  Total Backups:   %d\n" "$count"
    printf "  Total Size:      %s\n" "$total_size"
    printf "  Oldest Backup:   %s\n" "$oldest"
    printf "  Newest Backup:   %s\n" "$newest"
    echo ""
    
    echo -e "${CYAN}═══ Backup by Type ═══${NC}"
    echo ""
    ls "$BACKUP_DIR" | awk -F. '{print $NF}' | sort | uniq -c | awk '{printf "  %s: %d backups\n", $2, $1}'
    
    echo ""
    read -p "Press Enter to continue..."
}

# Clean old backups
clean_old_backups() {
    display_header
    echo -e "${YELLOW}Clean Old Backups${NC}"
    echo ""
    
    read -p "Delete backups older than how many days? [default: 30]: " days
    days=${days:-30}
    
    if [[ ! "$days" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid number${NC}"
        sleep 2
        return
    fi
    
    local old_backups=$(find "$BACKUP_DIR" -name "*.tar*" -mtime +$days 2>/dev/null)
    local count=$(echo "$old_backups" | grep -c "." || echo "0")
    
    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}No backups older than $days days found${NC}"
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${CYAN}Found $count backup(s) older than $days days:${NC}"
    echo ""
    echo "$old_backups" | while read -r file; do
        echo "  - $(basename "$file")"
    done
    
    echo ""
    read -p "Delete these backups? (yes/no): " confirm
    
    if [[ "$confirm" == "yes" ]]; then
        find "$BACKUP_DIR" -name "*.tar*" -mtime +$days -delete 2>/dev/null
        echo -e "${GREEN}✓ Old backups deleted${NC}"
        log_backup "Cleaned backups older than $days days ($count files)"
    else
        echo "Cancelled."
    fi
    
    sleep 2
}

# Main menu
show_menu() {
    display_header
    echo -e "${YELLOW}═══════════════ BACKUP MANAGER MENU ═══════════════${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Create Backup          - Backup files/directories"
    echo -e "  ${CYAN}[2]${NC} List Backups           - View all backups"
    echo -e "  ${CYAN}[3]${NC} Restore Backup         - Restore from backup"
    echo -e "  ${CYAN}[4]${NC} Delete Backup          - Remove a backup"
    echo -e "  ${CYAN}[5]${NC} Backup Statistics      - View backup stats"
    echo -e "  ${CYAN}[6]${NC} Clean Old Backups      - Remove old backups"
    echo ""
    echo -e "  ${CYAN}[0]${NC} Back to Dashboard"
    echo ""
    echo -e "${YELLOW}══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Select option [0-6]: " choice
    
    case $choice in
        1) create_backup ; show_menu ;;
        2) list_backups ; show_menu ;;
        3) restore_backup ; show_menu ;;
        4) delete_backup ; show_menu ;;
        5) show_statistics ; show_menu ;;
        6) clean_old_backups ; show_menu ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ; sleep 1 ; show_menu ;;
    esac
}

# Main execution
main() {
    mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$CONFIG_FILE")"
    log_backup "Backup Manager started"
    show_menu
}

trap 'echo -e "\n${YELLOW}Exiting Backup Manager${NC}"; exit 0' INT TERM

main
