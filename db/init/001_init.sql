-- App schema used by n8n workflows
CREATE TABLE IF NOT EXISTS sync_log (
  id            BIGSERIAL PRIMARY KEY,
  source        TEXT NOT NULL,
  source_ref    TEXT,
  action        TEXT NOT NULL,
  status        TEXT NOT NULL,
  details       JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_log_created_at ON sync_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_log_source_ref ON sync_log (source, source_ref);

-- Optional: a table representing work items derived from Google Sheets
CREATE TABLE IF NOT EXISTS work_items (
  id            BIGSERIAL PRIMARY KEY,
  external_id   TEXT UNIQUE,
  title         TEXT NOT NULL,
  description   TEXT,
  jira_key      TEXT,
  status        TEXT NOT NULL DEFAULT 'NEW',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
