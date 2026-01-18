# AUTOMATION.md

Automation scripts, cron jobs, and production deployment guides.

## Overview

This project includes production-ready bash scripts for:
- Log analysis and monitoring
- Service health checks
- Log backup and rotation
- Performance analysis
- Automated cleanup

All scripts follow industry best practices with:
- Detailed usage documentation
- Color-coded output
- Parameter validation
- Dry-run modes where applicable
- Error handling

## Available Scripts

### 1. load_test.py - HTTP Load Generator

**Purpose:** Generate HTTP traffic with intentional errors for log analysis practice.

**What it does:**
- Creates 20 HTTP POST requests to `/users` endpoint
- 70% valid requests (status 200/201)
- 30% error requests:
  - Invalid email (status 422)
  - Missing username field (status 422)
  - Duplicate email (status 400)
- 0.3 second delay between requests

**Usage:**
```bash
python load_test.py
# or
python scripts/load_test.py
```

**When to use:**
- Practicing log analysis with grep/awk/sed
- Testing monitoring scripts
- Generating realistic error patterns

---

### 2. analyze_logs.sh - Automatic Log Analysis

**Purpose:** Comprehensive automatic analysis of backend logs.

**What it analyzes:**
- Total HTTP request count
- HTTP status code statistics (200, 400, 422, 500, etc.)
- 4xx and 5xx error counts
- Error type breakdown
- Last 5 errors
- Success rate percentage

**Usage:**
```bash
./analyze_logs.sh
# or
bash analyze_logs.sh
```

**Output example:**
```
═══════════════════════════════════════════════
Backend Logs Analysis
═══════════════════════════════════════════════
Total HTTP requests: 724
Success (200/201): 592 (82%)
Errors (4xx/5xx): 132 (18%)

Status code breakdown:
  200: 520
  201: 72
  400: 72
  422: 36
  404: 24
```

**Technologies used:** grep, awk, sed, sort, uniq, wc

---

### 3. generate_bug_report.sh - Professional Bug Report Generator

**Purpose:** Generate structured bug reports with timestamp.

**Sections included:**
1. Error Statistics
2. Error Examples
3. IP Analysis
4. Time Range
5. Error Types Breakdown
6. Top 5 Most Recent Errors
7. Recommendations

**Usage:**
```bash
./generate_bug_report.sh
```

**Output:** Creates `bug_report_YYYYMMDD_HHMMSS.txt` with detailed analysis.

**When to use:**
- After incident investigation
- Before reporting bugs to team
- For compliance documentation

---

### 4. find_slow_requests.sh - Performance Analysis

**Purpose:** Find slow HTTP requests in Docker logs.

**Features:**
- Customizable threshold (default: 1.0 second)
- Top N slowest requests
- Response time statistics (min, max, avg, p50, p95, p99)
- Optional output to file
- Formatted table output

**Usage:**
```bash
# Find requests slower than 2 seconds
./scripts/find_slow_requests.sh --threshold=2.0

# Find top 10 slowest requests
./scripts/find_slow_requests.sh --top=10

# Save results to file
./scripts/find_slow_requests.sh --threshold=1.5 --output=slow_requests.txt

# Analyze specific service
./scripts/find_slow_requests.sh --service=backend --threshold=1.0

# Show help
./scripts/find_slow_requests.sh --help
```

**Output format:**
```
TIME   | METHOD | ENDPOINT                | STATUS | TIMESTAMP
────────────────────────────────────────────────────────────
3500ms | POST   | /users                  | 201    | 2025-12-25T10:30:45
2800ms | GET    | /users/123              | 200    | 2025-12-25T10:31:22
1500ms | PUT    | /users/456              | 200    | 2025-12-25T10:32:10

Response Time Statistics:
─────────────────────────────────────
Total requests:  724
Min time:        12ms
Max time:        3500ms
Average time:    145ms
p50 (median):    120ms
p95:             380ms
p99:             890ms
```

**When to use:**
- Performance troubleshooting
- SLA monitoring
- Optimization planning
- Capacity planning

---

### 5. monitoring_script.sh - Service Health Monitoring

**Purpose:** Comprehensive health check of all Docker services.

**Checks performed:**
1. Container status (Running/Stopped)
2. PostgreSQL health (pg_isready)
3. Backend API availability (HTTP 200)
4. Resource usage (CPU/RAM)
5. Error count in logs (last N lines)

**Usage:**
```bash
# Full health check
./scripts/monitoring_script.sh

# Quick check (faster, less detailed)
./scripts/monitoring_script.sh --quick

# Check specific service
./scripts/monitoring_script.sh --service=backend

# Custom log lines to check
./scripts/monitoring_script.sh --logs=100
```

**Exit codes:**
- 0 - All checks passed
- 1 - One or more checks failed

**When to use:**
- Before starting work (quick health check)
- Troubleshooting service issues
- Automated monitoring (via cron)
- Integration with alerting systems

---

### 6. cleanup_logs.sh - Log Cleanup Automation

**Purpose:** Automatically delete old log files to prevent disk space issues.

**Features:**
- Dry-run mode by default (safe)
- Customizable age threshold
- Pattern-based filtering
- Directory specification
- Summary of space saved

**Usage:**
```bash
# See what would be deleted (dry-run)
./scripts/cleanup_logs.sh --days=7 --dry-run

# Actually delete files older than 7 days
./scripts/cleanup_logs.sh --days=7 --force

# Delete specific pattern
./scripts/cleanup_logs.sh --days=30 --pattern="*.log" --force

# Custom directory
./scripts/cleanup_logs.sh --days=7 --dir=/var/log/myapp --force

# Show help
./scripts/cleanup_logs.sh --help
```

**Best practices:**
- Always test with `--dry-run` first
- Keep logs minimum 7 days, recommended 30 days
- Run during low-traffic hours (02:00-04:00)
- Log the cleanup operation itself

**When to use:**
- Development: Manually when disk space is low
- Production: Automated via cron (daily)

---

### 7. backup_logs.sh - Log Backup with Archiving

**Purpose:** Save Docker logs to files with timestamp, optional archiving.

**Features:**
- Timestamped filenames (YYYYMMDD_HHMMSS)
- Optional tar.gz compression (~70% space savings)
- Service selection
- Line limit option
- Automatic cleanup of old archives

**Usage:**
```bash
# Backup all services
./scripts/backup_logs.sh

# Backup with archiving
./scripts/backup_logs.sh --archive

# Backup specific service
./scripts/backup_logs.sh --service=backend --archive

# Backup last 500 lines only
./scripts/backup_logs.sh --lines=500

# Backup and cleanup archives older than 90 days
./scripts/backup_logs.sh --archive --cleanup-days=90
```

**Output location:** `logs/backups/`

**When to use:**
- Before important changes/deployments
- After incidents (preserve evidence)
- Compliance requirements
- Automated daily backups (via cron)

---

## Production Automation with Cron

### Cron Syntax Quick Reference

```
* * * * * command
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 and 7 = Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

**Common patterns:**
```bash
0 2 * * *      # Every day at 02:00
*/15 * * * *   # Every 15 minutes
0 9 * * 1-5    # Every weekday at 09:00
0 0 1 * *      # First day of month at midnight
```

### Production Cron Setup

**Recommended crontab for DockerKube:**

```bash
# Edit crontab
crontab -e

# Add these entries:
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=admin@example.com

# MONITORING: Quick check every 5 minutes
*/5 * * * * cd /opt/dockerkube && ./scripts/monitoring_script.sh --quick >> /var/log/dockerkube/monitoring.log 2>&1

# MONITORING: Full check every hour
0 * * * * cd /opt/dockerkube && ./scripts/monitoring_script.sh >> /var/log/dockerkube/monitoring_full.log 2>&1

# BACKUP: Daily backup at 23:00
0 23 * * * cd /opt/dockerkube && ./scripts/backup_logs.sh --archive >> /var/log/dockerkube/backup.log 2>&1

# CLEANUP: Daily cleanup at 02:00
0 2 * * * cd /opt/dockerkube && ./scripts/cleanup_logs.sh --days=7 --force >> /var/log/dockerkube/cleanup.log 2>&1

# CLEANUP: Weekly old archive cleanup (Sundays at 03:00)
0 3 * * 0 cd /opt/dockerkube && ./scripts/backup_logs.sh --archive --cleanup-days=90 >> /var/log/dockerkube/backup_cleanup.log 2>&1
```

### Cron Best Practices

1. **Use absolute paths:**
   ```bash
   # ❌ Bad
   */15 * * * * monitoring_script.sh

   # ✅ Good
   */15 * * * * /opt/dockerkube/scripts/monitoring_script.sh
   ```

2. **Redirect output to logs:**
   ```bash
   # ❌ Bad (output goes to email)
   0 2 * * * /opt/app/cleanup.sh

   # ✅ Good
   0 2 * * * /opt/app/cleanup.sh >> /var/log/cleanup.log 2>&1
   ```

3. **Change to working directory:**
   ```bash
   0 2 * * * cd /opt/dockerkube && ./scripts/cleanup.sh >> /var/log/cleanup.log 2>&1
   ```

4. **Test manually first:**
   ```bash
   # Run manually with full path
   cd /opt/dockerkube && ./scripts/cleanup.sh

   # Check exit code
   echo $?  # 0 = success

   # If works - add to cron
   ```

### Managing Cron Jobs

```bash
# View current cron jobs
crontab -l

# Edit cron jobs
crontab -e

# Remove all cron jobs
crontab -r

# Edit for specific user (requires sudo)
sudo crontab -e -u username
```

### Debugging Cron Jobs

```bash
# Check cron logs (Ubuntu/Debian)
sudo tail -f /var/log/syslog | grep CRON

# Check cron logs (CentOS/RHEL)
sudo tail -f /var/log/cron

# Check cron daemon status
sudo systemctl status cron      # Ubuntu/Debian
sudo systemctl status crond     # CentOS/RHEL

# Restart cron daemon
sudo systemctl restart cron
```

---

## Integration with Alerting

### Email Alerts

```bash
#!/bin/bash
# monitoring_with_email_alerts.sh

./scripts/monitoring_script.sh > /tmp/monitoring_result.txt 2>&1

if [ $? -ne 0 ]; then
    mail -s "ALERT: Service Issues Detected!" admin@example.com < /tmp/monitoring_result.txt
fi
```

### Slack Alerts

```bash
#!/bin/bash
# monitoring_with_slack_alerts.sh

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

./scripts/monitoring_script.sh > /tmp/monitoring_result.txt 2>&1

if [ $? -ne 0 ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🔴 Service issues detected! Check logs."}' \
        "$SLACK_WEBHOOK"
fi
```

### Telegram Alerts

```bash
#!/bin/bash
# monitoring_with_telegram_alerts.sh

BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"

./scripts/monitoring_script.sh > /tmp/monitoring_result.txt 2>&1

if [ $? -ne 0 ]; then
    MESSAGE="🔴 Service issues detected in DockerKube!"
    curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}&text=${MESSAGE}"
fi
```

**Cron with alerts:**
```bash
# Every 10 minutes monitoring with alerts
*/10 * * * * /opt/dockerkube/monitoring_with_alerts.sh
```

---

## Environment-Specific Recommendations

### Development Environment

**Approach:** Manual execution only
```bash
# Run when needed
./scripts/monitoring_script.sh --quick     # Before starting work
./scripts/cleanup_logs.sh --days=7 --dry-run  # When disk is full
./scripts/backup_logs.sh --archive         # Before major changes
```

**Why:** Cron automation is unnecessary overhead in dev

---

### Staging Environment

**Approach:** Moderate automation
```bash
# Crontab for staging
*/30 * * * * cd /opt/dockerkube && ./scripts/monitoring_script.sh --quick
0 0 * * 0 cd /opt/dockerkube && ./scripts/cleanup_logs.sh --days=14 --force
0 23 * * * cd /opt/dockerkube && ./scripts/backup_logs.sh --archive
```

**Why:** Balance between automation and manual control

---

### Production Environment

**Approach:** Full automation with monitoring
```bash
# Crontab for production (full automation)
*/5 * * * * cd /opt/dockerkube && ./scripts/monitoring_script.sh --quick >> /var/log/monitoring.log 2>&1
0 * * * * cd /opt/dockerkube && ./scripts/monitoring_script.sh >> /var/log/monitoring_full.log 2>&1
0 23 * * * cd /opt/dockerkube && ./scripts/backup_logs.sh --archive >> /var/log/backup.log 2>&1
0 2 * * * cd /opt/dockerkube && ./scripts/cleanup_logs.sh --days=7 --force >> /var/log/cleanup.log 2>&1
*/10 * * * * /opt/dockerkube/monitoring_with_alerts.sh
```

**Why:** Proactive monitoring and automatic remediation

---

## Typical Production Day Timeline

```
00:00 - (Sunday) Old archive cleanup (90+ days)
02:00 - Daily log cleanup (7+ days old)
03:00 - (Sunday) Weekly deep cleanup
23:00 - Daily log backup with archiving

Every 5 minutes  - Quick health check
Every 10 minutes - Health check with alerts
Every hour       - Full health check with log analysis
```

---

## Alternatives to Cron

### systemd Timers (Modern Linux)

**Advantages:**
- Better logging via journalctl
- Dependencies between tasks
- More flexible scheduling

**Example:**
```ini
# /etc/systemd/system/monitoring.timer
[Unit]
Description=Docker monitoring timer

[Timer]
OnCalendar=*:0/15  # Every 15 minutes
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/monitoring.service
[Unit]
Description=Docker monitoring service

[Service]
Type=oneshot
ExecStart=/opt/dockerkube/scripts/monitoring_script.sh --quick
WorkingDirectory=/opt/dockerkube
StandardOutput=append:/var/log/dockerkube/monitoring.log
StandardError=append:/var/log/dockerkube/monitoring.log
```

**Activation:**
```bash
sudo systemctl enable monitoring.timer
sudo systemctl start monitoring.timer
sudo systemctl list-timers  # View active timers
```

---

### Docker-based Scheduling

Run cron inside a container:

```yaml
# Add to docker-compose.yml
services:
  cron:
    image: alpine:latest
    volumes:
      - ./scripts:/scripts
      - ./logs:/logs
    command: >
      sh -c "
      echo '0 2 * * * /scripts/cleanup_logs.sh --days=7 --force' > /etc/crontabs/root &&
      echo '*/15 * * * * /scripts/monitoring_script.sh --quick' >> /etc/crontabs/root &&
      crond -f -l 2
      "
    restart: unless-stopped
```

---

## WSL Integration

### Running Scripts in WSL

```bash
# Make executable (one time)
chmod +x analyze_logs.sh
chmod +x scripts/*.sh

# Run bash scripts
./analyze_logs.sh
./scripts/monitoring_script.sh

# Run Python scripts
python load_test.py
python scripts/load_test.py
```

### WSL Aliases

Already configured in `~/.bashrc`:
```bash
alias dc='docker-compose'
alias dcup='docker-compose up'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs'
alias dcps='docker-compose ps'
```

**Usage in scripts:**
```bash
# ❌ Don't use aliases in scripts
dcup -d backend

# ✅ Use full commands in scripts
docker-compose up -d backend
```

**Why:** Aliases only work in interactive shells, not in cron or automated scripts.

### Troubleshooting

**Permission denied:**
```bash
chmod +x script_name.sh
```

**Line endings (CRLF → LF):**
```bash
# Install dos2unix
sudo apt-get install dos2unix

# Convert file
dos2unix script_name.sh

# Or use sed
sed -i 's/\r$//' script_name.sh
```

---

## Script Documentation

For detailed usage of each script:
```bash
# Show help for any script
./scripts/script_name.sh --help
```

All scripts include:
- Usage syntax
- Available options
- Examples
- Notes and best practices

---

## References

- Main documentation: `CLAUDE.md`
- Learning approach: `LEARNING.md`
- Scripts directory: `scripts/README.md`
- Commands reference: `COMMANDS_CHEATSHEET.md`
