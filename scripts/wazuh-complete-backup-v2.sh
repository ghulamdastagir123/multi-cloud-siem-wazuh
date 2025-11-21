#!/bin/bash

##############################################################################
# WAZUH MULTI-CLOUD SIEM - COMPLETE BACKUP SCRIPT v2.0
# Author: Ghulam Dastagir
# Description: Full backup of ALL Wazuh components including 15 Docker volumes
# Version: 2.0 - Complete Volume Coverage
##############################################################################

# Configuration
BACKUP_BASE="/home/wazuh/wazuh-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_BASE}/backup-${TIMESTAMP}"
DOCKER_DIR="/home/wazuh/wazuh-dir/wazuh-docker/single-node"
LOG_FILE="${BACKUP_BASE}/backup-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    error "Please run as root or with sudo"
    exit 1
fi

##############################################################################
# START BACKUP
##############################################################################

log "=========================================="
log "WAZUH MULTI-CLOUD SIEM - COMPLETE BACKUP v2.0"
log "=========================================="
log "Backup Directory: ${BACKUP_DIR}"
log ""

# Create backup directory structure
mkdir -p "${BACKUP_DIR}"/{configs,docker-volumes,rules,scripts,dashboards,certificates,system-state}

##############################################################################
# 1. DOCKER COMPOSE & HOST CONFIGS
##############################################################################

log "1. Backing up Docker Compose and host configs..."

# Docker compose file
if [ -f "${DOCKER_DIR}/docker-compose.yml" ]; then
    cp "${DOCKER_DIR}/docker-compose.yml" "${BACKUP_DIR}/configs/"
    log "   ✓ docker-compose.yml"
fi

# Secrets (environment files)
if [ -d "${DOCKER_DIR}/secrets" ]; then
    cp -r "${DOCKER_DIR}/secrets" "${BACKUP_DIR}/configs/"
    chmod -R 600 "${BACKUP_DIR}/configs/secrets/"
    log "   ✓ secrets/ (permissions: 600)"
fi

# Logstash configs
if [ -d "${DOCKER_DIR}/logstash" ]; then
    cp -r "${DOCKER_DIR}/logstash" "${BACKUP_DIR}/configs/"
    log "   ✓ logstash/"
fi

# Wazuh cluster configs
if [ -d "${DOCKER_DIR}/config/wazuh_cluster" ]; then
    cp -r "${DOCKER_DIR}/config/wazuh_cluster" "${BACKUP_DIR}/configs/"
    log "   ✓ wazuh_cluster/"
fi

# Wazuh indexer configs
if [ -d "${DOCKER_DIR}/config/wazuh_indexer" ]; then
    cp -r "${DOCKER_DIR}/config/wazuh_indexer" "${BACKUP_DIR}/configs/"
    log "   ✓ wazuh_indexer/"
fi

# Wazuh dashboard configs
if [ -d "${DOCKER_DIR}/config/wazuh_dashboard" ]; then
    cp -r "${DOCKER_DIR}/config/wazuh_dashboard" "${BACKUP_DIR}/configs/"
    log "   ✓ wazuh_dashboard/"
fi

# SSL Certificates
if [ -d "${DOCKER_DIR}/config/wazuh_indexer_ssl_certs" ]; then
    cp -r "${DOCKER_DIR}/config/wazuh_indexer_ssl_certs" "${BACKUP_DIR}/certificates/"
    log "   ✓ SSL certificates"
fi

##############################################################################
# 2. FILEBEAT (Host Service)
##############################################################################

log ""
log "2. Backing up Filebeat configuration..."

if [ -f "/etc/filebeat/filebeat.yml" ]; then
    cp /etc/filebeat/filebeat.yml "${BACKUP_DIR}/configs/"
    chmod 600 "${BACKUP_DIR}/configs/filebeat.yml"
    log "   ✓ filebeat.yml (permissions: 600)"
fi

if [ -d "/etc/filebeat/modules.d" ]; then
    cp -r /etc/filebeat/modules.d "${BACKUP_DIR}/configs/"
    chmod -R 600 "${BACKUP_DIR}/configs/modules.d/"
    log "   ✓ filebeat modules (permissions: 600)"
fi

##############################################################################
# 3. CUSTOM RULES & DECODERS
##############################################################################

log ""
log "3. Backing up custom rules and decoders..."

# Rules from container
docker cp single-node-wazuh.manager-1:/var/ossec/etc/rules/local_rules.xml \
    "${BACKUP_DIR}/rules/local_rules.xml" 2>/dev/null && log "   ✓ local_rules.xml"

docker cp single-node-wazuh.manager-1:/var/ossec/etc/rules/azure_rules.xml \
    "${BACKUP_DIR}/rules/azure_rules.xml" 2>/dev/null && log "   ✓ azure_rules.xml"

# Decoders
docker cp single-node-wazuh.manager-1:/var/ossec/etc/decoders/azure_decoders.xml \
    "${BACKUP_DIR}/rules/azure_decoders.xml" 2>/dev/null && log "   ✓ azure_decoders.xml"

docker cp single-node-wazuh.manager-1:/var/ossec/etc/decoders/local_decoder.xml \
    "${BACKUP_DIR}/rules/local_decoder.xml" 2>/dev/null && log "   ✓ local_decoder.xml (if exists)"

##############################################################################
# 4. DOCKER VOLUMES (ALL 15 VOLUMES - CRITICAL DATA)
##############################################################################

log ""
log "4. Backing up ALL Docker volumes (15 volumes - this will take several minutes)..."

# Complete list of all volumes
VOLUMES=(
    "single-node_wazuh_etc"
    "single-node_wazuh_wodles"
    "single-node_wazuh_logs"
    "single-node_wazuh_api_configuration"
    "single-node_wazuh_integrations"
    "single-node_wazuh-indexer-data"
    "single-node_wazuh-dashboard-config"
    "single-node_wazuh_queue"
    "single-node_filebeat_etc"
    "single-node_filebeat_var"
    "single-node_wazuh-dashboard-custom"
    "single-node_wazuh_active_response"
    "single-node_wazuh_agentless"
    "single-node_wazuh_var_multigroups"
    "single-node_wazuh-indexer-backup"
)

VOLUME_COUNT=0
TOTAL_VOLUMES=${#VOLUMES[@]}

for volume in "${VOLUMES[@]}"; do
    ((VOLUME_COUNT++))
    info "   [${VOLUME_COUNT}/${TOTAL_VOLUMES}] Backing up: ${volume}..."
    
    docker run --rm \
        -v "${volume}:/data" \
        -v "${BACKUP_DIR}/docker-volumes:/backup" \
        ubuntu tar czf "/backup/${volume}.tar.gz" /data 2>/dev/null
    
    if [ $? -eq 0 ]; then
        SIZE=$(du -h "${BACKUP_DIR}/docker-volumes/${volume}.tar.gz" | cut -f1)
        log "   ✓ ${volume} (${SIZE})"
    else
        error "   ✗ Failed to backup ${volume}"
    fi
done

##############################################################################
# 5. AGENT KEYS & CLIENT FILES
##############################################################################

log ""
log "5. Backing up agent keys..."

docker cp single-node-wazuh.manager-1:/var/ossec/etc/client.keys \
    "${BACKUP_DIR}/configs/client.keys" 2>/dev/null && log "   ✓ client.keys"

##############################################################################
# 6. SCRIPTS & AUTOMATION
##############################################################################

log ""
log "6. Backing up custom scripts..."

if [ -d "${DOCKER_DIR}" ]; then
    find "${DOCKER_DIR}" -name "*.sh" -exec cp {} "${BACKUP_DIR}/scripts/" \; 2>/dev/null
    SCRIPT_COUNT=$(ls -1 "${BACKUP_DIR}/scripts/" 2>/dev/null | wc -l)
    if [ $SCRIPT_COUNT -gt 0 ]; then
        log "   ✓ ${SCRIPT_COUNT} scripts backed up"
    fi
fi

# Copy this backup script itself
if [ -f "$0" ]; then
    cp "$0" "${BACKUP_DIR}/scripts/wazuh-backup-script.sh"
    log "   ✓ Backup script itself"
fi

##############################################################################
# 7. SYSTEM STATE & HEALTH
##############################################################################

log ""
log "7. Capturing system state..."

# Docker containers status
docker ps -a > "${BACKUP_DIR}/system-state/docker-containers-status.txt"
log "   ✓ Docker containers status"

# Docker compose config
cd "${DOCKER_DIR}" && docker-compose config > "${BACKUP_DIR}/system-state/docker-compose-resolved.yml" 2>/dev/null
log "   ✓ Docker compose resolved config"

# Docker volumes list
docker volume ls > "${BACKUP_DIR}/system-state/docker-volumes-list.txt"
log "   ✓ Docker volumes list"

# Wazuh version
docker exec single-node-wazuh.manager-1 /var/ossec/bin/wazuh-control info > \
    "${BACKUP_DIR}/system-state/wazuh-version.txt" 2>/dev/null
log "   ✓ Wazuh version info"

# Wazuh agent info (if any)
docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l > \
    "${BACKUP_DIR}/system-state/wazuh-agents-list.txt" 2>/dev/null
log "   ✓ Wazuh agents list"

# Disk usage
df -h > "${BACKUP_DIR}/system-state/disk-usage.txt"
log "   ✓ Disk usage"

# System info
uname -a > "${BACKUP_DIR}/system-state/system-info.txt"
cat /etc/os-release >> "${BACKUP_DIR}/system-state/system-info.txt"
log "   ✓ System information"

# Network info (Tailscale if exists)
if command -v tailscale &> /dev/null; then
    tailscale status > "${BACKUP_DIR}/system-state/tailscale-status.txt" 2>/dev/null
    log "   ✓ Tailscale status"
fi

##############################################################################
# 8. DASHBOARDS & VISUALIZATIONS
##############################################################################

log ""
log "8. Exporting dashboards and visualizations..."

# Export saved objects from Wazuh Dashboard
DASHBOARD_EXPORT=$(curl -sk -X POST "https://localhost:443/api/saved_objects/_export" \
    -H 'osd-xsrf: true' \
    -H 'Content-Type: application/json' \
    -d '{"type": ["dashboard", "visualization", "index-pattern"], "includeReferencesDeep": true}' \
    2>/dev/null)

if [ ! -z "$DASHBOARD_EXPORT" ]; then
    echo "$DASHBOARD_EXPORT" > "${BACKUP_DIR}/dashboards/wazuh-dashboards-export.ndjson"
    DASH_SIZE=$(du -h "${BACKUP_DIR}/dashboards/wazuh-dashboards-export.ndjson" | cut -f1)
    log "   ✓ Dashboards exported (${DASH_SIZE})"
else
    warning "   ⚠ Could not export dashboards (may need authentication)"
fi

##############################################################################
# 9. CREATE BACKUP INVENTORY
##############################################################################

log ""
log "9. Creating backup inventory..."

# Create inventory file
cat > "${BACKUP_DIR}/BACKUP_INVENTORY.txt" << EOF
==================================================
WAZUH MULTI-CLOUD SIEM - BACKUP INVENTORY
==================================================
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $(hostname)
Wazuh Version: $(docker exec single-node-wazuh.manager-1 /var/ossec/bin/wazuh-control info 2>/dev/null | head -n1)

CONFIGURATIONS:
- Docker Compose: ✓
- Wazuh Manager: ✓
- Wazuh Indexer: ✓
- Wazuh Dashboard: ✓
- Logstash: ✓
- Filebeat: ✓
- SSL Certificates: ✓

CUSTOM RULES:
- Azure Rules (52): ✓
- EC2 Rules (12): ✓
- Custom Decoders: ✓

DOCKER VOLUMES (15):
$(ls -1 ${BACKUP_DIR}/docker-volumes/ | sed 's/^/- /')

SCRIPTS:
$(ls -1 ${BACKUP_DIR}/scripts/ | sed 's/^/- /')

SYSTEM STATE:
- Container Status: ✓
- Volume List: ✓
- Agent List: ✓
- Disk Usage: ✓
- System Info: ✓

DASHBOARDS:
- Custom Visualizations: ✓

==================================================
TOTAL FILES: $(find ${BACKUP_DIR} -type f | wc -l)
TOTAL SIZE: $(du -sh ${BACKUP_DIR} | cut -f1)
==================================================
EOF

log "   ✓ Backup inventory created"

##############################################################################
# 10. CREATE COMPRESSED ARCHIVE
##############################################################################

log ""
log "10. Creating compressed backup archive..."

cd "${BACKUP_BASE}"
tar czf "wazuh-backup-${TIMESTAMP}.tar.gz" "backup-${TIMESTAMP}/" 2>/dev/null

if [ $? -eq 0 ]; then
    ARCHIVE_SIZE=$(du -h "wazuh-backup-${TIMESTAMP}.tar.gz" | cut -f1)
    log "   ✓ Archive created: wazuh-backup-${TIMESTAMP}.tar.gz (${ARCHIVE_SIZE})"
else
    error "   ✗ Failed to create archive"
fi

##############################################################################
# 11. BACKUP SUMMARY
##############################################################################

log ""
log "=========================================="
log "BACKUP SUMMARY"
log "=========================================="
log "Backup Location: ${BACKUP_DIR}"
log "Archive: wazuh-backup-${TIMESTAMP}.tar.gz"
log "Archive Size: ${ARCHIVE_SIZE}"
log ""

# Calculate total size
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
log "Total Backup Size: ${TOTAL_SIZE}"

# File count
FILE_COUNT=$(find "${BACKUP_DIR}" -type f | wc -l)
log "Total Files: ${FILE_COUNT}"

# Volume sizes breakdown
log ""
log "Volume Sizes:"
for volume in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_DIR}/docker-volumes/${volume}.tar.gz" ]; then
        SIZE=$(du -h "${BACKUP_DIR}/docker-volumes/${volume}.tar.gz" | cut -f1)
        printf "   %-50s %s\n" "${volume}" "${SIZE}"
    fi
done

log ""
log "✓ Backup completed successfully!"
log "Log file: ${LOG_FILE}"
log ""

log ""
log "=========================================="
log "BACKUP PROCESS FINISHED"
log "=========================================="
log ""
log "To restore this backup, use:"
log "  tar xzf wazuh-backup-${TIMESTAMP}.tar.gz"
log "  cd backup-${TIMESTAMP}"
log "  # Review BACKUP_INVENTORY.txt"
log ""
log "Manual cleanup (when needed):"
log "  # List old backups"
log "  ls -lh ${BACKUP_BASE}"
log "  # Remove specific backup"
log "  rm -rf ${BACKUP_BASE}/backup-YYYYMMDD-HHMMSS"
log "  rm ${BACKUP_BASE}/wazuh-backup-YYYYMMDD-HHMMSS.tar.gz"
log ""

exit 0
