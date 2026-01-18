# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Educational project demonstrating REST API test automation using Python, Docker, and Kubernetes:

1. **Backend API** - FastAPI application with PostgreSQL for user management (CRUD operations)
2. **Automated Tests** - pytest-based test suite with fixtures, parametrization, and logging
3. **Infrastructure** - Docker Compose for local development and Kubernetes manifests for deployment

**Learning Context:** This project is used for SDET/DevOps learning (see `LEARNING.md` and `LEARNING_PROGRESS.md`)
**Current Phase:** Week 2, Day 5 - Docker logs analysis and automation completed

## Quick Start

```bash
# Start all services
docker-compose up -d postgres backend

# Check status
docker-compose ps

# View logs
docker-compose logs -f backend

# Run tests
docker-compose up tests

# Stop services
docker-compose down
```

**Browser Access:**
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health Check: http://localhost:8000/

## Architecture

### Backend Application (`backend/app/`)

**FastAPI Application Structure:**
- `main.py` - API endpoints with request validation and error handling
- `models.py` - SQLAlchemy ORM models
- `schemas.py` - Pydantic schemas for request/response validation
- `crud.py` - Database CRUD operations
- `database.py` - Database connection and session management

**Key Patterns:**
- Database session managed via FastAPI Depends injection (`get_db()` generator)
- Automatic table creation on startup via SQLAlchemy metadata
- Pydantic email validation using `pydantic[email]` package
- Unique constraints on email and username fields
- Environment-based configuration via `DATABASE_URL`

**API Endpoints:**
- `GET /` - Health check
- `POST /users` - Create user (validates email/username uniqueness)
- `GET /users` - List users with pagination (skip/limit parameters)
- `GET /users/{user_id}` - Get user by ID
- `PUT /users/{user_id}` - Update user (partial updates supported)
- `DELETE /users/{user_id}` - Delete user
- `GET /docs` - Swagger UI
- `GET /redoc` - ReDoc documentation

### Test Architecture (`tests/`)

**Test Organization:**
- `test_users_crud.py` - Positive CRUD test scenarios
- `test_users_negative.py` - Negative scenarios (validation errors, conflicts)
- `test_users_edge_cases.py` - Edge cases and boundary testing
- `conftest.py` - Pytest fixtures shared across all test files
- `utils/logger.py` - HTTP request/response logging
- `utils/helpers.py` - Test data generators and assertion helpers

**Key Fixtures:**
- `base_url` (session) - API base URL from `API_BASE_URL` environment variable
- `api_client` (session) - requests.Session with automatic HTTP logging
- `created_user` (function) - Creates test user with automatic cleanup
- `multiple_users` (function) - Creates 5 test users with cleanup
- `wait_for_api` (autouse) - Checks API availability before each test

**Test Markers:**
- `@pytest.mark.smoke` - Fast smoke tests for core functionality
- `@pytest.mark.regression` - Full regression test suite
- `@pytest.mark.crud` - CRUD operation tests
- `@pytest.mark.negative` - Negative test scenarios
- `@pytest.mark.edge_case` - Edge case and boundary tests

### Docker Architecture

**Multi-Service Setup** (`docker-compose.yml`):

1. **postgres** service:
   - Image: `postgres:15-alpine`
   - Credentials: testuser/testpass, database: testdb
   - Health check via `pg_isready` every 10s
   - Persistent volume: `postgres_data`
   - Port: 5432

2. **backend** service:
   - Builds from `docker/backend.Dockerfile`
   - Depends on postgres health check
   - Environment: `DATABASE_URL=postgresql://testuser:testpass@postgres:5432/testdb`
   - Port: 8000
   - Auto-restart: `unless-stopped`

3. **tests** service:
   - Builds from `docker/tests.Dockerfile`
   - Depends on backend startup
   - Environment: `API_BASE_URL=http://backend:8000`
   - Default command: `pytest -v --tb=short`

**Network:** All services communicate via isolated `app_network` bridge network.

### Kubernetes Architecture

**Namespace:** `users-api`

**Deployment Pattern:**
- PostgreSQL StatefulSet-style deployment with PVCs
- Backend Deployment with configurable replicas
- Service resources for internal communication
- Job resource for one-time test execution

**Test Execution:**
- Kubernetes Job (`k8s/tests-job.yaml`) runs tests as one-off task
- Init container (`wait-for-backend`) polls health endpoint before tests
- Job config: `backoffLimit: 0`, `ttlSecondsAfterFinished: 3600`
- Resource limits: 256Mi memory, 200m CPU

## Running Commands

### Docker Compose Commands

```bash
# Start services
docker-compose up --build              # Build and start all services
docker-compose up -d postgres backend  # Start only backend services in background
docker-compose up tests                # Run tests against running backend

# Stop services
docker-compose down                    # Stop all services
docker-compose down -v                 # Stop and remove volumes (clears database)

# View logs
docker-compose logs backend            # All backend logs
docker-compose logs -f backend         # Follow logs in real-time
docker-compose logs --tail=50 backend  # Last 50 lines
docker-compose logs -t backend         # With timestamps
docker-compose logs --since=30m backend  # Last 30 minutes

# Check status
docker-compose ps                      # Service status
```

### Running Tests

```bash
# Run all tests
docker-compose up tests

# Run specific test file
docker-compose run tests pytest -v test_users_crud.py

# Run with specific marker
docker-compose run tests pytest -v -m smoke

# Run specific test by name
docker-compose run tests pytest -v -k test_create_user_success

# Run with parallel execution
docker-compose run tests pytest -v -n auto

# Run with coverage report
docker-compose run tests pytest --cov=. --cov-report=html

# Pytest debugging options
docker-compose run tests pytest -v --tb=long  # Detailed traceback
docker-compose run tests pytest -v -x         # Stop on first failure
docker-compose run tests pytest -v --lf       # Rerun only last failed
docker-compose run tests pytest -v --pdb      # Drop into debugger on failure
```

### Kubernetes Operations

```bash
# Build and load images (for Minikube)
docker build -t users-api-backend:latest -f docker/backend.Dockerfile .
docker build -t users-api-tests:latest -f docker/tests.Dockerfile .
minikube image load users-api-backend:latest
minikube image load users-api-tests:latest

# Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/postgres-service.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# Check deployment status
kubectl get pods -n users-api
kubectl wait --for=condition=ready pod -l app=backend -n users-api --timeout=120s

# Run tests in Kubernetes
kubectl apply -f k8s/tests-job.yaml
kubectl get jobs -n users-api
kubectl logs -n users-api -l app=api-tests -f

# Port-forward to access API locally
kubectl port-forward -n users-api svc/backend 8000:8000

# Clean up
kubectl delete job api-tests -n users-api
kubectl delete namespace users-api
```

### Local Development

**Running Backend Locally with Hot Reload:**
```bash
# Start only PostgreSQL via Docker
docker-compose up postgres

# In separate terminal, run backend locally
cd backend
pip install -r requirements.txt
set DATABASE_URL=postgresql://testuser:testpass@localhost:5432/testdb
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Running Tests Locally (without Docker):**
```bash
# Windows PowerShell
.venv\Scripts\Activate.ps1
pip install -r tests\requirements.txt
set API_BASE_URL=http://localhost:8000
pytest -v
```

## Logs Directory Structure

**Organized structure** for logs, backups, and analysis results (see `logs/README.md`):

```
logs/
├── raw/              # Manual log saves (by service: backend/, postgres/, tests/)
├── backups/          # Manual backups before deployments (backup_logs.sh)
├── rotated/          # Automated daily rotation via cron (logs_rotation.sh)
├── archives/         # Long-term tar.gz archives (compliance, audit)
├── analysis/         # Analysis results
│   ├── error_reports/   # HTML/TXT error reports (error_patterns.sh)
│   ├── slow_requests/   # Slow HTTP request analysis (find_slow_requests.sh)
│   └── stats/           # Statistics (top IPs, endpoints, HTTP codes)
└── alerts/           # Live monitoring alerts (live_monitor.sh)
    └── critical/        # Critical events only
```

**Key differences:**
- `backups/` - Manual backup before deployments (uncompressed by default, long retention)
- `rotated/` - Automated cron rotation (compressed .gz, auto-cleanup after N days)
- `archives/` - Long-term storage (weekly/monthly tar.gz for compliance)

## Automation Scripts

**Quick Reference** (see `SCRIPTS_GUIDE.md` for detailed scenarios):

```bash
# Before deployment: backup current state
./scripts/backup_logs.sh --service=all --archive

# Daily automated rotation (via cron)
./scripts/logs_rotation.sh --service=all --compress --max-files=7

# Incident investigation: analyze errors
./scripts/error_patterns.sh --service=backend --report
# → logs/analysis/error_reports/backend_errors_YYYYMMDD.html

# Find performance issues
./scripts/find_slow_requests.sh --threshold=1.0
# → Shows: min, max, avg, p50, p95, p99 response times

# Live monitoring with alerts
./scripts/live_monitor.sh --service=backend --alert-on=ERROR --save-alerts
# → logs/alerts/alerts.log

# Health check all services
./scripts/monitoring_script.sh

# Cleanup old logs
./scripts/cleanup_logs.sh --days=30 --dry-run  # Preview
./scripts/cleanup_logs.sh --days=30 --force     # Execute

# Generate load for testing
python scripts/load_test.py
```

**Cron Automation Example:**
```bash
# Daily rotation at 2 AM
0 2 * * * cd /path/to/DockerKube && ./scripts/logs_rotation.sh --service=all --compress --max-files=7

# Daily error reports at 3 AM
0 3 * * * cd /path/to/DockerKube && ./scripts/error_patterns.sh --service=backend --report

# Weekly cleanup on Mondays at 5 AM
0 5 * * 1 cd /path/to/DockerKube && ./scripts/cleanup_logs.sh --days=30 --force
```

**Documentation:**
- `SCRIPTS_GUIDE.md` - Which script to use when (5 real scenarios)
- `scripts/README.md` - All scripts with examples
- `AUTOMATION.md` - Cron jobs and production setup
- `logs/README.md` - Logs directory structure explanation
- `logs/{backups,rotated,analysis,alerts}/README.md` - Specific folder documentation

## WSL Integration

**Bash Aliases** (configured in `~/.bashrc`):
```bash
alias dc='docker-compose'
alias dcup='docker-compose up'
alias dcdown='docker-compose down'
alias dclogs='docker-compose logs'
alias dcps='docker-compose ps'
```

**Project Path:**
```bash
cd /mnt/c/Users/Admin/PycharmProjects/DockerKube
```

**Make Scripts Executable:**
```bash
chmod +x analyze_logs.sh
chmod +x scripts/*.sh
```

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string (backend)
- `API_BASE_URL` - Base URL for API testing (tests)
- `PYTHONUNBUFFERED=1` - Ensure immediate log output (tests)
- `PYTHONDONTWRITEBYTECODE=1` - Prevent __pycache__ creation (tests)

## Important Notes

- Backend automatically creates tables on startup via SQLAlchemy metadata
- Tests use automatic cleanup fixtures to prevent data pollution
- All services wait for dependencies via health checks or init containers
- Kubernetes images must be loaded into cluster for Minikube/Kind
- pytest timeout: 60 seconds per test (configurable in `pytest.ini`)
- For production automation and cron jobs, see `AUTOMATION.md`
- For learning materials and educational approach, see `LEARNING.md`

## Development Workflow

**Debugging Failed Tests:**
- The `api_client` fixture automatically logs all HTTP requests/responses
- Use pytest options: `--tb=long`, `-x`, `--lf`, `--pdb`, `-s`

**Database Cleanup:**
- Use `docker-compose down -v` to reset database state

**Rebuilding Images:**
- Use `docker-compose up --build` when dependencies change

**Parallel Test Execution:**
- Use `-n auto` to auto-detect CPU cores (requires `pytest-xdist`)

**Deployment Workflow (with log backup):**
```bash
# STEP 1: Backup current state (before deploy)
./scripts/backup_logs.sh --service=all --archive
./scripts/monitoring_script.sh > logs/analysis/stats/health_before_deploy.txt

# STEP 2: Deploy new version
docker-compose down
docker-compose pull
docker-compose up -d

# STEP 3: Check after deployment
./scripts/monitoring_script.sh > logs/analysis/stats/health_after_deploy.txt

# STEP 4: Compare before/after
diff logs/analysis/stats/health_before_deploy.txt \
     logs/analysis/stats/health_after_deploy.txt

# STEP 5: Analyze logs for issues
./scripts/error_patterns.sh --service=backend --report
./scripts/find_slow_requests.sh --threshold=1.0

# STEP 6: Rollback if needed (using backup to investigate)
# If issues found → use backup logs to compare old vs new behavior
```

**Why backup logs before deployment:**
- Compare "before/after" to identify regressions
- Establish baseline metrics (error rate, response times)
- Quick incident investigation (minutes, not days)
- Compliance and audit trail
- Rollback justification with evidence

## Learning Resources

- `LEARNING.md` - Educational approach and communication style
- `LEARNING_PROGRESS.md` - 12-week SDET/DevOps learning plan with progress tracking
- `COMMANDS_CHEATSHEET.md` - Linux and Docker commands reference (grep, awk, sed, docker logs)
- `AUTOMATION.md` - Automation scripts, cron jobs, and production setup
- `docs/learning/docker-compose-explained.md` - Line-by-line docker-compose.yml explanation
- `scripts/README.md` - Documentation for all automation scripts

## PyCharm Optimization

**Utility Scripts:**
- `clear_pycharm_cache.bat` - Clean PyCharm caches when IDE becomes slow
- `monitor_pycharm.ps1` - Monitor PyCharm memory/CPU usage

**Common Issues:**
- Terminal lag: Clear terminal with `cls` before running docker-compose
- PyCharm freezing: Run `clear_pycharm_cache.bat` and restart IDE
- High memory usage: Restart PyCharm if >5GB RAM

## Windows-Specific Notes

**PowerShell vs CMD:**
- PowerShell: `$env:API_BASE_URL="http://localhost:8000"`
- CMD: `set API_BASE_URL=http://localhost:8000`

**Line Endings:**
- Ensure bash scripts use LF (not CRLF) line endings
- Use `dos2unix` or `sed -i 's/\r$//'` to convert

**Docker Desktop:**
- Enable WSL 2 backend for better performance
- Check WSL Integration in Docker Desktop settings
