# Hospital Infrastructure Setup - Phần 2

Tiếp tục từ Bước 5 đến Bước 12

## 🖥️ Bước 5: Tạo Jump Host và VPN

### 5.1 Tạo Key Pair

1. **Tạo EC2 Key Pair**
   - EC2 Console → Key Pairs → Create key pair
   ```
   Name: hospital-key
   Key pair type: RSA
   Private key file format: .pem
   ```
   - Click "Create key pair"
   - **Lưu file .pem an toàn**

### 5.2 Tạo Jump Host Security Group

1. **Tạo Security Group**
   - EC2 → Security Groups → Create security group
   ```
   Security group name: hospital-jump-host-sg
   Description: Jump host security group for VPN access
   VPC: Hospital-vpc
   ```

2. **Inbound Rules**
   ```
   Rule 1:
   Type: SSH
   Protocol: TCP
   Port: 22
   Source: 0.0.0.0/0
   Description: SSH access
   
   Rule 2:
   Type: Custom UDP
   Protocol: UDP
   Port: 51820
   Source: 0.0.0.0/0
   Description: WireGuard VPN
   
   Rule 3:
   Type: HTTP
   Protocol: TCP
   Port: 80
   Source: 0.0.0.0/0
   Description: WireGuard UI
   ```

### 5.3 Launch Jump Host

1. **Launch Instance**
   - EC2 → Instances → Launch instances
   ```
   Name: Hospital-Jump-Host
   
   Application and OS Images:
   AMI: Ubuntu Server 24.04 LTS
   Architecture: 64-bit (x86)
   
   Instance type: t3.micro
   
   Key pair: hospital-key
   ```

2. **Network Settings**
   ```
   VPC: Hospital-vpc
   Subnet: Hospital-subnet-public-us-east-1a
   Auto-assign public IP: Enable
   
   Firewall (security groups): Select existing
   Security groups: hospital-jump-host-sg
   ```

3. **Storage**
   ```
   Root volume: 8 GiB gp3
   ```

4. **Advanced Details**
   ```
   User data: (copy script từ scripts/wireguard-setup.sh)
   ```

5. **Launch Instance**
   - Đợi instance chạy và lấy Public IP

### 5.4 Cấu hình WireGuard VPN

1. **SSH vào Jump Host**
   ```bash
   ssh -i hospital-key.pem ubuntu@JUMP_HOST_PUBLIC_IP
   ```

2. **Chạy WireGuard Setup**
   ```bash
   curl -sSL https://raw.githubusercontent.com/vanhoangkha/Review-Architecture/main/scripts/wireguard-setup.sh | bash
   ```

3. **Truy cập WireGuard UI**
   - Mở browser: `http://JUMP_HOST_PUBLIC_IP`
   - Login: `admin` / `HospitalVPN2024!`

4. **Cấu hình Server**
   - Post Up Script:
     ```bash
     iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
     ```
   - Post Down Script:
     ```bash
     iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
     ```
   - DNS Server: `10.0.0.2`

## 🖥️ Bước 6: Tạo Application Servers

### 6.1 Tạo IAM Role cho EC2

1. **Tạo IAM Role**
   - IAM Console → Roles → Create role
   ```
   Trusted entity type: AWS service
   Service: EC2
   ```

2. **Tạo Custom Policy**
   - Click "Create policy"
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "secretsmanager:GetSecretValue",
           "secretsmanager:DescribeSecret"
         ],
         "Resource": [
           "arn:aws:secretsmanager:us-east-1:*:secret:hospital/*"
         ]
       },
       {
         "Effect": "Allow",
         "Action": [
           "kms:Decrypt",
           "kms:DescribeKey"
         ],
         "Resource": [
           "arn:aws:kms:us-east-1:*:key/*"
         ]
       },
       {
         "Effect": "Allow",
         "Action": [
           "logs:CreateLogGroup",
           "logs:CreateLogStream",
           "logs:PutLogEvents"
         ],
         "Resource": "*"
       }
     ]
   }
   ```
   - Policy name: `HospitalSecretsManagerAccess`

3. **Attach Policy và Create Role**
   ```
   Role name: Hospital-EC2-SecretsManager-Role
   Attach policies:
   - HospitalSecretsManagerAccess
   - CloudWatchAgentServerPolicy (AWS managed)
   ```

### 6.2 Tạo Application Security Groups

1. **WordPress Security Group**
   ```
   Name: hospital-wordpress-sg
   Description: WordPress server security group
   VPC: Hospital-vpc
   
   Inbound Rules:
   - SSH (22) from hospital-jump-host-sg
   - HTTP (80) from ALB security group (tạo sau)
   ```

2. **CRM Security Group**
   ```
   Name: hospital-crm-sg
   Description: CRM server security group
   VPC: Hospital-vpc
   
   Inbound Rules:
   - SSH (22) from hospital-jump-host-sg
   - Custom TCP (8080) from ALB security group (tạo sau)
   ```

### 6.3 Launch WordPress Server

1. **Launch Instance**
   ```
   Name: Hospital-WordPress-Server
   AMI: Amazon Linux 2023
   Instance type: t3.medium
   Key pair: hospital-key
   
   Network:
   VPC: Hospital-vpc
   Subnet: Hospital-subnet-private-us-east-1a
   Auto-assign public IP: Disable
   Security group: hospital-wordpress-sg
   
   IAM instance profile: Hospital-EC2-SecretsManager-Role
   ```

2. **User Data Script**
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y httpd php php-mysql php-gd php-xml php-mbstring php-curl php-zip jq
   
   # Install AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Get database credentials from Secrets Manager
   DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "hospital/wordpress/db" --region us-east-1 --query 'SecretString' --output text)
   DB_HOST=$(echo $DB_SECRET | jq -r '.host')
   DB_NAME=$(echo $DB_SECRET | jq -r '.dbname')
   DB_USER=$(echo $DB_SECRET | jq -r '.username')
   DB_PASS=$(echo $DB_SECRET | jq -r '.password')
   
   # Install WordPress
   cd /var/www/html
   wget https://wordpress.org/latest.tar.gz
   tar -xzf latest.tar.gz
   mv wordpress/* .
   rm -rf wordpress latest.tar.gz
   
   # Configure WordPress
   cp wp-config-sample.php wp-config.php
   sed -i "s/database_name_here/$DB_NAME/" wp-config.php
   sed -i "s/username_here/$DB_USER/" wp-config.php
   sed -i "s/password_here/$DB_PASS/" wp-config.php
   sed -i "s/localhost/$DB_HOST/" wp-config.php
   
   # Security configurations
   cat >> wp-config.php << 'EOF'
   define('FORCE_SSL_ADMIN', true);
   define('DISALLOW_FILE_EDIT', true);
   if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
       $_SERVER['HTTPS'] = 'on';
   }
   EOF
   
   # Set permissions
   chown -R apache:apache /var/www/html
   chmod -R 755 /var/www/html
   
   # Start services
   systemctl start httpd
   systemctl enable httpd
   ```

### 6.4 Launch CRM Server

1. **Launch Instance tương tự**
   ```
   Name: Hospital-CRM-Server
   Security group: hospital-crm-sg
   ```

2. **User Data Script**
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y docker python3 python3-pip jq
   
   # Install AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Start Docker
   systemctl start docker
   systemctl enable docker
   
   # Get database credentials
   DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "hospital/crm/db" --region us-east-1 --query 'SecretString' --output text)
   DB_HOST=$(echo $DB_SECRET | jq -r '.host')
   DB_NAME=$(echo $DB_SECRET | jq -r '.dbname')
   DB_USER=$(echo $DB_SECRET | jq -r '.username')
   DB_PASS=$(echo $DB_SECRET | jq -r '.password')
   
   # Create CRM application
   mkdir -p /opt/crm
   cd /opt/crm
   
   # Install Flask
   pip3 install flask mysql-connector-python
   
   # Create simple CRM app
   cat > app.py << 'PYTHON_EOF'
   from flask import Flask, jsonify
   import os
   
   app = Flask(__name__)
   
   @app.route('/')
   def home():
       return jsonify({
           'message': 'Hospital CRM System',
           'status': 'running',
           'version': '2.0.0'
       })
   
   @app.route('/health')
   def health():
       return jsonify({'status': 'healthy'})
   
   if __name__ == '__main__':
       app.run(host='0.0.0.0', port=8080)
   PYTHON_EOF
   
   # Create systemd service
   cat > /etc/systemd/system/crm-app.service << 'EOF'
   [Unit]
   Description=Hospital CRM Application
   After=network.target
   
   [Service]
   Type=simple
   User=ec2-user
   WorkingDirectory=/opt/crm
   Environment=DB_HOST=$DB_HOST
   Environment=DB_NAME=$DB_NAME
   Environment=DB_USER=$DB_USER
   Environment=DB_PASS=$DB_PASS
   ExecStart=/usr/bin/python3 app.py
   Restart=always
   
   [Install]
   WantedBy=multi-user.target
   EOF
   
   # Start service
   systemctl daemon-reload
   systemctl enable crm-app
   systemctl start crm-app
   ```

## ⚖️ Bước 7: Tạo Application Load Balancer

### 7.1 Tạo ALB Security Group

1. **Tạo Security Group**
   ```
   Name: hospital-alb-sg
   Description: Application Load Balancer security group
   VPC: Hospital-vpc
   
   Inbound Rules:
   - HTTP (80) from 0.0.0.0/0
   - HTTPS (443) from 0.0.0.0/0
   ```

### 7.2 Update Application Security Groups

1. **Update WordPress SG**
   - Edit hospital-wordpress-sg
   - Add rule: HTTP (80) from hospital-alb-sg

2. **Update CRM SG**
   - Edit hospital-crm-sg
   - Add rule: Custom TCP (8080) from hospital-alb-sg

### 7.3 Tạo Target Groups

1. **WordPress Target Group**
   - EC2 → Target Groups → Create target group
   ```
   Target type: Instances
   Target group name: hospital-wordpress-tg
   Protocol: HTTP
   Port: 80
   VPC: Hospital-vpc
   
   Health checks:
   Health check path: /
   Health check interval: 30 seconds
   Healthy threshold: 2
   Unhealthy threshold: 5
   Timeout: 5 seconds
   Success codes: 200
   ```
   - Register WordPress instance

2. **CRM Target Group**
   ```
   Target group name: hospital-crm-tg
   Protocol: HTTP
   Port: 8080
   Health check path: /health
   ```
   - Register CRM instance

### 7.4 Tạo Application Load Balancer

1. **Create Load Balancer**
   - EC2 → Load Balancers → Create load balancer
   - Choose "Application Load Balancer"

2. **Basic Configuration**
   ```
   Load balancer name: hospital-alb
   Scheme: Internet-facing
   IP address type: IPv4
   ```

3. **Network Mapping**
   ```
   VPC: Hospital-vpc
   Mappings:
   - us-east-1a: Hospital-subnet-public-us-east-1a
   - us-east-1b: Hospital-subnet-public-us-east-1b
   ```

4. **Security Groups**
   ```
   Security groups: hospital-alb-sg
   ```

5. **Listeners and Routing**
   ```
   Listener 1:
   Protocol: HTTP
   Port: 80
   Default action: Redirect to HTTPS
   
   Listener 2:
   Protocol: HTTPS
   Port: 443
   Default action: Forward to hospital-wordpress-tg
   ```

6. **Create Load Balancer**
   - Lưu lại ALB DNS name

### 7.5 Thêm Listener Rules

1. **Edit HTTPS Listener**
   - Select HTTPS:443 listener → View/edit rules
   - Add rule:
   ```
   Priority: 100
   Conditions: Host header is crm.hospital.com
   Actions: Forward to hospital-crm-tg
   ```

## 🔐 Bước 8: Tạo SSL Certificate

### 8.1 Request Certificate

1. **Certificate Manager Console**
   - AWS Console → Certificate Manager
   - **Region: us-east-1** (bắt buộc cho CloudFront)
   - Click "Request a certificate"

2. **Certificate Details**
   ```
   Certificate type: Request a public certificate
   
   Domain names:
   - hospital.com
   - www.hospital.com
   - crm.hospital.com
   
   Validation method: DNS validation
   Key algorithm: RSA 2048
   ```

3. **Request Certificate**
   - Click "Request"
   - **Lưu lại Certificate ARN**

### 8.2 Validate Certificate

1. **DNS Validation**
   - Click vào certificate vừa tạo
   - Copy CNAME records cho từng domain
   - Add CNAME records vào DNS provider của domain

2. **Đợi Validation**
   - Đợi status chuyển thành "Issued" (5-30 phút)

### 8.3 Update ALB với SSL Certificate

1. **Edit HTTPS Listener**
   - ALB → Listeners → Edit HTTPS:443
   - Default SSL certificate: Select certificate vừa tạo
   - Save changes

## 🛡️ Bước 9: Tạo WAF Web ACL

### 9.1 Tạo WAF Web ACL

1. **WAF Console**
   - AWS Console → WAF & Shield
   - Click "Create web ACL"

2. **Basic Information**
   ```
   Name: Hospital-WAF
   Description: WAF for Hospital Management System
   CloudWatch metric name: HospitalWAF
   Resource type: CloudFront distributions
   Region: Global (CloudFront)
   ```

### 9.2 Add Managed Rules

1. **AWS Managed Rules - Core Rule Set**
   ```
   Rule group: AWS-AWSManagedRulesCommonRuleSet
   Name: CommonRuleSet
   Priority: 1
   Action: Block
   ```

2. **AWS Managed Rules - Known Bad Inputs**
   ```
   Rule group: AWS-AWSManagedRulesKnownBadInputsRuleSet
   Name: KnownBadInputs
   Priority: 2
   Action: Block
   ```

3. **AWS Managed Rules - SQL Injection**
   ```
   Rule group: AWS-AWSManagedRulesSQLiRuleSet
   Name: SQLiProtection
   Priority: 3
   Action: Block
   ```

### 9.3 Add Custom Rules

1. **Rate Limiting Rule**
   ```
   Rule type: Rate-based rule
   Name: GeneralRateLimit
   Priority: 10
   
   Rate limit: 2000 requests per 5 minutes
   Scope: IP address
   Action: Block
   ```

2. **Login Rate Limiting**
   ```
   Rule type: Rate-based rule
   Name: LoginRateLimit
   Priority: 11
   
   Rate limit: 10 requests per 5 minutes
   Scope: IP address
   
   Statement:
   Field to match: URI path
   Match type: Contains string
   String to match: wp-login.php
   
   Action: Block
   ```

3. **Geo Blocking Rule**
   ```
   Rule type: Regular rule
   Name: GeoBlocking
   Priority: 20
   
   Statement:
   Geographic match
   Country codes: CN, RU, KP, IR (thêm theo nhu cầu)
   
   Action: Block
   ```

### 9.4 Configure Logging

1. **Enable Logging**
   ```
   Log destination: Amazon CloudWatch Logs
   Log group: /aws/wafv2/hospital-waf
   
   Redacted fields:
   - authorization (request header)
   - cookie (request header)
   ```

2. **Create Web ACL**
   - Review và click "Create web ACL"
   - **Lưu lại Web ACL ARN**

## 🌐 Bước 10: Tạo CloudFront Distribution

### 10.1 Create Distribution

1. **CloudFront Console**
   - AWS Console → CloudFront
   - Click "Create distribution"

2. **Origin Settings**
   ```
   Origin domain: hospital-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com
   Protocol: HTTPS only
   Origin path: (để trống)
   
   Origin request policy: AllViewer
   ```

3. **Default Cache Behavior**
   ```
   Path pattern: Default (*)
   Viewer protocol policy: Redirect HTTP to HTTPS
   Allowed HTTP methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
   Cache policy: CachingDisabled (cho dynamic content)
   Origin request policy: AllViewer
   ```

4. **Additional Behaviors**
   - Add behavior:
   ```
   Path pattern: /wp-content/*
   Cache policy: CachingOptimized
   Origin request policy: None
   ```

5. **Settings**
   ```
   Alternate domain names (CNAME):
   - hospital.com
   - www.hospital.com
   - crm.hospital.com
   
   Custom SSL certificate: Select certificate đã tạo
   
   Web Application Firewall (WAF): Enable
   WAF Web ACL: Hospital-WAF
   
   Default root object: index.php
   ```

6. **Create Distribution**
   - Đợi 15-20 phút để deploy
   - **Lưu lại CloudFront domain name**

## 🌍 Bước 11: Cấu hình DNS

### 11.1 Create Route 53 Records

1. **Route 53 Console**
   - AWS Console → Route 53
   - Hosted zones → Select your domain

2. **Create A Records**
   ```
   Record 1:
   Name: hospital.com
   Type: A
   Alias: Yes
   Route traffic to: CloudFront distribution
   Distribution: Select Hospital distribution
   
   Record 2:
   Name: www.hospital.com
   Type: A
   Alias: Yes
   Route traffic to: CloudFront distribution
   
   Record 3:
   Name: crm.hospital.com
   Type: A
   Alias: Yes
   Route traffic to: CloudFront distribution
   ```

## 🧪 Bước 12: Testing và Monitoring

### 12.1 Test Applications

1. **Test WordPress**
   ```
   URL: https://www.hospital.com
   Expected: WordPress installation page
   ```

2. **Test CRM**
   ```
   URL: https://crm.hospital.com
   Expected: CRM JSON response
   ```

3. **Test WAF**
   ```bash
   # Test SQL injection (should be blocked)
   curl "https://hospital.com/?id=1' OR '1'='1"
   
   # Test rate limiting
   for i in {1..100}; do curl https://hospital.com/wp-login.php; done
   ```

### 12.2 Setup Monitoring

1. **CloudWatch Alarms**
   ```
   Alarm 1: ALB-HighLatency
   Metric: TargetResponseTime > 2 seconds
   
   Alarm 2: WAF-HighBlockRate
   Metric: BlockedRequests > 100 per 5 minutes
   
   Alarm 3: RDS-HighCPU
   Metric: CPUUtilization > 80%
   ```

2. **SNS Notifications**
   ```
   Topic: hospital-alerts
   Subscriptions: your-email@domain.com
   ```

### 12.3 Verify Security

1. **Check Encryption**
   - RDS: Verify encryption enabled
   - Secrets: Verify KMS encryption
   - SSL: Test HTTPS certificates

2. **Check WAF Logs**
   ```
   CloudWatch Logs → /aws/wafv2/hospital-waf
   Filter: action = "BLOCK"
   ```

3. **Security Scan**
   - Use tools like OWASP ZAP
   - Test common vulnerabilities
   - Verify WAF blocking

---

## ✅ Hoàn thành!

Hệ thống Hospital Management đã được setup hoàn chỉnh với:

- ✅ KMS encryption cho RDS và Secrets
- ✅ MySQL RDS với Multi-AZ
- ✅ Secrets Manager cho credentials
- ✅ WAF protection trước CloudFront
- ✅ SSL/TLS certificates
- ✅ VPN access cho admin
- ✅ Monitoring và logging

**Truy cập hệ thống:**
- WordPress: https://www.hospital.com
- CRM: https://crm.hospital.com
- VPN UI: http://JUMP_HOST_IP

**Bảo mật:**
- Tất cả traffic được bảo vệ bởi WAF
- Database được mã hóa bằng KMS
- Credentials được lưu trong Secrets Manager
- Admin access chỉ qua VPN
