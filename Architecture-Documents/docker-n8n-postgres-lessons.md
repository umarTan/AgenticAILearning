# Docker, PostgreSQL, and n8n – What We Changed, Why It Works, and How to Test

This lesson explains the exact changes we made, what each snippet does, how it achieves the goal, and the commands to validate the setup. It also clarifies how n8n connects to PostgreSQL and how container ports work.

---

## 1) High-Level Overview
- Added persistent storage for both PostgreSQL and n8n using named volumes.
- Wired n8n to PostgreSQL over the internal Docker network (service name DNS).
- Provided an optional database bootstrap path that runs once on a fresh DB volume.
- Exposed only necessary ports to the host so you can access n8n UI and (optionally) PostgreSQL from Windows.

---

## 2) Docker Compose: Snippet-by-Snippet Breakdown

### 2.1 PostgreSQL service
```yaml
services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_NON_ROOT_USER=${POSTGRES_NON_ROOT_USER}
      - POSTGRES_NON_ROOT_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
    volumes:
      - type: volume
        source: postgres_data
        target: /var/lib/postgresql/data
      - type: bind
        source: ./init-data.sh
        target: /docker-entrypoint-initdb.d/init-data.sh
        read_only: true
      - type: bind
        source: ./01_initial_schema.sql
        target: /docker-entrypoint-initdb.d/01_initial_schema.sql
        read_only: true
    ports:
      - "5432:5432"
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 10
```
What it is doing:
- Pulls Postgres 15 and keeps it running unless stopped.
- Sets admin and app user variables used by entrypoint and our init script.
- Mounts a named volume at `/var/lib/postgresql/data` so data persists across container restarts.
- Mounts `init-data.sh` and `01_initial_schema.sql` into `/docker-entrypoint-initdb.d/` so they run automatically on first database initialization (fresh volume only).
- Publishes TCP port 5432 to the host for tools like pgAdmin/psql from Windows.
- Adds a healthcheck so other services (like n8n) wait for Postgres to be ready.

How it achieves that:
- The official Postgres image runs any `*.sh` and `*.sql` files in `/docker-entrypoint-initdb.d/` exactly once when the database directory is empty. This makes first-time bootstrap simple and idempotent.
- Docker named volumes store data outside the container filesystem, providing persistence.
- The healthcheck executes `pg_isready` until it reports ready.

---

### 2.2 n8n service
```yaml
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: unless-stopped
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
      - DB_POSTGRESDB_SCHEMA=public
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=${WEBHOOK_URL}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${GENERIC_TIMEZONE}
      - N8N_SECURE_COOKIE=false
      - N8N_RUNNERS_ENABLED=true
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files
    depends_on:
      postgres:
        condition: service_healthy
```
What it is doing:
- Configures n8n to use PostgreSQL by setting DB_TYPE and related env vars.
- Points n8n to the Postgres host as `postgres` (the Docker service name) on port 5432.
- Publishes n8n’s web UI on host port 5678.
- Persists n8n application data (workflows, settings) in the `n8n_data` volume.
- Waits for Postgres healthcheck to pass before starting.

How it achieves that:
- Docker Compose provides an internal network and DNS; the service name `postgres` resolves to the Postgres container IP inside the network.
- Port mapping `5678:5678` makes n8n accessible on http://localhost:5678 on Windows.

---

### 2.3 Volumes and network
```yaml
volumes:
  n8n_data:
    external: true
  postgres_data:
    external: true

networks:
  default:
    name: n8n_network
```
What it is doing:
- Declares named volumes for data persistence.
- Uses a named default network `n8n_network` so services can communicate via service names.

How it achieves that:
- Docker stores named volumes independently of container lifecycle; tearing down containers won’t delete data unless you remove the volume.
- A named network keeps your environment tidy and reproducible.

---

## 3) Init Scripts: Snippet-by-Snippet

### 3.1 `init-data.sh` (user + privileges)
```bash
#!/bin/bash
set -e

# Create the non-root user and database grants
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$POSTGRES_NON_ROOT_USER') THEN
            CREATE USER $POSTGRES_NON_ROOT_USER WITH PASSWORD '$POSTGRES_NON_ROOT_PASSWORD';
        END IF;
    END
    $$;

    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_NON_ROOT_USER;
    GRANT ALL ON SCHEMA public TO $POSTGRES_NON_ROOT_USER;
    ALTER USER $POSTGRES_NON_ROOT_USER CREATEDB;

    -- Ensure future objects have proper permissions
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $POSTGRES_NON_ROOT_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO $POSTGRES_NON_ROOT_USER;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    GRANT USAGE ON SCHEMA public TO $POSTGRES_NON_ROOT_USER;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $POSTGRES_NON_ROOT_USER;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO $POSTGRES_NON_ROOT_USER;
EOSQL
```
What it is doing:
- Ensures an app (non-root) user exists and has correct privileges on the DB and schema.
- Sets default privileges so any tables/sequences created later are usable by the app user.
- Grants are applied both for future objects (default privileges) and existing objects (ALL TABLES/SEQUENCES).

How it achieves that:
- Uses the admin user to run SQL and configure roles/privileges.
- Default privileges save you from having to grant permissions after each new table is created.

---

### 3.2 `01_initial_schema.sql` (optional app schema)
```sql
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'
    ) THEN
        CREATE EXTENSION pgcrypto;
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source VARCHAR(100) NOT NULL,
    external_id VARCHAR(150),
    company_name TEXT,
    contact_name TEXT,
    email TEXT,
    phone TEXT,
    website TEXT,
    status VARCHAR(50) DEFAULT 'new',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lead_enrichment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    run_id UUID NOT NULL DEFAULT gen_random_uuid(),
    model VARCHAR(100) NOT NULL DEFAULT 'phi3:mini',
    input_json JSONB,
    output_json JSONB,
    score NUMERIC(5,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lead_enrichment_lead_id ON lead_enrichment(lead_id);

CREATE OR REPLACE VIEW v_lead_latest_enrichment AS
SELECT le.lead_id,
       max(le.created_at) AS last_enriched_at,
       (ARRAY_AGG(le.output_json ORDER BY le.created_at DESC))[1] AS latest_output,
       (ARRAY_AGG(le.score ORDER BY le.created_at DESC))[1] AS latest_score
FROM lead_enrichment le
GROUP BY le.lead_id;

CREATE TABLE IF NOT EXISTS app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO app_metadata(key, value)
VALUES ('schema_version', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
```
What it is doing:
- Enables `pgcrypto` so we can use `gen_random_uuid()` for primary keys.
- Creates simple app tables and a view useful for reporting/joins.
- Seeds a tiny `app_metadata` table to quickly verify schema existence.

How it achieves that:
- Uses idempotent `IF NOT EXISTS` so re-applying the file is safe.
- Keeps schema minimal and immediately useful for n8n workflows.

---

## 4) How n8n Connects to PostgreSQL (and Ports Explained)

- Inside Docker, services talk over an internal network. You reference other services by their service name (e.g., `postgres`).
- n8n is configured to connect using:
  - Host: `postgres`
  - Port: `5432`
  - DB name/user/password from `.env`
- Port mapping `5678:5678` publishes n8n’s web server to your Windows host at http://localhost:5678.
- Port mapping `5432:5432` publishes PostgreSQL to your Windows host at localhost:5432 (useful for pgAdmin/psql). It’s optional for app-only setups.

Conceptually:
- Internal container port: where the app listens inside the container.
- Published host port: makes that container port available on your machine.
- You do not use `localhost` from one container to reach another; `localhost` stays within the same container. Use service names instead.

---

## 5) Commands to Run and Tests to Validate

### Start and verify services
```powershell
cd "d:\Qaariah\AgenticAI\n8n-docker"
docker compose up -d
docker compose ps
```

### Check logs for readiness
```powershell
docker compose logs postgres --tail=100
docker compose logs n8n --tail=100
```

### Test PostgreSQL connectivity and schema
```powershell
# List tables
docker compose exec -T postgres psql -U n8n -d n8n -c "\\dt"

# Check metadata row
docker compose exec -T postgres psql -U n8n -d n8n -c "SELECT * FROM app_metadata;"
```

If you need to apply the schema manually (existing volume):
```powershell
docker cp 01_initial_schema.sql $(docker compose ps -q postgres):/01_initial_schema.sql
docker compose exec -T postgres psql -U n8n -d n8n -f /01_initial_schema.sql
```

### Test n8n UI
- Open http://localhost:5678
- Log in with credentials in `.env`
- Create a tiny workflow and save it (verifies DB persistence)

---

## 6) Troubleshooting Quick Wins
- “n8n can’t connect to DB”: ensure DB host is `postgres`, not `localhost`. Check postgres logs.
- “Port in use”: find and stop the conflicting process or change the host port.
- “Schema didn’t create”: auto-init only runs on a fresh volume. Apply manually or recreate the volume.

---

## 7) Key Lessons
- Rely on Docker service names for inter-container networking.
- Use named volumes to persist data and auto-init scripts for first-time setup.
- Publish ports only when host access is needed; containers can talk internally without exposing ports.
- Validate with `docker compose config -q` and healthchecks before testing the app.
