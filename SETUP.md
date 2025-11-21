#  Installation & Setup Guide

Complete step-by-step guide to deploy the Multi-Cloud SIEM with Wazuh.



##  Table of Contents

1. [Prerequisites](#prerequisites)
2. [System Requirements](#system-requirements)
3. [Pre-Installation Steps](#pre-installation-steps)
4. [Core Installation](#core-installation)
5. [AWS Integration](#aws-integration)
6. [Azure Integration](#azure-integration)
7. [EC2 Agent Installation](#ec2-agent-installation)
8. [Post-Installation](#post-installation)
9. [Verification](#verification)
10. [Troubleshooting](#troubleshooting)



##  Prerequisites

### Required Accounts
- [ ] AWS Account with administrator access
- [ ] Azure Subscription (optional, for Azure integration)
- [ ] Linux server (Ubuntu 20.04/22.04/24.04 LTS)
- [ ] Domain/IP for Wazuh Manager (or use IP directly)

### Required Skills
- Basic Linux command line
- Understanding of Docker & Docker Compose
- Basic networking knowledge
- AWS/Azure console familiarity

### Tools Needed
```bash
# Install these before starting
- Docker 20.10+
- Docker Compose v2 (docker compose command)
- Git
- Text editor (nano/vim)
- curl/wget
```



## 💻 System Requirements

### Minimum Requirements
```yaml
OS: Ubuntu 20.04/22.04/24.04 LTS
CPU: 4 cores
RAM: 8 GB
Disk: 50 GB
Network: 100 Mbps
```

### Recommended Requirements
```yaml
OS: Ubuntu 24.04 LTS
CPU: 8 cores
RAM: 16 GB
Disk: 100 GB (SSD)
Network: 1 Gbps
```

### Port Requirements
```yaml
# Wazuh Manager
1514/tcp: Agent communication (data)
1515/tcp: Agent enrollment
514/tcp:  Syslog (remote logs)
55000/tcp: API

# Wazuh Dashboard
443/tcp:  Web UI (HTTPS)

# Wazuh Indexer
9200/tcp: API (internal)

# Logstash
5044/tcp: Beats input (Filebeat)
```

### Firewall Configuration
```bash
# Ubuntu UFW
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # Dashboard
sudo ufw allow 1514/tcp  # Agent data
sudo ufw allow 1515/tcp  # Agent enrollment
sudo ufw allow 514/tcp   # Remote syslog
sudo ufw allow 55000/tcp # API
sudo ufw enable

# CentOS/RHEL Firewalld
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=1514/tcp
sudo firewall-cmd --permanent --add-port=1515/tcp
sudo firewall-cmd --permanent --add-port=514/tcp
sudo firewall-cmd --permanent --add-port=55000/tcp
sudo firewall-cmd --reload
```



##  Pre-Installation Steps

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

### 2. Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker ps
```

### 3. Install Docker Compose v2
```bash
# Docker Compose v2 comes with Docker
# Verify it's installed
docker compose version

# Should show: Docker Compose version v2.x.x
```

### 4. Configure System Settings
```bash
# CRITICAL: Increase max_map_count for Elasticsearch/OpenSearch
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Increase file descriptors
sudo tee -a /etc/security/limits.conf << EOF
*    soft nofile 65536
*    hard nofile 65536
EOF

# Verify settings
sysctl vm.max_map_count
ulimit -n
```



##  Core Installation

### Step 1: Clone Repository
```bash
cd /home/$USER
git clone https://github.com/YOUR_USERNAME/multi-cloud-siem-wazuh.git
cd multi-cloud-siem-wazuh
```

### Step 2: Verify Repository Files
```bash
# Check required files exist
ls -la

# Required files/directories:
# docker-compose.yml            Main orchestration file
# generate-indexer-certs.yml    SSL certificate generation
# config/                       Configuration directory
# scripts/                      Helper scripts
# README.md                     Main documentation
```

**If any files are missing, check the repository!**

### Step 3: Create Environment Variables File

**This is where ALL your sensitive credentials will be stored!**

```bash
# Create .env file in project root
nano .env
```

**Add your credentials:**
```bash
# ============================================
# Wazuh Multi-Cloud SIEM - Environment Variables
# ============================================

# AWS Configuration
# -----------------
# Get these from AWS IAM Console > Users > wazuh-siem > Security credentials
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1

# AWS S3 Bucket Names
# ------------------
AWS_CLOUDTRAIL_BUCKET=aws-cloudtrail-logs-320708867398-37475846
AWS_GUARDDUTY_BUCKET=aws-guardduty-logs-320708867398
AWS_VPC_FLOW_BUCKET=aws-vpc-flow-logs-320708867398

# Azure Configuration
# -------------------
# Get this from Azure Portal > Event Hubs > Namespace > Shared access policies
AZURE_CONNECTION_STRING=Endpoint=sb://wazuh-event-hub-ns.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_KEY_HERE
AZURE_EVENTHUB_NAME=wazuh-activity-logs
AZURE_CONSUMER_GROUP=$Default

# Email Configuration (Optional)
# ------------------------------
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_FROM=wazuh-alerts@yourdomain.com
EMAIL_TO=security@yourdomain.com
EMAIL_USERNAME=your-email@gmail.com
EMAIL_PASSWORD=your-app-password

# Wazuh Configuration
# ------------------
WAZUH_MANAGER_IP=YOUR_SERVER_IP_HERE
INDEXER_PASSWORD=SecurePassword
API_PASSWORD=SecurePassword

# ============================================
# SECURITY NOTES:
# - NEVER commit this file to Git!
# - Keep backup in secure location
# - Rotate credentials regularly
# - Use IAM roles when possible
# ============================================
```

**Save and protect the file:**
```bash
# Set restrictive permissions (owner read/write only)
chmod 600 .env

# Verify it's in .gitignore
grep "^\.env$" .gitignore

# If not, add it
echo ".env" >> .gitignore
```

**CRITICAL SECURITY:**
- This file contains ALL sensitive credentials
- NEVER commit it to Git
- Keep encrypted backup in secure location
- Share only via secure channels (not email/Slack)

### Step 4: Configure Wazuh Manager with Environment Variables

**Edit the Wazuh manager config:**
```bash
nano config/wazuh_cluster/wazuh_manager.conf
```

**Find the `<wodle name="aws-s3">` section and update:**
```xml
<wodle name="aws-s3">
  <disabled>no</disabled>
  <interval>5m</interval>
  
  <!-- CloudTrail -->
  <bucket type="cloudtrail">
    <name>YOUR_CLOUDTRAIL_BUCKET</name>
    <access_key>YOUR_AWS_ACCESS_KEY</access_key>
    <secret_key>YOUR_AWS_SECRET_KEY</secret_key>
    <regions>us-east-1</regions>
  </bucket>
  
  <!-- GuardDuty -->
  <bucket type="guardduty">
    <name>YOUR_GUARDDUTY_BUCKET</name>
    <access_key>YOUR_AWS_ACCESS_KEY</access_key>
    <secret_key>YOUR_AWS_SECRET_KEY</secret_key>
    <regions>us-east-1</regions>
  </bucket>
  
  <!-- VPC Flow Logs -->
  <bucket type="vpcflow">
    <name>YOUR_VPC_FLOW_BUCKET</name>
    <access_key>YOUR_AWS_ACCESS_KEY</access_key>
    <secret_key>YOUR_AWS_SECRET_KEY</secret_key>
    <regions>us-east-1</regions>
  </bucket>
  
  <!-- Inspector v2 -->
  <service type="inspector">
    <access_key>YOUR_AWS_ACCESS_KEY</access_key>
    <secret_key>YOUR_AWS_SECRET_KEY</secret_key>
    <regions>us-east-1</regions>
  </service>
</wodle>
```

**Replace placeholders with your actual values from `.env` file:**
- `YOUR_CLOUDTRAIL_BUCKET` → Value from `AWS_CLOUDTRAIL_BUCKET`
- `YOUR_GUARDDUTY_BUCKET` → Value from `AWS_GUARDDUTY_BUCKET`
- `YOUR_VPC_FLOW_BUCKET` → Value from `AWS_VPC_FLOW_BUCKET`
- `YOUR_AWS_ACCESS_KEY` → Value from `AWS_ACCESS_KEY_ID`
- `YOUR_AWS_SECRET_KEY` → Value from `AWS_SECRET_ACCESS_KEY`

**Pro Tip:** You can create a helper script to auto-populate:
```bash
# Create update script
cat > scripts/update-aws-config.sh << 'EOF'
#!/bin/bash
source .env

sed -i "s|YOUR_CLOUDTRAIL_BUCKET|${AWS_CLOUDTRAIL_BUCKET}|g" config/wazuh_cluster/wazuh_manager.conf
sed -i "s|YOUR_GUARDDUTY_BUCKET|${AWS_GUARDDUTY_BUCKET}|g" config/wazuh_cluster/wazuh_manager.conf
sed -i "s|YOUR_VPC_FLOW_BUCKET|${AWS_VPC_FLOW_BUCKET}|g" config/wazuh_cluster/wazuh_manager.conf
sed -i "s|YOUR_AWS_ACCESS_KEY|${AWS_ACCESS_KEY_ID}|g" config/wazuh_cluster/wazuh_manager.conf
sed -i "s|YOUR_AWS_SECRET_KEY|${AWS_SECRET_ACCESS_KEY}|g" config/wazuh_cluster/wazuh_manager.conf

echo " AWS configuration updated!"
EOF

chmod +x scripts/update-aws-config.sh
./scripts/update-aws-config.sh
```

### Step 5: Generate SSL Certificates (MANDATORY!)

**This step MUST be done before starting containers!**

```bash
# Generate SSL certificates for Wazuh Indexer
docker compose -f generate-indexer-certs.yml run --rm generator

# This creates certificates in config/wazuh_indexer_ssl_certs/
# Verify certificates were created
ls -la config/wazuh_indexer_ssl_certs/

# Should see:
# - root-ca.pem
# - admin.pem
# - admin-key.pem
# - wazuh.indexer.pem
# - wazuh.indexer-key.pem
# - wazuh.manager.pem
# - wazuh.manager-key.pem
# - wazuh.dashboard.pem
# - wazuh.dashboard-key.pem
```

**CRITICAL: Without this step, containers will fail to start!**

### Step 6: Start Wazuh Stack
```bash
# Docker Compose automatically reads .env file!
# Start all containers in background
docker compose up -d

# Check container status
docker compose ps

# Expected output (all healthy):
# NAME                STATUS
# wazuh.manager       Up (healthy)
# wazuh.indexer       Up (healthy)
# wazuh.dashboard     Up (healthy)
# logstash            Up
```

### Step 7: Wait for Services to Initialize

**Wazuh Indexer (2-3 minutes):**
```bash
# Watch indexer logs
docker compose logs -f wazuh.indexer

# Wait for: "Node started"
# Press Ctrl+C when you see it
```

**Wazuh Manager (1-2 minutes):**
```bash
# Watch manager logs
docker compose logs -f wazuh.manager

# Wait for: "wazuh-modulesd:agent-upgrade: INFO: Module Agent Upgrade started"
# Press Ctrl+C when you see it
```

**Wazuh Dashboard (1 minute):**
```bash
# Watch dashboard logs
docker compose logs -f wazuh.dashboard

# Wait for: "Server running at"
# Press Ctrl+C when you see it
```

### Step 8: Initial Dashboard Access
```bash
# Access dashboard in browser
https://YOUR_SERVER_IP

# Default credentials:
Username: admin
Password: SecurePassword

#  CHANGE PASSWORD IMMEDIATELY after first login!
```

**If you can't access:**
- Check firewall: `sudo ufw status`
- Check containers: `docker compose ps`
- Check logs: `docker compose logs wazuh.dashboard`



##  AWS Integration

### Step 1: Create IAM User & Policy

**Your `.env` file already has AWS credentials section ready!**

**Create IAM Policy File:**
```bash
cat > aws-wazuh-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::aws-cloudtrail-logs-*",
        "arn:aws:s3:::aws-cloudtrail-logs-*/*",
        "arn:aws:s3:::aws-guardduty-logs-*",
        "arn:aws:s3:::aws-guardduty-logs-*/*",
        "arn:aws:s3:::aws-vpc-flow-logs-*",
        "arn:aws:s3:::aws-vpc-flow-logs-*/*"
      ]
    },
    {
      "Sid": "GuardDutyAccess",
      "Effect": "Allow",
      "Action": [
        "guardduty:GetFindings",
        "guardduty:ListFindings",
        "guardduty:ListDetectors"
      ],
      "Resource": "*"
    },
    {
      "Sid": "InspectorAccess",
      "Effect": "Allow",
      "Action": [
        "inspector2:ListFindings"
      ],
      "Resource": "*"
    }
  ]
}
EOF
```

**Create in AWS:**
```bash
# Create policy
aws iam create-policy \
  --policy-name WazuhSIEMAccess \
  --policy-document file://aws-wazuh-policy.json

# Create user
aws iam create-user --user-name wazuh-siem

# Attach policy (replace YOUR_ACCOUNT_ID)
aws iam attach-user-policy \
  --user-name wazuh-siem \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/WazuhSIEMAccess

# Create access keys
aws iam create-access-key --user-name wazuh-siem

#  COPY OUTPUT TO .env FILE!
# Update these lines in .env:
# AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
# AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### Step 2: Enable AWS Services

**CloudTrail:**
```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket
CLOUDTRAIL_BUCKET="aws-cloudtrail-logs-${ACCOUNT_ID}-37475846"
aws s3 mb s3://$CLOUDTRAIL_BUCKET

# Apply bucket policy
cat > cloudtrail-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${CLOUDTRAIL_BUCKET}"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${CLOUDTRAIL_BUCKET}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket $CLOUDTRAIL_BUCKET \
  --policy file://cloudtrail-bucket-policy.json

# Create trail
aws cloudtrail create-trail \
  --name wazuh-security-trail \
  --s3-bucket-name $CLOUDTRAIL_BUCKET

# Start logging
aws cloudtrail start-logging --name wazuh-security-trail

#  UPDATE .env FILE:
# AWS_CLOUDTRAIL_BUCKET=aws-cloudtrail-logs-XXXXXX-37475846
```

**GuardDuty:**
```bash
# Enable GuardDuty
DETECTOR_ID=$(aws guardduty create-detector \
  --enable \
  --finding-publishing-frequency FIFTEEN_MINUTES \
  --query 'DetectorId' \
  --output text)

echo "GuardDuty Detector ID: $DETECTOR_ID"

# Create GuardDuty export bucket
GUARDDUTY_BUCKET="aws-guardduty-logs-${ACCOUNT_ID}"
aws s3 mb s3://$GUARDDUTY_BUCKET

# Configure findings export to S3
aws guardduty create-publishing-destination \
  --detector-id $DETECTOR_ID \
  --destination-type S3 \
  --destination-properties DestinationArn=arn:aws:s3:::$GUARDDUTY_BUCKET,KmsKeyArn=""

#  UPDATE .env FILE:
# AWS_GUARDDUTY_BUCKET=aws-guardduty-logs-XXXXXX
```

**VPC Flow Logs:**
```bash
# Get your VPC ID
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)

# Create flow logs bucket
VPC_FLOW_BUCKET="aws-vpc-flow-logs-${ACCOUNT_ID}"
aws s3 mb s3://$VPC_FLOW_BUCKET

# Enable flow logs
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids $VPC_ID \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination arn:aws:s3:::$VPC_FLOW_BUCKET

#  UPDATE .env FILE:
# AWS_VPC_FLOW_BUCKET=aws-vpc-flow-logs-XXXXXX
```

**Inspector:**
```bash
# Enable Inspector v2
aws inspector2 enable \
  --resource-types EC2 ECR

# Inspector doesn't need S3 bucket - it's API-based
```

### Step 3: Update Configuration and Restart

**After updating .env, run the helper script:**
```bash
# Update Wazuh config from .env
./scripts/update-aws-config.sh

# Restart manager to apply changes
docker compose restart wazuh.manager

# Wait 30 seconds
sleep 30

# Verify AWS integration
docker compose exec wazuh.manager tail -f /var/ossec/logs/ossec.log | grep aws
# Look for: "Executing Service Analysis: (guard-duty)"
```

---

##  Azure Integration

### Step 1: Create Event Hub

**Your `.env` file already has Azure section ready!**

```bash
# Login to Azure
az login

# Set variables
RESOURCE_GROUP="wazuh-rg"
LOCATION="eastus"
NAMESPACE="wazuh-event-hub-ns"
EVENTHUB="wazuh-activity-logs"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Event Hub namespace (Basic tier - $11/month)
az eventhubs namespace create \
  --name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --sku Basic \
  --location $LOCATION

# Create Event Hub
az eventhubs eventhub create \
  --name $EVENTHUB \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP

# Get connection string
CONNECTION_STRING=$(az eventhubs namespace authorization-rule keys list \
  --resource-group $RESOURCE_GROUP \
  --namespace-name $NAMESPACE \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

echo "Azure Connection String:"
echo $CONNECTION_STRING

#  UPDATE .env FILE:
# AZURE_CONNECTION_STRING=Endpoint=sb://...
# AZURE_EVENTHUB_NAME=wazuh-activity-logs
```

### Step 2: Configure Activity Logs Diagnostic Settings
```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create diagnostic setting
az monitor diagnostic-settings create \
  --name send-to-wazuh \
  --resource /subscriptions/$SUBSCRIPTION_ID \
  --event-hub $EVENTHUB \
  --event-hub-rule /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.EventHub/namespaces/$NAMESPACE/authorizationRules/RootManageSharedAccessKey \
  --logs '[
    {"category": "Administrative", "enabled": true},
    {"category": "Security", "enabled": true},
    {"category": "Alert", "enabled": true},
    {"category": "Policy", "enabled": true}
  ]'
```

### Step 3: Install & Configure Filebeat

**On Wazuh Server (host machine, not container):**
```bash
# Install Filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-amd64.deb
sudo dpkg -i filebeat-8.11.0-amd64.deb
```

**Create Filebeat configuration (2 files):**

**File 1: Main Configuration (no credentials):**
```bash
sudo tee /etc/filebeat/filebeat.yml > /dev/null << 'EOF'
filebeat.config.inputs:
  enabled: true
  path: /etc/filebeat/azure.yml

output.logstash:
  hosts: ["localhost:5044"]

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF
```

**File 2: Azure Input Configuration (credentials from .env):**
```bash
# Load environment variables
source .env

# Create Azure input config
sudo tee /etc/filebeat/azure.yml > /dev/null << EOF
- type: azure-eventhub
  enabled: true
  connection_string: "${AZURE_CONNECTION_STRING}"
  eventhub: "${AZURE_EVENTHUB_NAME}"
  consumer_group: "${AZURE_CONSUMER_GROUP}"
  storage_account: "${AZURE_STORAGE_ACCOUNT}"
  storage_account_key: "${AZURE_STORAGE_ACCOUNT_KEY}"
EOF
```

**Start Filebeat:**
```bash
sudo systemctl enable filebeat
sudo systemctl start filebeat
sudo systemctl status filebeat
```

### Step 4: Deploy Azure Detection Rules

**Rules are already in the repository!**

```bash
# Verify Azure rules exist
ls -la config/wazuh_cluster/rules/

# Should see:
# - 0580-azure_rules.xml (38 Azure custom rules)
# - azure_decoders.xml
```

**Restart manager to load rules:**
```bash
docker compose restart wazuh.manager
```

### Step 5: Verify Azure Integration
```bash
# Check Filebeat is sending events
sudo journalctl -u filebeat -f

# Check Logstash receiving events
docker compose logs -f logstash | grep azure

# Check Wazuh Dashboard
# Navigate to: Security Events → Search "azure"
```



##  EC2 Agent Installation

### Important Note About Agents

**Agents are NOT pre-configured in the repository!**

Each agent gets unique keys generated dynamically during enrollment. This is handled automatically by Wazuh when you install an agent.

### Step 1: Prepare Wazuh Manager

**On Manager - Enable Agent Enrollment:**
```bash
# Check agent enrollment port is open
docker compose exec wazuh.manager netstat -tlnp | grep 1515

# Should see: tcp 0.0.0.0:1515 LISTEN
```

### Step 2: Install Wazuh Agent on EC2

**Option A: Direct Connection (If Manager has Public IP)**
```bash
# SSH to EC2
ssh ec2-user@YOUR_EC2_IP

# Install agent
WAZUH_MANAGER="YOUR_MANAGER_PUBLIC_IP" \
WAZUH_AGENT_NAME="ec2-production" \
curl -s https://packages.wazuh.com/4.x/wazuh-install.sh | sudo bash
```

**Option B: Tailscale VPN (Recommended for Private IPs)**
```bash
# On Wazuh Manager (host)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# On EC2 Instance
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Get Tailscale IP of manager
tailscale ip -4

# Install agent using Tailscale IP
WAZUH_MANAGER="100.x.x.x" \
WAZUH_AGENT_NAME="ec2-production" \
curl -s https://packages.wazuh.com/4.x/wazuh-install.sh | sudo bash
```

**Start agent:**
```bash
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

### Step 3: Configure Agent Monitoring

**Edit agent config:**
```bash
sudo nano /var/ossec/etc/ossec.conf
```

**Enable FIM, Rootcheck, SCA:**
```xml
<!-- File Integrity Monitoring -->
<syscheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>
  <scan_on_start>yes</scan_on_start>
  
  <!-- Monitor critical directories -->
  <directories realtime="yes" check_all="yes">/etc</directories>
  <directories realtime="yes" check_all="yes">/usr/bin</directories>
  <directories realtime="yes" check_all="yes">/usr/sbin</directories>
  <directories check_all="yes">/home</directories>
  <directories check_all="yes">/root</directories>
  
  <!-- Ignore common changes -->
  <ignore>/etc/mtab</ignore>
  <ignore>/etc/hosts.deny</ignore>
  <ignore>/etc/mail/statistics</ignore>
  <ignore>/etc/random-seed</ignore>
  <ignore>/etc/adjtime</ignore>
</syscheck>

<!-- Rootkit Detection -->
<rootcheck>
  <disabled>no</disabled>
  <frequency>43200</frequency>
  <rootkit_files>/var/ossec/etc/shared/rootkit_files.txt</rootkit_files>
  <rootkit_trojans>/var/ossec/etc/shared/rootkit_trojans.txt</rootkit_trojans>
  <system_audit>/var/ossec/etc/shared/system_audit_rcl.txt</system_audit>
  <system_audit>/var/ossec/etc/shared/cis_rhel_linux_rcl.txt</system_audit>
</rootcheck>

<!-- Security Configuration Assessment -->
<sca>
  <enabled>yes</enabled>
  <scan_on_start>yes</scan_on_start>
  <interval>12h</interval>
  <skip_nfs>yes</skip_nfs>
</sca>

<!-- Log Collection -->
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/auth.log</location>
</localfile>

<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/syslog</location>
</localfile>

<localfile>
  <log_format>command</log_format>
  <command>df -P</command>
  <frequency>360</frequency>
</localfile>
```

**Restart agent:**
```bash
sudo systemctl restart wazuh-agent
```

### Step 4: Verify Agent Connection

**On Wazuh Manager:**
```bash
# List all agents
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l

# Expected output:
# Wazuh agent_control. List of available agents:
#    ID: 000, Name: wazuh.manager (server), IP: 127.0.0.1, Active/Local
#    ID: 001, Name: ec2-production, IP: 10.x.x.x, Active
#
# List of agentless devices:

# Get detailed agent info
docker compose exec wazuh.manager /var/ossec/bin/agent_control -i 001

# Check agent status in real-time
docker compose exec wazuh.manager tail -f /var/ossec/logs/ossec.log | grep "ec2-production"
```

**On Dashboard:**
1. Login to Wazuh Dashboard
2. Navigate to: **Management** → **Agents**
3. Verify agent shows as **Active**



##  Post-Installation

### 1. Change Default Passwords

**Dashboard Password:**
1. Login to dashboard: `https://YOUR_SERVER_IP`
2. Navigate to: **Menu** → **Security** → **Internal users**
3. Select `admin` user → **Edit**
4. Set strong password (min 8 chars, uppercase, lowercase, number, special)
5. Logout and login with new password

**Update .env file:**
```bash
nano .env
# Update:
INDEXER_PASSWORD=YourNewStrongPassword
API_PASSWORD=YourNewStrongPassword
```

### 2. Configure Email Alerts

**Email settings already use .env variables!**

Just update `.env` file:
```bash
nano .env

# Update these values:
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_FROM=wazuh-alerts@yourdomain.com
EMAIL_TO=security-team@yourdomain.com
EMAIL_USERNAME=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
```

**For Gmail, create App Password:**
1. Google Account → Security → 2-Step Verification → App passwords
2. Generate password
3. Update `EMAIL_PASSWORD` in `.env`

**Restart manager:**
```bash
docker compose restart wazuh.manager
```

### 3. Set Up Automated Backup

**Backup script is already in repository:**
```bash
# Make executable
chmod +x scripts/wazuh-backup-complete-v2.sh

# Test backup
./scripts/wazuh-backup-complete-v2.sh

# Verify backup created
ls -lh /var/backups/wazuh/wazuh-backup-*.tar.gz
```

**Schedule daily backup:**
```bash
# Create backup directory
sudo mkdir -p /var/backups/wazuh
sudo chown $USER:$USER /var/backups/wazuh

# Open crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /home/$USER/multi-cloud-siem-wazuh/scripts/wazuh-backup-complete-v2.sh

# Add weekly cleanup (keep last 7 backups)
0 3 * * 0 find /var/backups/wazuh -name "wazuh-backup-*.tar.gz" -mtime +7 -delete
```

### 4. Backup Your .env File

**CRITICAL: Backup .env to secure location!**
```bash
# Encrypt and backup
gpg -c .env
# Enter passphrase

# Move encrypted file to secure location
mv .env.gpg ~/secure-backups/

# To restore later:
gpg -d ~/secure-backups/.env.gpg > .env
```



##  Verification

### 1. Check All Services
```bash
# All containers healthy
docker compose ps

# Expected output:
# NAME                    STATUS
# wazuh.manager           Up (healthy)
# wazuh.indexer           Up (healthy)
# wazuh.dashboard         Up (healthy)
# logstash                Up
```

### 2. Dashboard Access
```bash
# Open browser
https://YOUR_SERVER_IP

# Verify:
#  Dashboard loads
#  Login successful
#  Security Events visible
#  Agents showing
```

### 3. AWS Events Verification
```bash
# Check AWS module is running
docker compose exec wazuh.manager grep "aws-s3" /var/ossec/logs/ossec.log | tail -20

# Should see:
# INFO: Executing Service Analysis: (guard-duty)
# INFO: Executing Bucket Analysis: (cloudtrail)
# INFO: Executing Bucket Analysis: (vpcflow)

# Dashboard → Security Events → Search "cloudtrail"
# Dashboard → Security Events → Search "guardduty"
```

### 4. Azure Events Verification
```bash
# Check Filebeat status
sudo systemctl status filebeat

# Check events flowing
sudo journalctl -u filebeat -n 50 | grep "azure"

# Check Logstash
docker compose logs logstash | grep azure | tail -20

# Dashboard → Security Events → Search "azure"
```

### 5. Agent Status
```bash
# List all agents
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l

# Should show:
# ID: 001, Name: ec2-production, IP: x.x.x.x, Active

# Dashboard → Management → Agents
```

### 6. Test Detection Rules

**Test File Integrity Monitoring:**
```bash
# On EC2 agent
ssh ec2-user@YOUR_EC2_IP
sudo touch /etc/test-fim-detection.txt
echo "test content" | sudo tee /etc/test-fim-detection.txt

# Dashboard → File Integrity Monitoring
# Should see alert within 1-2 minutes
```

**Test Azure Rule:**
```bash
# Create Azure VM (or any resource)
az vm create --resource-group test-rg --name test-vm --image UbuntuLTS

# Dashboard → Security Events
# Search for: rule.groups:"azure"
# Should see VM creation event
```

**Test AWS CloudTrail:**
```bash
# Create S3 bucket
aws s3 mb s3://test-bucket-$(date +%s)

# Dashboard → Security Events  
# Search for: rule.groups:"aws"
# Should see CreateBucket event
```



##  Troubleshooting

### Environment Variable Issues

**Variables Not Loading:**
```bash
# Verify .env file exists
ls -la .env

# Check permissions
chmod 600 .env

# Test loading
source .env
echo $AWS_ACCESS_KEY_ID

# Docker Compose should auto-load .env
docker compose config
```

### Container Issues

**Manager Not Starting:**
```bash
# Check logs
docker compose logs wazuh.manager | tail -50

# Common issues:
# 1. SSL certificates missing
ls -la config/wazuh_indexer_ssl_certs/

# If missing, regenerate:
docker compose -f generate-indexer-certs.yml run --rm generator
docker compose restart wazuh.manager

# 2. Invalid configuration
docker compose exec wazuh.manager /var/ossec/bin/wazuh-logtest
```

**Indexer Issues:**
```bash
# Check cluster health
curl -k -u admin:SecurePassword https://localhost:9200/_cluster/health?pretty

# Expected: "status": "green" or "yellow"

# Check memory
docker stats wazuh.indexer

# Adjust memory in docker-compose.yml if needed:
# OPENSEARCH_JAVA_OPTS: "-Xms4g -Xmx4g"  # Change to 2g for 8GB RAM
```

### AWS Integration Issues

**No AWS Events:**
```bash
# Verify .env credentials
cat .env | grep AWS

# Test AWS credentials
source .env
aws s3 ls --region $AWS_REGION

# Check bucket access
aws s3 ls s3://$AWS_CLOUDTRAIL_BUCKET/

# Verify config was updated
grep -A 5 "cloudtrail" config/wazuh_cluster/wazuh_manager.conf

# Check Wazuh logs
docker compose exec wazuh.manager grep "aws" /var/ossec/logs/ossec.log | tail -20
```

### Azure Integration Issues

**No Azure Events:**
```bash
# Verify .env
cat .env | grep AZURE

# Check Filebeat
sudo systemctl status filebeat

# Test Filebeat config
sudo filebeat test config
sudo filebeat test output

# Check for errors
sudo journalctl -u filebeat -n 100 | grep -i error

# Test Event Hub connectivity
az eventhubs eventhub show \
  --resource-group wazuh-rg \
  --namespace-name wazuh-event-hub-ns \
  --name wazuh-activity-logs
```

### Agent Issues

**Agent Not Connecting:**
```bash
# On agent - check status
sudo systemctl status wazuh-agent

# Check connectivity
source .env
telnet $WAZUH_MANAGER_IP 1514
telnet $WAZUH_MANAGER_IP 1515

# Check agent logs
sudo tail -f /var/ossec/logs/ossec.log

# On manager - check firewall
sudo ufw status | grep 151

# List agents
docker compose exec wazuh.manager /var/ossec/bin/agent_control -l
```



##  Next Steps

1.  Review Security Events daily
2.  Tune detection rules (reduce false positives)
3.  Create custom dashboards
4.  Document baseline behavior
5.  Test incident response procedures
6.  Verify backup restoration
7.  Monitor system performance
8.  Keep Wazuh updated
9.  Rotate credentials quarterly



##  Getting Help

- **Wazuh Documentation**: https://documentation.wazuh.com/
- **Community Forum**: https://groups.google.com/g/wazuh
- **GitHub Issues**: https://github.com/ghulamdastagir123/multi-cloud-siem-wazuh/issues
- **Slack Community**: https://wazuh.com/community/join-us-on-slack/



##  Security Best Practices

1. **Never commit .env to Git** - Already in .gitignore
2. **Rotate credentials quarterly** - AWS keys, Azure keys, passwords
3. **Enable MFA** - AWS, Azure, Dashboard
4. **Restrict network access** - Use security groups/firewall
5. **Monitor failed login attempts** - Dashboard → Security
6. **Keep systems updated** - OS, Docker, Wazuh
7. **Encrypt backups** - Use GPG encryption
8. **Review logs regularly** - Daily security review
9. **Use least privilege** - IAM policies, RBAC
10. **Audit access** - CloudTrail, Activity Logs



**Installation Complete!**

Your Multi-Cloud SIEM is now operational with secure environment-based credential management.

All sensitive credentials are stored in `.env` file (never committed to Git).

Return to [README](README.md) for usage and best practices.
