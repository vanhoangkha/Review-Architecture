#!/bin/bash

# WordPress Server User Data Script with WAF Integration
# This script sets up WordPress on Amazon Linux 2023 with Secrets Manager integration

# Update system
yum update -y

# Install required packages
yum install -y httpd php php-mysql php-gd php-xml php-mbstring php-curl php-zip jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Get database credentials from Secrets Manager
echo "Retrieving database credentials from Secrets Manager..."
DB_SECRET=$(aws secretsmanager get-secret-value --secret-id "hospital/wordpress/db" --region us-east-1 --query 'SecretString' --output text)

if [ $? -eq 0 ]; then
    DB_HOST=$(echo $DB_SECRET | jq -r '.host')
    DB_NAME=$(echo $DB_SECRET | jq -r '.dbname')
    DB_USER=$(echo $DB_SECRET | jq -r '.username')
    DB_PASS=$(echo $DB_SECRET | jq -r '.password')
    
    echo "Database credentials retrieved successfully"
else
    echo "Failed to retrieve database credentials"
    exit 1
fi

# Download and install WordPress
echo "Installing WordPress..."
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rm -rf wordpress latest.tar.gz

# Configure WordPress
echo "Configuring WordPress..."
cp wp-config-sample.php wp-config.php

# Replace database configuration
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php
sed -i "s/localhost/$DB_HOST/" wp-config.php

# Add security configurations
cat >> wp-config.php << 'EOF'

// Security Keys - Generate new ones from https://api.wordpress.org/secret-key/1.1/salt/
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

// WordPress debugging
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', false);

// Security configurations
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', true);
define('WP_POST_REVISIONS', 3);
define('AUTOSAVE_INTERVAL', 300);

// Force SSL for CloudFront
if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
    $_SERVER['HTTPS'] = 'on';
}

// WAF-friendly configurations
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');
EOF

# Create security-focused .htaccess
cat > .htaccess << 'EOF'
# Security Headers for WAF compatibility
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' https:; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';"
</IfModule>

# WordPress security rules
<Files wp-config.php>
    order allow,deny
    deny from all
</Files>

<Files .htaccess>
    order allow,deny
    deny from all
</Files>

# Prevent access to sensitive files
<FilesMatch "\.(htaccess|htpasswd|ini|log|sh|inc|bak)$">
    Order Allow,Deny
    Deny from all
</FilesMatch>

# WordPress rewrite rules
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
    
    # Block suspicious requests
    RewriteCond %{QUERY_STRING} (\<|%3C).*script.*(\>|%3E) [NC,OR]
    RewriteCond %{QUERY_STRING} GLOBALS(=|\[|\%[0-9A-Z]{0,2}) [OR]
    RewriteCond %{QUERY_STRING} _REQUEST(=|\[|\%[0-9A-Z]{0,2}) [OR]
    RewriteCond %{QUERY_STRING} proc/self/environ [OR]
    RewriteCond %{QUERY_STRING} mosConfig_[a-zA-Z_]{1,21}(=|\%3D) [OR]
    RewriteCond %{QUERY_STRING} base64_(en|de)code\(.*\) [OR]
    RewriteCond %{QUERY_STRING} (\<|%3C).*iframe.*(\>|%3E) [NC]
    RewriteRule ^(.*)$ - [F,L]
</IfModule>

# Rate limiting headers for WAF
<IfModule mod_evasive24.c>
    DOSHashTableSize    2048
    DOSPageCount        10
    DOSSiteCount        50
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   600
</IfModule>
EOF

# Set proper permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
find /var/www/html -type f -exec chmod 644 {} \;

# Configure Apache with security headers
echo "Configuring Apache..."
cat > /etc/httpd/conf.d/wordpress.conf << 'EOF'
<Directory "/var/www/html">
    AllowOverride All
    Options -Indexes -ExecCGI
    DirectoryIndex index.php index.html
</Directory>

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
Header always set Referrer-Policy "strict-origin-when-cross-origin"

# Hide server information
ServerTokens Prod
ServerSignature Off

# Disable unnecessary modules
LoadModule rewrite_module modules/mod_rewrite.so
LoadModule headers_module modules/mod_headers.so

# Security configurations
<IfModule mod_security.c>
    SecRuleEngine On
    SecRequestBodyAccess On
    SecResponseBodyAccess Off
    SecRequestBodyLimit 13107200
    SecRequestBodyNoFilesLimit 131072
    SecRequestBodyInMemoryLimit 131072
    SecRequestBodyLimitAction Reject
    SecPcreMatchLimit 1000
    SecPcreMatchLimitRecursion 1000
</IfModule>

# Rate limiting
<IfModule mod_evasive24.c>
    DOSHashTableSize    2048
    DOSPageCount        10
    DOSSiteCount        50
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   600
    DOSLogDir           /var/log/httpd
    DOSEmailNotify      admin@hospital.com
</IfModule>
EOF

# Install security plugins via WP-CLI
echo "Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/wp-cli/v2.8.1/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Create WordPress security configuration
cat > /var/www/html/wp-security-config.php << 'EOF'
<?php
// Additional security configurations for WordPress

// Disable XML-RPC
add_filter('xmlrpc_enabled', '__return_false');

// Remove WordPress version from head
remove_action('wp_head', 'wp_generator');

// Disable file editing
define('DISALLOW_FILE_EDIT', true);

// Hide login errors
add_filter('login_errors', function($error) {
    return 'Invalid credentials.';
});

// Limit login attempts
add_action('wp_login_failed', 'hospital_login_failed');
function hospital_login_failed($username) {
    $ip = $_SERVER['REMOTE_ADDR'];
    $attempts = get_transient('failed_login_' . $ip);
    
    if (!$attempts) {
        $attempts = 0;
    }
    
    $attempts++;
    set_transient('failed_login_' . $ip, $attempts, 300); // 5 minutes
    
    // Log for WAF analysis
    error_log("Failed login attempt #$attempts for user: $username from IP: $ip");
    
    if ($attempts >= 5) {
        error_log("IP $ip blocked due to excessive failed login attempts");
        wp_die('Too many failed login attempts. Please try again later.');
    }
}

// Check for blocked IPs
add_action('init', 'hospital_check_blocked_ip');
function hospital_check_blocked_ip() {
    $ip = $_SERVER['REMOTE_ADDR'];
    $attempts = get_transient('failed_login_' . $ip);
    
    if ($attempts && $attempts >= 5) {
        wp_die('Access denied. Your IP has been temporarily blocked.');
    }
}

// Security headers
add_action('send_headers', 'hospital_security_headers');
function hospital_security_headers() {
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
    header('X-XSS-Protection: 1; mode=block');
    header('Referrer-Policy: strict-origin-when-cross-origin');
}

// Disable pingbacks
add_filter('wp_headers', 'hospital_disable_pingbacks');
function hospital_disable_pingbacks($headers) {
    if (isset($headers['X-Pingback'])) {
        unset($headers['X-Pingback']);
    }
    return $headers;
}
?>
EOF

# Include security config in wp-config.php
echo "require_once(ABSPATH . 'wp-security-config.php');" >> wp-config.php

# Start and enable services
echo "Starting services..."
systemctl start httpd
systemctl enable httpd

# Install CloudWatch agent
echo "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm
rm -f amazon-cloudwatch-agent.rpm

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/wordpress/access",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/aws/ec2/wordpress/error",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/www/html/wp-content/debug.log",
                        "log_group_name": "/aws/ec2/wordpress/debug",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "Hospital/WordPress",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create health check endpoint
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');
header('Cache-Control: no-cache, must-revalidate');

$health = array(
    'status' => 'healthy',
    'timestamp' => date('c'),
    'service' => 'wordpress',
    'version' => '1.0.0'
);

// Check database connection
try {
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME, DB_USER, DB_PASSWORD);
    $health['database'] = 'connected';
    $health['db_server_info'] = $pdo->getAttribute(PDO::ATTR_SERVER_INFO);
} catch (PDOException $e) {
    $health['database'] = 'disconnected';
    $health['status'] = 'unhealthy';
    $health['error'] = 'Database connection failed';
}

// Check disk space
$disk_free = disk_free_space('/');
$disk_total = disk_total_space('/');
$disk_used_percent = (($disk_total - $disk_free) / $disk_total) * 100;

$health['disk_usage'] = array(
    'used_percent' => round($disk_used_percent, 2),
    'free_bytes' => $disk_free,
    'total_bytes' => $disk_total
);

// Check memory usage
$memory_info = array();
if (function_exists('memory_get_usage')) {
    $memory_info['current_usage'] = memory_get_usage(true);
    $memory_info['peak_usage'] = memory_get_peak_usage(true);
}
$health['memory'] = $memory_info;

// Overall health status
if ($disk_used_percent > 90) {
    $health['status'] = 'warning';
    $health['warnings'][] = 'Disk usage above 90%';
}

echo json_encode($health, JSON_PRETTY_PRINT);
?>
EOF

# Set up log rotation
cat > /etc/logrotate.d/wordpress << 'EOF'
/var/log/httpd/*log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 apache apache
    postrotate
        /bin/systemctl reload httpd.service > /dev/null 2>/dev/null || true
    endscript
}

/var/www/html/wp-content/debug.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 apache apache
    copytruncate
}
EOF

# Create security monitoring script
cat > /usr/local/bin/wordpress-security-monitor.sh << 'EOF'
#!/bin/bash

# WordPress Security Monitoring Script
LOG_FILE="/var/log/wordpress-security.log"
ALERT_EMAIL="admin@hospital.com"

# Check for suspicious activity
check_suspicious_activity() {
    # Check for SQL injection attempts
    SQLI_ATTEMPTS=$(grep -c "union.*select\|drop.*table\|insert.*into" /var/log/httpd/access_log)
    if [ $SQLI_ATTEMPTS -gt 0 ]; then
        echo "$(date): SQL injection attempts detected: $SQLI_ATTEMPTS" >> $LOG_FILE
    fi
    
    # Check for XSS attempts
    XSS_ATTEMPTS=$(grep -c "<script\|javascript:\|onload=" /var/log/httpd/access_log)
    if [ $XSS_ATTEMPTS -gt 0 ]; then
        echo "$(date): XSS attempts detected: $XSS_ATTEMPTS" >> $LOG_FILE
    fi
    
    # Check for brute force attempts
    BRUTE_FORCE=$(grep -c "wp-login.php" /var/log/httpd/access_log | tail -1)
    if [ $BRUTE_FORCE -gt 100 ]; then
        echo "$(date): Potential brute force attack detected: $BRUTE_FORCE login attempts" >> $LOG_FILE
    fi
}

# Run checks
check_suspicious_activity

# Send alerts if needed
if [ -s $LOG_FILE ]; then
    tail -10 $LOG_FILE | mail -s "WordPress Security Alert" $ALERT_EMAIL
fi
EOF

chmod +x /usr/local/bin/wordpress-security-monitor.sh

# Add to crontab
echo "*/5 * * * * /usr/local/bin/wordpress-security-monitor.sh" | crontab -

echo "WordPress installation with WAF integration completed successfully!"
echo "Security features enabled:"
echo "- Login attempt limiting"
echo "- Security headers"
echo "- File access restrictions"
echo "- Security monitoring"
echo "- CloudWatch logging"
echo ""
echo "Access your WordPress site through the Application Load Balancer"
echo "Health check available at: /health.php"
