# PostgreSQL Configuration for n8n

## 📊 Database Architecture

### Overview
This setup uses PostgreSQL 15 as the primary database for n8n workflow automation platform, providing:
- **Persistent data storage** for workflows, executions, and credentials
- **Multi-user support** with separate database users
- **Scalable performance** for production workloads
- **ACID compliance** for data integrity

### Database Schema
n8n automatically creates the following tables:
- `workflows` - Workflow definitions and metadata
- `executions` - Workflow execution history and logs
- `credentials` - Encrypted credential storage
- `webhook_entity` - Webhook configurations
- `settings` - System configuration settings
- `tag_entity` - Workflow tags and organization
- `workflows_tags` - Many-to-many relationship table

## 🔧 Configuration Details

### Environment Variables
Located in `n8n-docker/.env`:

```env
# PostgreSQL Database Configuration
DB_TYPE=postgresdb
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=YourSecurePassword
DB_POSTGRESDB_SCHEMA=public
DB_POSTGRESDB_POOL_SIZE=2
DB_POSTGRESDB_CONNECTION_TIMEOUT=20000
DB_POSTGRESDB_IDLE_CONNECTION_TIMEOUT=30000
```

### Connection Pool Settings
- **Pool Size**: 2 concurrent connections (adjustable based on load)
- **Connection Timeout**: 20 seconds
- **Idle Timeout**: 30 seconds for connection cleanup
- **SSL**: Disabled for local development (enable for production)

## 🛡️ Security Configuration

### User Management
- **Admin User**: `postgres` (database admin)
- **Application User**: `n8n` (limited privileges for n8n application)
- **Password Policy**: Strong passwords required (minimum 12 characters)

### Access Control
```sql
-- n8n user permissions
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
GRANT ALL ON SCHEMA public TO n8n;
ALTER USER n8n CREATEDB;
```

### SSL Configuration (Production)
For production environments, enable SSL:
```env
DB_POSTGRESDB_SSL_ENABLED=true
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true
DB_POSTGRESDB_SSL_CA=/path/to/ca-certificate.crt
DB_POSTGRESDB_SSL_CERT=/path/to/client-certificate.crt
DB_POSTGRESDB_SSL_KEY=/path/to/client-key.key
```

## 📦 Docker Configuration

### PostgreSQL Service
```yaml
postgres:
  image: postgres:15
  restart: unless-stopped
  environment:
    - POSTGRES_USER=${POSTGRES_USER}
    - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    - POSTGRES_DB=${POSTGRES_DB}
  volumes:
    - postgres_data:/var/lib/postgresql/data
  ports:
    - "5432:5432"
  healthcheck:
    test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
    interval: 5s
    timeout: 5s
    retries: 10
```

### Volume Management
- **Named Volume**: `postgres_data` for persistent storage
- **Backup Strategy**: Regular volume backups recommended
- **Data Location**: `/var/lib/postgresql/data` inside container

## 🔍 Monitoring & Maintenance

### Health Checks
The Docker setup includes automatic health monitoring:
- **Check Interval**: Every 5 seconds
- **Timeout**: 5 seconds per check
- **Retry Limit**: 10 attempts before marking unhealthy

### Performance Monitoring
```sql
-- Check database size
SELECT pg_size_pretty(pg_database_size('n8n')) as database_size;

-- Monitor active connections
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Backup Commands
```powershell
# Create database backup
docker compose exec postgres pg_dump -U n8n -d n8n > backup_$(Get-Date -Format "yyyyMMdd_HHmmss").sql

# Restore from backup
docker compose exec -T postgres psql -U n8n -d n8n < backup_file.sql

# Full volume backup
docker run --rm -v postgres_data:/data -v ${PWD}:/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

## 🚀 Optimization Tips

### Performance Tuning
For higher loads, adjust PostgreSQL settings:
```sql
-- Increase shared_buffers (25% of RAM)
ALTER SYSTEM SET shared_buffers = '512MB';

-- Adjust work_mem for complex queries
ALTER SYSTEM SET work_mem = '16MB';

-- Optimize for SSD storage
ALTER SYSTEM SET random_page_cost = 1.1;

-- Apply changes
SELECT pg_reload_conf();
```

### Connection Pooling
For production with high concurrency:
```env
# Increase connection pool
DB_POSTGRESDB_POOL_SIZE=10

# Adjust timeouts
DB_POSTGRESDB_CONNECTION_TIMEOUT=30000
DB_POSTGRESDB_IDLE_CONNECTION_TIMEOUT=60000
```

## 🔧 Troubleshooting

### Common Issues

#### Connection Refused
```powershell
# Check if PostgreSQL container is running
docker compose ps

# View PostgreSQL logs
docker compose logs postgres

# Test connection manually
docker compose exec postgres psql -U n8n -d n8n -c "SELECT version();"
```

#### Permission Denied
```sql
-- Fix user permissions
GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
GRANT ALL ON SCHEMA public TO n8n;
GRANT USAGE ON SCHEMA public TO n8n;
```

#### Database Not Found
```powershell
# Recreate database
docker compose exec postgres createdb -U postgres -O n8n n8n
```

### Log Analysis
```powershell
# View detailed PostgreSQL logs
docker compose logs -f postgres

# Filter for errors only
docker compose logs postgres 2>&1 | findstr ERROR

# Check n8n database connection logs
docker compose logs n8n 2>&1 | findstr -i "database\|postgres\|connection"
```

## 📊 Capacity Planning

### Storage Requirements
- **Base Installation**: ~50MB
- **Per Workflow**: ~1-5KB
- **Per Execution**: ~5-50KB (depending on data size)
- **Growth Rate**: Plan for 100MB per 1000 executions

### Resource Recommendations
- **Development**: 512MB RAM, 2GB storage
- **Small Production**: 1GB RAM, 10GB storage
- **Medium Production**: 2GB RAM, 50GB storage
- **Large Production**: 4GB+ RAM, 200GB+ storage

## 🔐 Security Best Practices

### Production Checklist
- [ ] Use strong, unique passwords for all database users
- [ ] Enable SSL/TLS encryption for database connections
- [ ] Regularly update PostgreSQL to latest stable version
- [ ] Implement automated backup strategy
- [ ] Monitor database access logs
- [ ] Use connection pooling for high-traffic scenarios
- [ ] Restrict database access to application subnet only
- [ ] Enable audit logging for compliance requirements

### Credential Management
- Store database passwords in Docker secrets or external vault
- Rotate credentials regularly (quarterly recommended)
- Use separate users for different application components
- Implement least-privilege access principles

---
*This configuration supports both development and production deployments of n8n with PostgreSQL.*
