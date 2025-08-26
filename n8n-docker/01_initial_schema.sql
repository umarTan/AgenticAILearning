-- Initial database schema for Agentic AI Lead Enrichment System
-- This file is executed automatically by the Postgres container on first startup
-- using /docker-entrypoint-initdb.d/*.sql

-- Enable pgcrypto before using gen_random_uuid
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'
    ) THEN
        CREATE EXTENSION pgcrypto;
    END IF;
END$$;

-- Note: n8n manages its own internal tables. These are app-specific tables
-- for lead ingestion/enrichment you can use from n8n workflows.

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

-- Enrichment results per lead and run
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

-- Simple index to speed up lookups
CREATE INDEX IF NOT EXISTS idx_lead_enrichment_lead_id ON lead_enrichment(lead_id);

-- Basic view for quick reporting
CREATE OR REPLACE VIEW v_lead_latest_enrichment AS
SELECT le.lead_id,
       max(le.created_at) AS last_enriched_at,
       (ARRAY_AGG(le.output_json ORDER BY le.created_at DESC))[1] AS latest_output,
       (ARRAY_AGG(le.score ORDER BY le.created_at DESC))[1] AS latest_score
FROM lead_enrichment le
GROUP BY le.lead_id;

-- Touch a metadata table for simple health check
CREATE TABLE IF NOT EXISTS app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO app_metadata(key, value)
VALUES ('schema_version', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
