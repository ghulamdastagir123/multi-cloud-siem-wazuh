#  System Architecture

Comprehensive technical architecture documentation for the Multi-Cloud SIEM with Wazuh.



##  Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [AWS Integration Architecture](#aws-integration-architecture)
6. [Azure Integration Architecture](#azure-integration-architecture)
7. [Network Architecture](#network-architecture)
8. [Security Architecture](#security-architecture)
9. [Scalability & Performance](#scalability--performance)
10. [Disaster Recovery](#disaster-recovery)



##  Overview

### Architecture Highlights

- **Deployment Type**: Hybrid (On-premise manager with cloud workloads)
- **Platform**: Docker containerized Wazuh 4.13
- **Cloud Coverage**: AWS + Azure multi-cloud
- **Agent Support**: EC2 endpoints via Tailscale VPN
- **Log Processing**: 370+ events/day with real-time analysis
- **Storage**: OpenSearch/Elasticsearch for event indexing
- **Detection**: 50 custom rules with MITRE ATT&CK mapping

### Design Principles

1. **Cost Efficiency**: Open-source stack with 99% cost savings vs commercial SIEM
2. **Scalability**: Containerized architecture for easy horizontal scaling
3. **Security**: Encrypted communications, TLS/SSL, VPN for agent connectivity
4. **Compliance**: PCI DSS, HIPAA, ISO 27001, NIST 800-53, GDPR, SOC 2 coverage
5. **Maintainability**: Infrastructure-as-Code, version controlled configurations
6. **Observability**: Centralized logging, real-time dashboards, email alerting



##  System Architecture

### High-Level Architecture

```mermaid
graph TB
    subgraph "Cloud Services"
        AWS[AWS Services]
        Azure[Azure Services]
        EC2[EC2 Instances]
    end
    
    subgraph "Data Ingestion Layer"
        S3[S3 Buckets]
        EventHub[Azure Event Hub]
        Filebeat[Filebeat Agent]
    end
    
    subgraph "Wazuh SIEM Platform - Docker Host"
        subgraph "Processing Layer"
            Manager[Wazuh Manager<br/>Analysis Engine]
            Logstash[Logstash<br/>Log Processor]
        end
        
        subgraph "Storage Layer"
            Indexer[Wazuh Indexer<br/>OpenSearch]
        end
        
        subgraph "Presentation Layer"
            Dashboard[Wazuh Dashboard<br/>Web UI]
        end
    end
    
    subgraph "Monitoring Agents"
        Agent1[EC2 Agent 001<br/>via Tailscale VPN]
    end
    
    subgraph "Alerting"
        Email[Email Alerts<br/>SMTP]
        AR[Active Response<br/>Automated Actions]
    end
    
    %% AWS Integration
    AWS --> |CloudTrail Logs| S3
    AWS --> |GuardDuty Findings| S3
    AWS --> |VPC Flow Logs| S3
    AWS --> |Inspector Findings| Manager
    S3 --> |5-minute polling| Manager
    
    %% Azure Integration
    Azure --> |Activity Logs| EventHub
    EventHub --> |Real-time stream| Filebeat
    Filebeat --> |Port 5044| Logstash
    Logstash --> |Processed logs| Manager
    
    %% Agent Communication
    EC2 --> |Tailscale VPN| Agent1
    Agent1 --> |Port 1514/1515<br/>TLS Encrypted| Manager
    
    %% Internal Processing
    Manager --> |Index events| Indexer
    Manager --> |Trigger alerts| Email
    Manager --> |Execute scripts| AR
    Indexer --> |Query data| Dashboard
    
    %% Access
    Dashboard -.-> |HTTPS Port 443| User((Security<br/>Analyst))
    
    style Manager fill:#e1f5ff
    style Indexer fill:#fff4e1
    style Dashboard fill:#e8f5e9
    style AWS fill:#ff9900
    style Azure fill:#0078d4
    style Agent1 fill:#4CAF50
```

### Architecture Layers

| Layer | Components | Purpose |
|-------|-----------|---------|
| **Cloud Sources** | AWS Services, Azure Services | Generate security events and logs |
| **Data Ingestion** | S3 buckets, Event Hub, Filebeat | Collect and forward logs |
| **Processing** | Wazuh Manager, Logstash | Decode, analyze, correlate events |
| **Storage** | OpenSearch/Elasticsearch | Index and store security events |
| **Presentation** | Wazuh Dashboard | Visualize alerts and analytics |
| **Endpoints** | Wazuh Agents | Monitor EC2 instances |
| **Response** | Email alerts, Active Response | Notify and automate actions |



##  Component Details

### Wazuh Manager

**Role**: Core analysis engine and rule processor

**Specifications:**
- **Container**: `wazuh/wazuh:4.13.0`
- **CPU**: 2-4 cores
- **Memory**: 4GB allocated
- **Ports**: 1514 (agent data), 1515 (enrollment), 55000 (API)

**Key Features:**
- Log decoding and parsing (3000+ decoders)
- Rule-based detection (50 custom rules)
- MITRE ATT&CK framework mapping
- AWS cloud integration (S3 wodle)
- Azure log processing (via Logstash)
- Active Response automation
- Email alerting
- Agent management
- CIS benchmark scanning
- File integrity monitoring
- Vulnerability detection

### Wazuh Indexer (OpenSearch)

**Role**: Event storage and search engine

**Specifications:**
- **Container**: `wazuh/wazuh-indexer:4.13.0`
- **CPU**: 2-4 cores
- **Memory**: 4-8GB (configurable)
- **Port**: 9200 (internal API)

**Key Features:**
- RESTful API for queries
- Full-text search
- Aggregations and analytics
- Index lifecycle management
- TLS encryption
- Role-based access control (RBAC)

### Wazuh Dashboard

**Role**: Web-based visualization and management interface

**Specifications:**
- **Container**: `wazuh/wazuh-dashboard:4.13.0`
- **CPU**: 1-2 cores
- **Memory**: 2GB
- **Port**: 443 (HTTPS)

**Key Features:**
- Security events dashboard
- MITRE ATT&CK visualization
- Agent management interface
- File integrity monitoring views
- Vulnerability reports
- Compliance dashboards
- Custom visualizations



##  Data Flow

### Complete Log Processing Pipeline

```mermaid
flowchart TB
    subgraph "1. Log Generation"
        A1[AWS CloudTrail<br/>API Calls]
        A2[AWS GuardDuty<br/>Threat Detection]
        A3[AWS VPC Flow<br/>Network Traffic]
        A4[AWS Inspector<br/>Vulnerabilities]
        AZ1[Azure Activity Logs<br/>Resource Changes]
        EC1[EC2 Agent<br/>Syslog/FIM/SCA]
    end
    
    subgraph "2. Collection Layer"
        S3[S3 Buckets<br/>JSON/CSV Logs]
        EH[Event Hub<br/>Real-time Stream]
        FB[Filebeat<br/>Event Collector]
    end
    
    subgraph "3. Ingestion Layer"
        WM[Wazuh Manager<br/>AWS Wodle]
        LS[Logstash<br/>Pipeline Processor]
    end
    
    subgraph "4. Processing Layer"
        DEC[Decoders<br/>Parse & Extract]
        RULES[Detection Rules<br/>50 Custom Rules]
        COR[Correlation<br/>MITRE Mapping]
    end
    
    subgraph "5. Storage Layer"
        ES[OpenSearch<br/>Indexed Events]
        ARCH[Archives<br/>Raw Logs]
    end
    
    subgraph "6. Action Layer"
        DASH[Dashboard<br/>Visualization]
        ALERT[Email Alerts<br/>Level 12+]
        AR[Active Response<br/>Firewall Rules]
    end
    
    %% AWS Flow
    A1 --> S3
    A2 --> S3
    A3 --> S3
    A4 --> WM
    S3 --> |5-min poll| WM
    
    %% Azure Flow
    AZ1 --> EH
    EH --> FB
    FB --> |Port 5044| LS
    LS --> |JSON logs| WM
    
    %% Agent Flow
    EC1 --> |TLS 1514| WM
    
    %% Processing Flow
    WM --> DEC
    DEC --> RULES
    RULES --> COR
    
    %% Storage Flow
    COR --> ES
    COR --> ARCH
    
    %% Action Flow
    ES --> DASH
    COR --> ALERT
    COR --> AR
    
    style WM fill:#e1f5ff
    style ES fill:#fff4e1
    style RULES fill:#ffe1e1
    style DASH fill:#e8f5e9
```



##  AWS Integration Architecture

### AWS Services Topology

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "Logging Services"
            CT[CloudTrail<br/>API Activity Monitoring]
            GD[GuardDuty<br/>Threat Intelligence]
            VPC[VPC Flow Logs<br/>Network Monitoring]
            INS[Inspector v2<br/>Vulnerability Scanning]
        end
        
        subgraph "Storage Layer"
            S3_CT[S3: cloudtrail-logs<br/>JSON Files]
            S3_GD[S3: guardduty-logs<br/>JSON Findings]
            S3_VPC[S3: vpc-flow-logs<br/>Parquet Files]
        end
        
        subgraph "IAM Security"
            IAM[IAM User: wazuh-siem<br/>Access Keys]
            POL[IAM Policy<br/>S3 Read, GuardDuty, Inspector]
        end
        
        subgraph "Compute"
            EC2_1[EC2 Instance<br/>Production Workload]
        end
    end
    
    subgraph "Wazuh Manager"
        AWS_WOD[AWS S3 Wodle<br/>Python Module]
        AWS_DB[State Database<br/>aws_services.db]
        AWS_RULES[AWS Detection Rules<br/>0225-aws_rules.xml]
    end
    
    %% CloudTrail Flow
    CT --> S3_CT
    S3_CT --> |Every 5 minutes| AWS_WOD
    
    %% GuardDuty Flow
    GD --> S3_GD
    S3_GD --> |Every 5 minutes| AWS_WOD
    
    %% VPC Flow Logs
    VPC --> S3_VPC
    S3_VPC --> |Every 5 minutes| AWS_WOD
    
    %% Inspector API
    INS --> |API Calls| AWS_WOD
    
    %% IAM
    IAM --> POL
    POL --> S3_CT
    POL --> S3_GD
    POL --> S3_VPC
    POL --> INS
    AWS_WOD -.-> |Uses credentials| IAM
    
    %% Processing
    AWS_WOD --> AWS_DB
    AWS_WOD --> AWS_RULES
    
    %% EC2 Agent
    EC2_1 --> |Wazuh Agent<br/>Tailscale VPN| Wazuh_Manager[Wazuh Manager]
    
    style CT fill:#ff9900
    style GD fill:#ff9900
    style VPC fill:#ff9900
    style INS fill:#ff9900
    style AWS_WOD fill:#e1f5ff
```



##  Azure Integration Architecture

### Azure Services Topology

```mermaid
graph TB
    subgraph "Azure Cloud"
        subgraph "Azure Services"
            VM[Virtual Machines]
            NSG[Network Security Groups]
            SA[Storage Accounts]
            KV[Key Vault]
            ADB[Azure Databases]
        end
        
        subgraph "Activity Logs"
            AL[Activity Log<br/>Resource Operations]
            CAT1[Administrative Category]
            CAT2[Security Category]
            CAT3[Alert Category]
            CAT4[Policy Category]
        end
        
        subgraph "Event Hub"
            NS[Event Hub Namespace<br/>wazuh-event-hub-ns]
            EH[Event Hub<br/>wazuh-activity-logs]
            CG[Consumer Group<br/>$Default]
        end
        
        subgraph "Diagnostic Settings"
            DS[Diagnostic Setting<br/>send-to-wazuh]
        end
    end
    
    subgraph "Wazuh Server Host"
        FB[Filebeat 8.11.0<br/>azure-eventhub input]
        LS[Logstash 8.11.0<br/>Pipeline Processor]
        
        subgraph "Wazuh Manager"
            AZ_DEC[Azure Decoder<br/>azure_decoders.xml]
            AZ_RULES[38 Azure Rules<br/>azure_rules.xml]
            MITRE[14 Azure MITRE Techniques<br/>38 Custom Rules]
        end
    end
    
    %% Azure Flow
    VM --> AL
    NSG --> AL
    SA --> AL
    KV --> AL
    ADB --> AL
    
    AL --> CAT1
    AL --> CAT2
    AL --> CAT3
    AL --> CAT4
    
    CAT1 --> DS
    CAT2 --> DS
    CAT3 --> DS
    CAT4 --> DS
    
    DS --> NS
    NS --> EH
    EH --> CG
    
    %% Wazuh Flow
    CG --> |Real-time stream<br/>AMQP 1.0| FB
    FB --> |Port 5044<br/>Beats Protocol| LS
    LS --> |JSON logs| AZ_DEC
    AZ_DEC --> AZ_RULES
    AZ_RULES --> MITRE
    
    style EH fill:#0078d4
    style FB fill:#00d9ff
    style AZ_RULES fill:#ffe1e1
```



##  Network Architecture

### Network Topology

```mermaid
graph TB
    subgraph "Internet"
        USER[Security Analyst<br/>HTTPS Browser]
    end
    
    subgraph "Wazuh Server - 192.168.1.100"
        subgraph "Docker Network: wazuh"
            MGR[wazuh.manager<br/>172.18.0.2]
            IDX[wazuh.indexer<br/>172.18.0.3]
            DASH[wazuh.dashboard<br/>172.18.0.4]
            LOG[logstash<br/>172.18.0.5]
        end
        
        subgraph "Host Services"
            FB_HOST[Filebeat<br/>127.0.0.1:5044]
            FW[UFW Firewall]
        end
        
        subgraph "Tailscale VPN"
            TS[Tailscale Node<br/>100.64.0.1]
        end
    end
    
    subgraph "AWS VPC - 10.0.0.0/16"
        EC2[EC2 Instance<br/>10.0.1.50<br/>Tailscale: 100.64.0.2]
    end
    
    subgraph "Azure Event Hub"
        EH[Event Hub Endpoint<br/>wazuh-event-hub-ns.servicebus.windows.net]
    end
    
    subgraph "AWS S3"
        S3[S3 Endpoints<br/>s3.amazonaws.com]
    end
    
    %% User Access
    USER --> |HTTPS:443| FW
    FW --> |Port 443| DASH
    
    %% Internal Docker
    DASH --> |HTTP:9200| IDX
    MGR --> |HTTP:9200| IDX
    LOG --> |TCP:9200| MGR
    
    %% Filebeat
    EH --> |AMQP:5671| FB_HOST
    FB_HOST --> |Beats:5044| LOG
    
    %% AWS Integration
    S3 --> |HTTPS:443| MGR
    
    %% Agent Communication
    EC2 --> |Tailscale VPN| TS
    TS --> |TLS:1514/1515| MGR
    
    %% Firewall Rules
    FW -.-> |Allow 443| DASH
    FW -.-> |Allow 1514| MGR
    FW -.-> |Allow 1515| MGR
    FW -.-> |Allow 55000| MGR
    
    style MGR fill:#e1f5ff
    style IDX fill:#fff4e1
    style DASH fill:#e8f5e9
    style TS fill:#4CAF50
```

### Port Matrix

| Service | Port | Protocol | Direction | Purpose |
|---------|------|----------|-----------|---------|
| **Wazuh Dashboard** | 443 | TCP (HTTPS) | Inbound | Web UI access |
| **Wazuh Manager** | 1514 | TCP (TLS) | Inbound | Agent data |
| **Wazuh Manager** | 1515 | TCP | Inbound | Agent enrollment |
| **Wazuh Manager** | 55000 | TCP (HTTPS) | Inbound | API access |
| **Wazuh Indexer** | 9200 | TCP (HTTP) | Internal | REST API |
| **Logstash** | 5044 | TCP | Inbound | Filebeat input |
| **Filebeat** | 5671 | TCP (AMQP) | Outbound | Azure Event Hub |
| **Tailscale** | 41641 | UDP | Bidirectional | VPN mesh network |



##  Security Architecture

### Security Layers

```mermaid
graph TB
    subgraph "Layer 1: Network Security"
        FW[Firewall - UFW]
        VPN[VPN - Tailscale]
        TLS[TLS 1.2+ Encryption]
    end
    
    subgraph "Layer 2: Authentication & Authorization"
        AUTH[Dashboard Authentication]
        RBAC[Role-Based Access Control]
        API_KEY[API Keys]
    end
    
    subgraph "Layer 3: Data Security"
        ENCRYPT[Data Encryption at Rest]
        TRANSIT[Data Encryption in Transit]
        SECRETS[Secrets Management - .env]
    end
    
    subgraph "Layer 4: Application Security"
        AR[Active Response]
        FIM[File Integrity Monitoring]
        VULN[Vulnerability Detection]
    end
    
    subgraph "Layer 5: Monitoring & Logging"
        AUDIT[Audit Logging]
        ALERT[Real-time Alerts]
        COMP[Compliance Monitoring]
    end
    
    FW --> AUTH
    VPN --> AUTH
    TLS --> AUTH
    
    AUTH --> ENCRYPT
    RBAC --> ENCRYPT
    API_KEY --> ENCRYPT
    
    ENCRYPT --> AR
    TRANSIT --> AR
    SECRETS --> AR
    
    AR --> AUDIT
    FIM --> AUDIT
    VULN --> AUDIT
    
    style FW fill:#ff6b6b
    style AUTH fill:#4ecdc4
    style ENCRYPT fill:#ffe66d
    style AR fill:#95e1d3
    style AUDIT fill:#f38181
```



##  Scalability & Performance

### Current Capacity

**Throughput:**
- Events per second (EPS): 50-100
- Daily events: 370+ (current baseline)
- Peak EPS: 500+ (tested with load)

**Storage:**
- Active indices: 7 days × 1GB/day = 7GB
- Total capacity: 100GB SSD
- Retention: 30 days before archive

**Processing:**
- Average decode time: <10ms
- Rule evaluation: <5ms
- End-to-end latency: <100ms



##  Disaster Recovery

### Backup Strategy

**What's Backed Up:**
1. Docker volumes (15 volumes)
2. Host configurations
3. Custom rules and decoders
4. SSL certificates
5. Environment variables (.env)

**Backup Schedule:**
```cron
# Daily at 2 AM
0 2 * * * /path/to/wazuh-backup-complete-v2.sh

# Weekly cleanup (keep last 7 backups)
0 3 * * 0 find /var/backups/wazuh -mtime +7 -delete
```

**Recovery Time Objective (RTO):** 1 hour  
**Recovery Point Objective (RPO):** 24 hours



##  References

### Official Documentation
- [Wazuh Documentation](https://documentation.wazuh.com/)
- [OpenSearch Documentation](https://opensearch.org/docs/)
- [Docker Documentation](https://docs.docker.com/)

### Architecture Resources
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)



**Architecture Version:** 1.0  
**Last Updated:** November 20, 2025  
**Maintained By:** Ghulam Dastagir

Return to [README](README.md) | View [SETUP Guide](SETUP.md)
