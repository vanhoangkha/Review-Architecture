# Hospital Management System - AWS Infrastructure

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange)](https://aws.amazon.com/)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-as--Code-blue)](https://aws.amazon.com/infrastructure/)
[![Security](https://img.shields.io/badge/Security-Best--Practices-green)](https://aws.amazon.com/security/)
[![WAF](https://img.shields.io/badge/AWS-WAF-red)](https://aws.amazon.com/waf/)

A production-ready AWS infrastructure setup for Hospital Management System with secure VPN access, WAF protection, and following AWS Well-Architected Framework principles.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                Internet                                     │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────┐
│                    AWS WAF v2                                              │
│              (DDoS Protection, Rate Limiting)                              │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────┐
│                    CloudFront CDN                                           │
│                 (Global Edge Locations)                                     │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────┐
│                Application Load Balancer                                    │
│              (Multi-AZ, SSL Termination)                                    │
└─────────────┬───────────────────────────────────────────┬───────────────────┘
              │                                           │
┌─────────────▼─────────────┐                 ┌───────────▼─────────────┐
│     WordPress Server      │                 │      CRM Server         │
│    (Patient Portal)       │                 │   (Staff Management)    │
│   Private Subnet 1A       │                 │   Private Subnet 1A     │
└─────────────┬─────────────┘                 └───────────┬─────────────┘
              │                                           │
              └─────────────┬───────────────────────────────┘
                            │
              ┌─────────────▼─────────────┐
              │      RDS MySQL            │
              │   (Multi-AZ, Encrypted)   │
              │   Private Subnets         │
              └───────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          VPN Access Layer                                  │
│  ┌─────────────────┐                                                       │
│  │   Jump Host     │ ◄─── WireGuard VPN ◄─── Admin Users                  │
│  │  (Bastion Host) │                                                       │
│  │ Public Subnet   │                                                       │
│  └─────────────────┘                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture Components](#architecture-components)
- [Security Implementation](#security-implementation)
- [WAF Configuration](#waf-configuration)
- [Deployment Guide](#deployment-guide)
- [Configuration Management](#configuration-management)
- [Monitoring & Logging](#monitoring--logging)
- [Backup & Disaster Recovery](#backup--disaster-recovery)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

## ✨ Features

### 🔒 Security First
- **AWS WAF v2**: Advanced web application firewall with managed rules
- **Zero Trust Network**: All resources in private subnets
- **VPN-Only Access**: Secure WireGuard VPN for administrative access
- **Secrets Management**: AWS Secrets Manager for database credentials
- **Encryption**: Data encrypted at rest and in transit
- **IAM Best Practices**: Least privilege access with role-based permissions

### 🛡️ WAF Protection
- **DDoS Protection**: AWS Shield Standard integration
- **Rate Limiting**: Request rate limiting per IP
- **Geo Blocking**: Country-based access control
- **SQL Injection Protection**: Automated SQL injection detection
- **XSS Protection**: Cross-site scripting prevention
- **Bot Protection**: Automated bot detection and blocking

### 🚀 High Availability & Scalability
- **Multi-AZ Deployment**: Resources distributed across availability zones
- **Auto Scaling Ready**: Infrastructure prepared for horizontal scaling
- **Load Balancing**: Application Load Balancer with health checks
- **CDN Integration**: CloudFront for global content delivery

### 📊 Observability
- **Comprehensive Monitoring**: CloudWatch metrics and alarms
- **WAF Logging**: Detailed request logging and analysis
- **Centralized Logging**: Application and infrastructure logs
- **Performance Tracking**: Real-time performance metrics
- **Security Monitoring**: VPC Flow Logs and CloudTrail

### 💰 Cost Optimized
- **Right-Sized Resources**: Appropriate instance types for workload
- **Reserved Capacity**: Cost savings through reserved instances
- **Automated Backups**: Efficient backup strategies
- **Resource Tagging**: Cost allocation and management

## 🚀 Prerequisites

### Required Tools
- AWS Account with appropriate permissions
- Domain name for SSL certificates
- SSH client (Terminal/PuTTY)
- Web browser for AWS Console access

### Required AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "rds:*",
        "elbv2:*",
        "cloudfront:*",
        "route53:*",
        "certificatemanager:*",
        "secretsmanager:*",
        "wafv2:*",
        "shield:*",
        "iam:*",
        "vpc:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Network Requirements
- VPC CIDR: `10.0.0.0/16`
- Public Subnets: `10.0.1.0/24`, `10.0.2.0/24`
- Private Subnets: `10.0.10.0/24`, `10.0.11.0/24`
- Database Subnets: `10.0.20.0/24`, `10.0.21.0/24`

## 🏗️ Architecture Components

### Network Layer
- **VPC**: Isolated network environment with custom CIDR
- **Subnets**: Multi-AZ setup with public, private, and database tiers
- **Internet Gateway**: Outbound internet access for public subnets
- **NAT Gateway**: Secure outbound access for private resources
- **Route Tables**: Proper routing configuration for each subnet tier

### Security Layer
- **AWS WAF v2**: Web application firewall with managed rule sets
- **AWS Shield**: DDoS protection service
- **Security Groups**: Stateful firewall rules
- **NACLs**: Additional network-level security
- **IAM Roles**: Service-to-service authentication
- **VPC Flow Logs**: Network traffic monitoring

### Compute Layer
- **Jump Host**: Secure bastion host with WireGuard VPN
- **WordPress Server**: Patient portal on Amazon Linux 2023
- **CRM Server**: Staff management system with containerized application
- **Application Load Balancer**: Layer 7 load balancing with SSL termination

### Data Layer
- **RDS MySQL**: Multi-AZ database with automated backups
- **Secrets Manager**: Secure credential storage and rotation
- **S3 Buckets**: Static asset storage and backup repository

### Content Delivery
- **CloudFront**: Global CDN with edge caching and WAF integration
- **Route 53**: DNS management and health checks
- **ACM**: SSL/TLS certificate management

## 🛡️ WAF Configuration

### WAF Web ACL Rules

#### 1. AWS Managed Rules
```yaml
Core Rule Set (AWSManagedRulesCommonRuleSet):
  - SQL Injection Protection
  - Cross-Site Scripting (XSS) Protection
  - Local File Inclusion (LFI) Protection
  - Remote File Inclusion (RFI) Protection

Known Bad Inputs (AWSManagedRulesKnownBadInputsRuleSet):
  - Known malicious inputs
  - Exploit patterns
  - Vulnerability scanners

Admin Protection (AWSManagedRulesAdminProtectionRuleSet):
  - Admin panel protection
  - Login page protection
  - Administrative interface security
```

#### 2. Custom Rules
```yaml
Rate Limiting Rules:
  - General Rate Limit: 2000 requests per 5 minutes per IP
  - Login Rate Limit: 10 requests per 5 minutes per IP
  - API Rate Limit: 1000 requests per 5 minutes per IP

Geo Blocking Rules:
  - Allow: US, CA, GB, AU, JP, KR, SG
  - Block: High-risk countries (configurable)

IP Reputation Rules:
  - Block known malicious IPs
  - Amazon IP reputation list
  - Custom IP blacklist/whitelist
```

#### 3. Healthcare-Specific Rules
```yaml
HIPAA Compliance Rules:
  - Block requests with potential PHI in URLs
  - Prevent data exfiltration attempts
  - Monitor sensitive data access patterns

Medical Data Protection:
  - Block SQL injection targeting medical records
  - Prevent unauthorized API access
  - Monitor bulk data download attempts
```

### WAF Logging Configuration
```yaml
Log Destination: CloudWatch Logs
Log Group: /aws/wafv2/hospital-waf
Retention: 30 days
Fields Logged:
  - Timestamp
  - Client IP
  - Country
  - URI
  - Action (Allow/Block)
  - Rule matched
  - Request headers
```

## 🔒 Security Implementation

### Network Security
```yaml
Security Groups:
  jump-host-sg:
    Inbound:
      - SSH (22): 0.0.0.0/0
      - WireGuard (51820/UDP): 0.0.0.0/0
      - HTTP (80): 0.0.0.0/0  # WireGuard UI
    
  alb-sg:
    Inbound:
      - HTTP (80): 0.0.0.0/0
      - HTTPS (443): 0.0.0.0/0
    
  wordpress-sg:
    Inbound:
      - SSH (22): jump-host-sg
      - HTTP (80): alb-sg
    
  crm-sg:
    Inbound:
      - SSH (22): jump-host-sg
      - TCP (8080): alb-sg
    
  rds-sg:
    Inbound:
      - MySQL (3306): wordpress-sg, crm-sg, jump-host-sg
```

### IAM Policies
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:hospital/*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## 📖 Deployment Guide

### Phase 1: Network Infrastructure (30 minutes)

#### 1.1 Create VPC and Subnets
1. **Navigate to VPC Console**
   - AWS Console → Services → VPC
   - Click "Create VPC"
   - Select "VPC and more"

2. **VPC Configuration**
   ```yaml
   Name: Hospital-VPC
   IPv4 CIDR: 10.0.0.0/16
   Number of AZs: 2
   Public subnets: 2
   Private subnets: 2
   NAT gateways: In 1 AZ
   VPC endpoints: None
   ```

3. **Additional Database Subnets**
   - Create `DB-Subnet-1A` (10.0.20.0/24) in us-east-1a
   - Create `DB-Subnet-1B` (10.0.21.0/24) in us-east-1b

### Phase 2: WAF Setup (20 minutes)

#### 2.1 Create WAF Web ACL
1. **Navigate to WAF Console**
   - AWS Console → Services → WAF & Shield
   - Click "Create web ACL"

2. **Basic Configuration**
   ```yaml
   Name: Hospital-WAF
   Resource type: CloudFront distributions
   Region: Global (CloudFront)
   ```

3. **Add Managed Rules**
   ```yaml
   Rules to Add:
     - AWS-AWSManagedRulesCommonRuleSet
     - AWS-AWSManagedRulesKnownBadInputsRuleSet
     - AWS-AWSManagedRulesAdminProtectionRuleSet
     - AWS-AWSManagedRulesSQLiRuleSet
   ```

4. **Custom Rate Limiting Rule**
   ```yaml
   Rule Name: RateLimitRule
   Type: Rate-based rule
   Rate limit: 2000 requests per 5 minutes
   Scope: IP address
   Action: Block
   ```

5. **Geo Blocking Rule**
   ```yaml
   Rule Name: GeoBlockRule
   Type: Regular rule
   Statement: Geographic match
   Countries to block: [Configure based on requirements]
   Action: Block
   ```

#### 2.2 Configure WAF Logging
```yaml
Log destination: Amazon CloudWatch Logs
Log group: /aws/wafv2/hospital-waf
Redacted fields: 
  - Authorization header
  - Cookie header
```

### Phase 3: Database Setup (25 minutes)

#### 3.1 Create Secrets Manager Entries
1. **Navigate to Secrets Manager**
   - Create `hospital/rds/master`
   - Create `hospital/wordpress/db`
   - Create `hospital/crm/db`

#### 3.2 Create RDS Instance
```yaml
Engine: MySQL 8.0.35
Instance Class: db.t3.micro (POC) / db.t3.small (Production)
Storage: 20 GiB GP2
Multi-AZ: Yes
Backup Retention: 7 days
Encryption: Enabled
Performance Insights: Enabled
```

### Phase 4: Jump Host and VPN Setup (25 minutes)

#### 4.1 Launch Jump Host
```yaml
AMI: Ubuntu Server 24.04 LTS
Instance Type: t3.micro
Subnet: Public-Subnet-1A
Security Group: jump-host-sg
Public IP: Enable
```

#### 4.2 Install WireGuard VPN
```bash
# Connect to Jump Host
ssh -i hospital-key.pem ubuntu@JUMP_HOST_IP

# Run WireGuard setup
curl -sSL https://raw.githubusercontent.com/vanhoangkha/Review-Architecture/main/scripts/wireguard-setup.sh | bash
```

### Phase 5: Application Servers (30 minutes)

#### 5.1 Create IAM Role
```yaml
Role Name: EC2-SecretsManager-Role
Trust Policy: EC2 Service
Policies:
  - Custom SecretsManagerAccess
  - CloudWatchAgentServerPolicy
```

#### 5.2 Launch WordPress Server
```yaml
AMI: Amazon Linux 2023
Instance Type: t3.medium
Subnet: Private-Subnet-1A
Security Group: wordpress-sg
IAM Role: EC2-SecretsManager-Role
User Data: wordpress-userdata.sh
```

#### 5.3 Launch CRM Server
```yaml
AMI: Amazon Linux 2023
Instance Type: t3.medium
Subnet: Private-Subnet-1A
Security Group: crm-sg
IAM Role: EC2-SecretsManager-Role
User Data: crm-userdata.sh
```

### Phase 6: Load Balancer Configuration (20 minutes)

#### 6.1 Create Application Load Balancer
```yaml
Name: hospital-alb
Scheme: Internet-facing
VPC: Hospital-VPC
Subnets: Both public subnets
Security Group: alb-sg
```

#### 6.2 Create Target Groups
```yaml
WordPress Target Group:
  Name: wordpress-tg
  Protocol: HTTP, Port: 80
  Health Check: /

CRM Target Group:
  Name: crm-tg
  Protocol: HTTP, Port: 8080
  Health Check: /health
```

### Phase 7: SSL Certificate and CloudFront (25 minutes)

#### 7.1 Request SSL Certificate
```yaml
Certificate Manager (us-east-1):
  Domain Names:
    - hospital.com
    - www.hospital.com
    - crm.hospital.com
  Validation: DNS
```

#### 7.2 Create CloudFront Distribution
```yaml
Origin: ALB DNS name
Behaviors:
  Default: CachingDisabled
  /wp-content/*: CachingOptimized
  /crm/*: CachingDisabled

WAF Integration:
  Web ACL: Hospital-WAF
  
Settings:
  Alternate Domain Names: Your domains
  SSL Certificate: Your ACM certificate
```

## ⚙️ Configuration Management

### Environment Variables
```bash
# Application Configuration
export DB_HOST="hospital-db.xxxxxx.us-east-1.rds.amazonaws.com"
export DB_NAME="wordpress_db"
export WAF_WEB_ACL_ID="arn:aws:wafv2:us-east-1:account:global/webacl/hospital-waf/id"
```

### WordPress Security Configuration
```php
// wp-config.php security enhancements
define('FORCE_SSL_ADMIN', true);
define('DISALLOW_FILE_EDIT', true);
define('WP_DEBUG', false);

// Security headers
if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
    $_SERVER['HTTPS'] = 'on';
}

// Rate limiting for login attempts
add_action('wp_login_failed', 'hospital_login_failed');
function hospital_login_failed($username) {
    // Log failed attempts for WAF analysis
    error_log("Failed login attempt for user: " . $username . " from IP: " . $_SERVER['REMOTE_ADDR']);
}
```

### CRM Security Configuration
```python
# config.py
import os
from dataclasses import dataclass

@dataclass
class SecurityConfig:
    MAX_LOGIN_ATTEMPTS: int = 5
    LOGIN_TIMEOUT: int = 300  # 5 minutes
    SESSION_TIMEOUT: int = 1800  # 30 minutes
    REQUIRE_HTTPS: bool = True
    CSRF_PROTECTION: bool = True
```

## 📊 Monitoring & Logging

### CloudWatch Metrics
```yaml
Custom Metrics:
  Application:
    - WordPress Response Time
    - CRM API Response Time
    - Database Connection Count
    - Active User Sessions
  
  Security:
    - WAF Blocked Requests
    - Failed Login Attempts
    - VPN Connection Count
    - Unusual Traffic Patterns
  
  Infrastructure:
    - EC2 CPU Utilization
    - Memory Usage
    - Disk I/O
    - Network Traffic
```

### WAF Monitoring Dashboard
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/WAFV2", "AllowedRequests", "WebACL", "Hospital-WAF"],
          ["AWS/WAFV2", "BlockedRequests", "WebACL", "Hospital-WAF"],
          ["AWS/WAFV2", "SampledRequests", "WebACL", "Hospital-WAF"]
        ],
        "period": 300,
        "stat": "Sum",
        "region": "us-east-1",
        "title": "WAF Request Statistics"
      }
    }
  ]
}
```

### Security Alarms
```yaml
Critical Alarms:
  - WAF Blocked Requests > 100/5min
  - Failed Login Attempts > 50/5min
  - Database Connection Errors
  - Unusual Geographic Access Patterns
  
Warning Alarms:
  - WAF Blocked Requests > 50/5min
  - High Request Rate from Single IP
  - Multiple Failed VPN Attempts
```

## 🔄 Backup & Disaster Recovery

### RDS Backup Strategy
```yaml
Automated Backups:
  Retention Period: 7 days
  Backup Window: 03:00-04:00 UTC
  Maintenance Window: Sun 04:00-05:00 UTC
  
Manual Snapshots:
  Frequency: Weekly
  Retention: 30 days
  Cross-Region Copy: Enabled
```

### WAF Configuration Backup
```yaml
WAF Backup Strategy:
  - Export WAF rules monthly
  - Store configurations in S3
  - Version control WAF changes
  - Document rule modifications
```

## 💰 Cost Optimization

### WAF Cost Management
```yaml
WAF Pricing Optimization:
  - Monitor WCU (Web ACL Capacity Units) usage
  - Optimize rule complexity
  - Use managed rules efficiently
  - Regular rule performance review

Estimated Monthly Costs:
  WAF Web ACL: $1.00
  WAF Rules: $1.00 per rule
  WAF Requests: $0.60 per million requests
  WAF Logging: CloudWatch Logs pricing
```

### Resource Right-Sizing
```yaml
Current Configuration (POC):
  EC2 Instances: t3.micro/t3.medium
  RDS Instance: db.t3.micro
  NAT Gateway: Single AZ
  WAF: Basic rule set
  
Production Recommendations:
  EC2 Instances: t3.large with Reserved Instances
  RDS Instance: db.t3.small Multi-AZ
  NAT Gateway: Multi-AZ for HA
  WAF: Enhanced rule set with rate limiting
```

## 🔧 Troubleshooting

### WAF Issues

#### 1. Legitimate Traffic Blocked
```yaml
Problem: WAF blocking legitimate users
Solutions:
  - Review WAF logs in CloudWatch
  - Check rate limiting thresholds
  - Analyze blocked request patterns
  - Adjust rule sensitivity
  - Add IP whitelist if needed
```

#### 2. High False Positive Rate
```yaml
Problem: Too many false positives
Solutions:
  - Fine-tune managed rules
  - Create exception rules
  - Adjust rule priorities
  - Monitor and iterate
```

### Security Monitoring
```bash
# Check WAF logs
aws logs filter-log-events \
  --log-group-name /aws/wafv2/hospital-waf \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern '{ $.action = "BLOCK" }'

# Monitor blocked requests by country
aws logs filter-log-events \
  --log-group-name /aws/wafv2/hospital-waf \
  --filter-pattern '{ $.httpRequest.country != "US" && $.action = "BLOCK" }'
```

### Performance Optimization
```yaml
WAF Performance:
  - Monitor WCU usage
  - Optimize rule order
  - Use efficient rule conditions
  - Regular performance reviews

Application Performance:
  - Monitor response times
  - Optimize database queries
  - Configure appropriate caching
  - Use CloudFront effectively
```

## 🏥 Healthcare Compliance

### HIPAA Considerations
```yaml
Technical Safeguards:
  - Data encryption at rest and in transit
  - Access controls and authentication
  - Audit logs and monitoring
  - Automatic logoff mechanisms

Administrative Safeguards:
  - Security officer designation
  - Workforce training
  - Access management procedures
  - Incident response procedures

Physical Safeguards:
  - Facility access controls
  - Workstation use restrictions
  - Device and media controls
```

### Audit Trail Requirements
```yaml
Required Logging:
  - All data access attempts
  - User authentication events
  - Administrative actions
  - System configuration changes
  - Security incidents

Log Retention:
  - Minimum 6 years for HIPAA
  - Secure storage in S3
  - Encrypted log files
  - Access controls on logs
```

## 📚 Additional Resources

### AWS Documentation
- [AWS WAF Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/)
- [AWS Shield Advanced Guide](https://docs.aws.amazon.com/waf/latest/developerguide/shield-chapter.html)
- [CloudFront Security](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/SecurityAndPrivacy.html)

### Security Best Practices
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:
- Create an issue in this repository
- Contact the DevOps team: devops@hospital.com
- AWS Support (for AWS-related issues)

---

**⚠️ Important Security Notice**

This infrastructure setup follows AWS security best practices and includes WAF protection, but should be reviewed and customized for your specific security requirements before production deployment. Regular security audits and WAF rule updates are recommended.

**🏥 Healthcare Compliance**

If deploying for actual healthcare use, ensure compliance with relevant regulations such as HIPAA, GDPR, or local healthcare data protection laws. Additional security measures, audit trails, and WAF rules may be required.

---

*Last Updated: 2024-06-18*
*Version: 2.0.0*
*Maintained by: Hospital DevOps Team*
