# PHP SRE Troubleshooting Cheatsheet

## **Scenario 1: 502 Bad Gateway / PHP-FPM Won't Respond**
**Symptoms:** Nginx returns 502, `connect() to unix:/var/run/php-fpm.sock failed`

**Causes:**
- FPM not running
- All workers busy (pm.max_children too low)
- Socket permission issues
- Socket path mismatch between Nginx and FPM

**Fix:**
```bash
systemctl status php-fpm                    # Check if running
ps aux | grep php-fpm | wc -l              # Count workers
# Check nginx config matches FPM listen directive
grep "fastcgi_pass" /etc/nginx/sites-enabled/*
grep "listen" /etc/php-fpm.d/www.conf
# Increase workers if all busy
pm.max_children = 100  # In FPM config
systemctl reload php-fpm
```

---

## **Scenario 2: Slow Response Times**
**Symptoms:** Pages load in 5-10+ seconds, users complaining

**Causes:**
- Database queries not optimized
- OPcache disabled or full
- FPM workers doing blocking I/O
- `max_execution_time` too high allowing slow requests

**Fix:**
```bash
# Check FPM slow log
tail -f /var/log/php-fpm/www-slow.log
# Enable slow log if not set
request_slowlog_timeout = 5s
slowlog = /var/log/php-fpm/www-slow.log

# Check OPcache status (create info.php with phpinfo())
opcache.enable = 1
opcache.memory_consumption = 256

# Restart FPM to clear OPcache
systemctl restart php-fpm
```

---

## **Scenario 3: Memory Exhausted Errors**
**Symptoms:** `Fatal error: Allowed memory size of X bytes exhausted`

**Causes:**
- Memory limit too low for workload
- Memory leak in application
- Large file uploads/processing
- Inefficient queries loading huge datasets

**Fix:**
```bash
# Check current limit
php -i | grep memory_limit

# Increase in php.ini
memory_limit = 256M

# Or per-site in FPM pool
php_admin_value[memory_limit] = 256M

# Monitor per-process memory
ps aux --sort=-%mem | grep php-fpm | head -10

# Calculate max_children based on available RAM
# Formula: max_children = (Total RAM - System RAM) / Average Process Size
# Example: (8GB - 2GB) / 100MB = 60 max workers
```

---

## **Scenario 4: High CPU Usage**
**Symptoms:** Server CPU at 90%+, php-fpm processes consuming resources

**Causes:**
- Too many workers spawned
- Infinite loops in code
- Inefficient code execution
- No OPcache (recompiling on every request)

**Fix:**
```bash
# Check which PHP process is consuming CPU
top -c -p $(pgrep -d',' php-fpm)

# Check OPcache
php -i | grep opcache.enable

# Reduce workers if over-provisioned
pm.max_children = 30  # Lower if too high

# Enable process limits
pm.max_requests = 500  # Restart workers after N requests

# Check for runaway processes
php -i | grep max_execution_time
```

---

## **Scenario 5: Site Down After Deploy**
**Symptoms:** White screen, 500 errors immediately after code deployment

**Causes:**
- OPcache serving old bytecode
- Syntax errors in new code
- Missing dependencies (Composer packages)
- File permissions changed

**Fix:**
```bash
# Clear OPcache
systemctl reload php-fpm
# Or via code: opcache_reset()

# Check PHP error log
tail -f /var/log/php-fpm/error.log
tail -f /var/www/app/storage/logs/laravel.log

# Verify file permissions
chown -R www-data:www-data /var/www/app
chmod -R 755 /var/www/app

# Check for missing dependencies
cd /var/www/app
composer install --no-dev --optimize-autoloader

# Test PHP syntax
php -l /var/www/app/index.php
```

---

## **Scenario 6: File Upload Failures**
**Symptoms:** Users can't upload files, "File too large" errors

**Causes:**
- `upload_max_filesize` too small
- `post_max_size` smaller than upload limit
- Temp directory full or wrong permissions
- Nginx `client_max_body_size` too small

**Fix:**
```bash
# Check current settings
php -i | grep upload_max_filesize
php -i | grep post_max_size

# Update php.ini
upload_max_filesize = 50M
post_max_size = 60M         # Must be >= upload size
max_file_uploads = 20

# Check temp directory
php -i | grep upload_tmp_dir
df -h /tmp                  # Check space
ls -ld /tmp                 # Check permissions

# Don't forget Nginx
client_max_body_size 50M;   # In nginx.conf
```

---

## **Scenario 7: Session Issues / Users Logged Out**
**Symptoms:** Users randomly logged out, session data lost

**Causes:**
- Session directory not writable
- Session GC deleting active sessions
- Multiple servers not sharing sessions
- Disk full

**Fix:**
```bash
# Check session settings
php -i | grep session.save_path
ls -ld /var/lib/php/sessions

# Fix permissions
chown -R www-data:www-data /var/lib/php/sessions
chmod 700 /var/lib/php/sessions

# Adjust GC probability if too aggressive
session.gc_probability = 1
session.gc_divisor = 1000      # 0.1% chance per request
session.gc_maxlifetime = 1440  # 24 minutes

# For multiple servers, use Redis/Memcached
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379"
```

---

## **Scenario 8: Database Connection Errors**
**Symptoms:** `Too many connections`, `SQLSTATE[HY000] [2002]`

**Causes:**
- Connection pool exhausted
- App not closing connections
- Too many FPM workers for DB capacity
- Network issues to database

**Fix:**
```bash
# Check MySQL max connections
mysql -e "SHOW VARIABLES LIKE 'max_connections';"
mysql -e "SHOW STATUS LIKE 'Threads_connected';"

# Increase DB connections
max_connections = 200  # In my.cnf

# Reduce FPM workers if exceeding DB capacity
pm.max_children = 50  # Must be < DB max_connections

# Enable persistent connections cautiously
# In app config (Laravel example)
'mysql' => [
    'options' => [
        PDO::ATTR_PERSISTENT => false  # Usually false for FPM
    ]
]

# Check for connection leaks
lsof -i :3306 | grep php-fpm
```

---

## **Scenario 9: Logs Full / Disk Space Issues**
**Symptoms:** Disk at 100%, can't write files, site errors

**Causes:**
- Error logs growing unbounded
- Debug mode left on in production
- No log rotation configured

**Fix:**
```bash
# Find large files
du -sh /var/log/* | sort -h
du -sh /var/www/*/storage/logs/*

# Clear old logs
truncate -s 0 /var/log/php-fpm/error.log
find /var/log/php-fpm -name "*.log" -mtime +7 -delete

# Setup logrotate
cat > /etc/logrotate.d/php-fpm <<EOF
/var/log/php-fpm/*.log {
    daily
    rotate 14
    missingok
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload php-fpm > /dev/null
    endscript
}
EOF

# Disable debug in production
# In Laravel: APP_DEBUG=false in .env
```

---

## **Scenario 10: Workers Stuck / Zombies**
**Symptoms:** Workers in "busy" state for hours, not processing requests

**Causes:**
- `max_execution_time = 0` allowing infinite runs
- Blocking calls (external API, file locks)
- Deadlocks

**Fix:**
```bash
# Check FPM status (enable status page)
# In FPM pool config:
pm.status_path = /status

# Nginx config:
location ~ ^/(status|ping)$ {
    access_log off;
    fastcgi_pass unix:/var/run/php-fpm.sock;
    include fastcgi_params;
}

curl http://localhost/status?full
# Look for processes in "Running" state for long times

# Set execution limits
max_execution_time = 30
max_input_time = 60

# Auto-restart workers
pm.max_requests = 500

# Kill stuck processes
ps aux | grep php-fpm | grep "00:" | awk '{print $2}' | xargs kill -9
systemctl restart php-fpm
```

---

## **Quick Reference Commands**

```bash
# Status & Monitoring
systemctl status php-fpm
ps aux | grep php-fpm
curl http://localhost/status?full          # FPM status page

# Logs
tail -f /var/log/php-fpm/error.log
tail -f /var/log/php-fpm/www-slow.log
tail -f /var/www/app/storage/logs/*.log

# Config Check
php --ini                                  # Find loaded configs
php -i | grep "Configuration File"
php-fpm -t                                 # Test config syntax

# Reload/Restart
systemctl reload php-fpm                   # Graceful, no downtime
systemctl restart php-fpm                  # Full restart, drops connections

# Performance
php -i | grep opcache                      # Check OPcache
php -i | grep memory_limit
php -i | grep max_execution_time
```

---

## **Key Metrics to Monitor**

- **FPM Pool Utilization:** Active workers / max_children (alert >80%)
- **Request Queue:** Requests waiting for workers (should be 0)
- **Memory per Process:** Usually 50-150MB depending on app
- **Request Duration:** P95 should be <500ms for web requests
- **OPcache Hit Rate:** Should be >95%
- **Error Rate:** Track fatal errors, warnings in logs

---

## **Critical FPM Configuration Reference**

### PHP-FPM Pool Settings (`/etc/php-fpm.d/www.conf`)
```ini
[www]
user = www-data
group = www-data
listen = /var/run/php-fpm.sock
listen.owner = www-data
listen.group = nginx
listen.mode = 0660

pm = dynamic                    # dynamic, static, or ondemand
pm.max_children = 50           # Max workers
pm.start_servers = 5           # Initial workers
pm.min_spare_servers = 5       # Idle minimum
pm.max_spare_servers = 10      # Idle maximum
pm.max_requests = 500          # Restart after N requests

; Logging
slowlog = /var/log/php-fpm/www-slow.log
request_slowlog_timeout = 5s
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on

; Status page
pm.status_path = /status
ping.path = /ping
```

### Key php.ini Settings
```ini
; Resource Limits
memory_limit = 128M
max_execution_time = 30
max_input_time = 60
post_max_size = 20M
upload_max_filesize = 20M
max_file_uploads = 20

; OPcache
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1

; Error Logging
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off           # Never On in production
log_errors = On
error_log = /var/log/php_errors.log

; Session
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
```

---

## **Tuning Formula Reference**

### Calculate max_children
```
max_children = (Total RAM - System RAM - Other Services) / Average PHP Process Size

Example:
Total RAM: 8GB
System + Other: 2GB
PHP Process: 100MB average
max_children = (8GB - 2GB) / 100MB = 6000MB / 100MB = 60
```

### Calculate OPcache Size
```
opcache.memory_consumption = (Number of PHP Files × 2KB) × 1.5 (overhead)

Example:
5000 PHP files × 2KB = 10MB
10MB × 1.5 = 15MB minimum
Recommended: 128MB for most applications
```

---

## **Emergency Response Checklist**

1. **Site Down?**
   - [ ] Check FPM is running: `systemctl status php-fpm`
   - [ ] Check error logs: `tail -100 /var/log/php-fpm/error.log`
   - [ ] Test config: `php-fpm -t`
   - [ ] Restart FPM: `systemctl restart php-fpm`

2. **Slow Performance?**
   - [ ] Check FPM status: `curl http://localhost/status?full`
   - [ ] Check CPU/Memory: `top -c | grep php-fpm`
   - [ ] Check slow log: `tail -50 /var/log/php-fpm/www-slow.log`
   - [ ] Clear OPcache: `systemctl reload php-fpm`

3. **High Load?**
   - [ ] Count workers: `ps aux | grep php-fpm | wc -l`
   - [ ] Check pool utilization in status page
   - [ ] Check for zombies: `ps aux | grep php-fpm | grep "00:"`
   - [ ] Review max_children setting

4. **After Deploy Issues?**
   - [ ] Reload FPM to clear OPcache: `systemctl reload php-fpm`
   - [ ] Check file permissions: `ls -la /var/www/app`
   - [ ] Run composer: `composer install`
   - [ ] Check app logs: `tail -f /var/www/app/storage/logs/laravel.log`