# AWS KMS Default Keys - Hướng dẫn sử dụng

## 🔐 Tổng quan về KMS Default Keys

AWS cung cấp sẵn các AWS managed keys (default keys) cho từng service, giúp đơn giản hóa việc encryption mà không cần tạo custom keys.

## 📋 Danh sách Default Keys cho Hospital System

### 1. RDS Default Key
```
Key Alias: alias/aws/rds
Key ID: Tự động tạo bởi AWS
Description: Default key for Amazon RDS
Cost: Miễn phí (AWS managed)
Usage: RDS instance encryption, snapshots, backups
```

### 2. Secrets Manager Default Key
```
Key Alias: alias/aws/secretsmanager
Key ID: Tự động tạo bởi AWS
Description: Default key for AWS Secrets Manager
Cost: Miễn phí (AWS managed)
Usage: Secrets encryption at rest
```

### 3. CloudWatch Logs Default Key
```
Key Alias: alias/aws/logs
Key ID: Tự động tạo bởi AWS
Description: Default key for CloudWatch Logs
Cost: Miễn phí (AWS managed)
Usage: Log group encryption
```

## ✅ Ưu điểm của Default Keys

### 1. **Chi phí**
- Hoàn toàn miễn phí
- Không tính phí key usage
- Không tính phí API calls

### 2. **Quản lý**
- AWS tự động quản lý key rotation
- Không cần setup permissions phức tạp
- Tự động có sẵn trong mọi region

### 3. **Bảo mật**
- Được AWS quản lý và bảo vệ
- Tuân thủ compliance standards
- Automatic key rotation

## ⚠️ Hạn chế của Default Keys

### 1. **Kiểm soát**
- Không thể xóa hoặc disable
- Không thể thay đổi key policy
- Không thể cross-account access

### 2. **Audit**
- Ít thông tin trong CloudTrail
- Không thể track usage chi tiết
- Không thể set custom permissions

## 🔧 Cách sử dụng Default Keys

### 1. RDS Encryption
```yaml
# Khi tạo RDS instance
Encryption: Enable
KMS Key: (default) aws/rds

# Hoặc trong Console
Storage encryption: ✅ Enable encryption
AWS KMS key: (default) aws/rds
```

### 2. Secrets Manager Encryption
```yaml
# Khi tạo secret
Encryption key: (default) aws/secretsmanager

# Hoặc trong Console
Select encryption key: DefaultEncryptionKey
```

### 3. CloudWatch Logs Encryption
```yaml
# Khi tạo log group
Encryption: Enable
KMS Key: (default) aws/logs
```

## 🔍 Kiểm tra Default Keys

### 1. Qua AWS Console
```
1. AWS Console → KMS
2. Customer managed keys → AWS managed keys
3. Tìm keys với alias:
   - aws/rds
   - aws/secretsmanager
   - aws/logs
```

### 2. Qua AWS CLI
```bash
# List all AWS managed keys
aws kms list-keys --query 'Keys[?KeyManager==`AWS`]'

# Get specific key info
aws kms describe-key --key-id alias/aws/rds
aws kms describe-key --key-id alias/aws/secretsmanager
```

## 📊 So sánh Default vs Custom Keys

| Tính năng | Default Keys | Custom Keys |
|-----------|--------------|-------------|
| **Chi phí** | Miễn phí | $1/tháng + usage |
| **Quản lý** | AWS managed | User managed |
| **Rotation** | Tự động | Tùy chọn |
| **Cross-account** | Không | Có |
| **Custom policy** | Không | Có |
| **Audit detail** | Cơ bản | Chi tiết |
| **Compliance** | AWS standard | Custom control |

## 🏥 Khuyến nghị cho Hospital System

### Sử dụng Default Keys khi:
- ✅ Môi trường development/testing
- ✅ Cần setup nhanh và đơn giản
- ✅ Không có yêu cầu compliance đặc biệt
- ✅ Muốn tiết kiệm chi phí
- ✅ Không cần cross-account access

### Sử dụng Custom Keys khi:
- ❌ Môi trường production với yêu cầu cao
- ❌ Cần compliance audit chi tiết
- ❌ Cần cross-account resource sharing
- ❌ Cần custom key policies
- ❌ Yêu cầu key rotation tùy chỉnh

## 🔐 Security Best Practices với Default Keys

### 1. IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "kms:ViaService": [
            "rds.us-east-1.amazonaws.com",
            "secretsmanager.us-east-1.amazonaws.com"
          ]
        }
      }
    }
  ]
}
```

### 2. Service-specific Access
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": [
    "arn:aws:kms:*:*:key/*"
  ],
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "secretsmanager.us-east-1.amazonaws.com"
    }
  }
}
```

## 📝 Cấu hình trong Hospital System

### 1. RDS MySQL
```yaml
# Sử dụng default key cho RDS
Encryption: ✅ Enable
KMS Key: (default) aws/rds

# Tự động encrypt:
- Database instance
- Automated backups
- Read replicas
- Snapshots
```

### 2. Secrets Manager
```yaml
# Tất cả secrets sử dụng default key
hospital/rds/master: aws/secretsmanager
hospital/wordpress/db: aws/secretsmanager
hospital/crm/db: aws/secretsmanager
```

### 3. Application Logs
```yaml
# CloudWatch log groups
/aws/ec2/wordpress: aws/logs
/aws/ec2/crm: aws/logs
/aws/wafv2/hospital-waf: aws/logs
```

## 🔄 Migration từ Custom Keys

Nếu đã sử dụng custom keys và muốn chuyển sang default keys:

### 1. RDS Migration
```bash
# Tạo snapshot với custom key
aws rds create-db-snapshot \
  --db-instance-identifier hospital-db \
  --db-snapshot-identifier hospital-db-snapshot

# Copy snapshot với default key
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier hospital-db-snapshot \
  --target-db-snapshot-identifier hospital-db-default-key \
  --kms-key-id alias/aws/rds

# Restore từ snapshot mới
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier hospital-db-new \
  --db-snapshot-identifier hospital-db-default-key
```

### 2. Secrets Migration
```bash
# Get current secret value
SECRET_VALUE=$(aws secretsmanager get-secret-value \
  --secret-id hospital/rds/master \
  --query 'SecretString' --output text)

# Create new secret with default key
aws secretsmanager create-secret \
  --name hospital/rds/master-new \
  --secret-string "$SECRET_VALUE"
  # Default key sẽ được sử dụng tự động
```

## 📈 Monitoring Default Key Usage

### 1. CloudTrail Events
```json
{
  "eventSource": "kms.amazonaws.com",
  "eventName": "Decrypt",
  "resources": [
    {
      "ARN": "arn:aws:kms:us-east-1:account:key/aws-managed-key-id",
      "type": "AWS::KMS::Key"
    }
  ],
  "requestParameters": {
    "keyId": "alias/aws/rds"
  }
}
```

### 2. CloudWatch Metrics
```yaml
# KMS key usage metrics
Namespace: AWS/KMS
Metrics:
  - NumberOfRequestsSucceeded
  - NumberOfRequestsFailed
Dimensions:
  - KeyId: aws-managed-key-id
```

## 🎯 Kết luận

Đối với Hospital Management System:

**✅ Khuyến nghị sử dụng Default Keys vì:**
- Đơn giản setup và maintenance
- Miễn phí hoàn toàn
- Đáp ứng đủ yêu cầu bảo mật cơ bản
- AWS managed và highly available
- Phù hợp cho POC và production nhỏ

**🔄 Có thể upgrade lên Custom Keys sau khi:**
- Hệ thống scale lớn
- Cần compliance audit chi tiết
- Yêu cầu cross-account access
- Cần custom key policies

---

*Tài liệu này giúp bạn hiểu rõ về việc sử dụng KMS default keys trong Hospital Management System một cách hiệu quả và an toàn.*
