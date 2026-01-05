# gs-n8n-jira-postgres-observability

[![Docker](https://img.shields.io/badge/Docker-Engine-blue)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)
[![n8n](https://img.shields.io/badge/n8n-Workflow%20Automation-orange)](https://n8n.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)](https://www.postgresql.org/)
[![Jira](https://img.shields.io/badge/Jira-Cloud-0052CC)](https://www.atlassian.com/software/jira)
[![Google Sheets](https://img.shields.io/badge/Google-Sheets-34A853)](https://www.google.com/sheets/about/)
[![Grafana](https://img.shields.io/badge/Grafana-OSS-orange)](https://grafana.com/oss/grafana/)
[![Prometheus](https://img.shields.io/badge/Prometheus-Metrics-E6522C)](https://prometheus.io/)
[![Loki](https://img.shields.io/badge/Loki-Logs-F46800)](https://grafana.com/oss/loki/)
[![Promtail](https://img.shields.io/badge/Promtail-Log%20Shipper-F46800)](https://grafana.com/docs/loki/latest/send-data/promtail/)

A dockerised reference stack that demonstrates a pragmatic **workflow automation + audit logging + observability** pattern using:

- **Google Sheets** as a lightweight intake/source-of-truth for work items
- **n8n** as the orchestration engine
- **Jira** as the delivery system of record
- **Postgres** as an append-friendly audit ledger (`sync_log`)
- **Grafana OSS + Prometheus + Loki** for open-source observability

---

## Blog-style overview

Most teams start workflow automation by “just connecting systems”: a spreadsheet feeds tickets, tickets feed dashboards, and everyone hopes it stays consistent. In reality, automation without **traceability** becomes brittle: when an update does not create a Jira issue, you need to answer **what happened**, **when**, **why**, and **what data was involved**.

This project solves that by treating workflow executions as first-class operational data. Every Google Sheets change that triggers a Jira action is captured into Postgres as a structured log event—complete with an execution identifier, timing, outcome status, and a JSON dump of the Jira payload. On top of that, the stack ships metrics and logs to an open-source observability platform, so you can monitor automation health like you would any production service.

---

## Problem statement

**How can we reliably convert Google Sheets updates into Jira tickets while maintaining an auditable, observable history of every workflow execution?**

Key requirements addressed:

1. **Event-driven**: react to updates in a Google Sheet
2. **Workflow orchestration**: create Jira issues from the row content
3. **Audit logging**: write an immutable-ish log record to Postgres per execution
4. **Operational visibility**: expose workflow metrics and logs via Grafana/Prometheus/Loki

---

## What the workflow does

Workflow file: `n8n/workflows/sheets_to_Jira_To_Postgres.json`

It:

1. **Listens for updates** to a Google Sheet (trigger)
2. Uses row values to **create a Jira ticket**
3. Writes a log record into Postgres `sync_log` including:
   - `execution_id` (used as the **primary key**)
   - source (Google Sheets)
   - action (e.g., `create_jira_issue`)
   - status (e.g., `SUCCESS` / `FAILED`)
   - execution time / duration (seconds or ms, depending on your implementation)
   - a JSON dump of the created Jira issue payload
4. Inserts the record into the `sync_log` table

---

## Project tree

```text
gs-n8n-jira-postgres-observability/
├─ docker-compose.yml
├─ .env.example
├─ Makefile
├─ README.md
├─ db/
│  └─ init/
│     └─ 001_init.sql
├─ n8n/
│  └─ workflows/
│     └─ sheets_to_Jira_To_Postgres.json
└─ observability/
   ├─ grafana/
   │  └─ provisioning/
   │     ├─ datasources/
   │     │  └─ datasources.yml
   │     └─ dashboards/
   │        ├─ dashboards.yml
   │        └─ workflow-health.json
   ├─ loki/
   │  └─ config.yml
   ├─ promtail/
   │  └─ config.yml
   ├─ prometheus/
   │  └─ prometheus.yml
   └─ logs/
      └─ n8n/
         └─ (runtime logs)
```

---

## Technology stack

### Core workflow components

- **Google Sheets**
  - Human-friendly intake layer and lightweight “queue”
  - Enables non-technical users to submit/modify work items

- **n8n**
  - Workflow automation/orchestration engine (triggers, nodes, error handling)
  - Executes the integration logic: Sheets → Jira → Postgres

- **Jira (Cloud or Server/DC, depending on your node/credentials)**
  - System of record for delivery tracking, SLA, and assignment workflows

- **Postgres**
  - Durable audit/ledger store (queryable, indexable, joinable)
  - Stores the `sync_log` entries for reporting and troubleshooting

### Observability components (open-source)

- **Prometheus**
  - Scrapes metrics from n8n (and optionally Postgres exporter)

- **Loki**
  - Log store optimised for label-based indexing (pairs well with Grafana)

- **Promtail**
  - Ships n8n log files into Loki

- **Grafana OSS**
  - Dashboards + Explore for metrics and logs
  - Provides quick operational visibility into workflow health

---

## Dataset description

### Input dataset (Google Sheet)

A Google Sheet tab (e.g., `WorkItems`) acts as the dataset. Typical columns include:

- `external_id` (row key or business key)
- `summary` / `title`
- `description`
- `jira_project_key`
- `issue_type`
- optional fields (priority, labels, reporter, assignee, etc.)

### Output dataset (Postgres: `sync_log`)

The `sync_log` table is the operational dataset produced by the workflow.

**Conceptual fields** (your exact schema may vary):

- `execution_id` (PRIMARY KEY) — n8n execution identifier
- `source` — e.g., `google_sheets`
- `action` — e.g., `create_jira_issue`
- `status` — e.g., `SUCCESS` / `FAILED`
- `execution_time_ms` or `duration_ms`
- `details` (JSONB) — JSON dump of Jira issue response (key, id, fields, URLs, etc.)
- `created_at` timestamp

This dataset enables:
- incident-style troubleshooting (“why didn’t row X create a ticket?”)
- auditability (“what was created, when, and by which run?”)
- downstream reporting (ticket throughput, failure rates, latency)

---

## Who can benefit from this project

- **Cloud/Platform Engineers** who want a reference pattern for automation + observability
- **SRE/Observability Engineers** who want to instrument workflow engines like production services
- **Data Engineers / Analytics Engineers** who need structured operational logs for reporting
- **ITSM / Service Management** teams integrating intake sources with Jira
- **Solution Architects** creating repeatable integration blueprints

---

## How to clone and run

### Prerequisites

- Docker Engine + Docker Compose plugin
- A Jira instance + credentials (API token recommended for Jira Cloud)
- A Google Sheet you control + Google OAuth credentials for n8n

### Clone

```bash
git clone <YOUR_REPO_URL>.git
cd gs-n8n-jira-postgres-observability
```

### Configure environment

```bash
cp .env.example .env
```

Update at minimum:
- `POSTGRES_PASSWORD`
- `N8N_BASIC_AUTH_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`

### Start the stack

Using Make:

```bash
make up
```

Or directly:

```bash
docker compose up -d --remove-orphans
```

### Open the UIs

- n8n: `http://localhost:5678`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

---

## n8n setup: importing the workflow and configuring credentials

### Import workflow

1. In n8n UI: **Workflows → Import from file**
2. Import: `n8n/workflows/sheets_to_Jira_To_Postgres.json`

### Configure credentials (required)

You must configure these credentials in n8n and then select them in the workflow nodes:

1. **Google Sheets OAuth2**
   - Used by the Google Sheets trigger/read nodes
2. **Jira**
   - Used to create issues
3. **Postgres**
   - Used to insert into `sync_log`

Important networking note:
- In the Postgres credential **Host** field, use `postgres` (Docker service name) or `wf-postgres` (container name), not `localhost`.

---

## Sample Grafana dashboard: import steps

A sample dashboard JSON is included:

- `observability/grafana/provisioning/dashboards/workflow-health.json`

### Option A: Use provisioning (recommended)
If you kept the provisioning directory mounted in `docker-compose.yml`, Grafana will auto-load it.

1. Start the stack (`make up`)
2. Login to Grafana
3. Navigate to **Dashboards** and look for **Workflow Stack - Health Overview**

### Option B: Import via Grafana UI
1. Open Grafana: `http://localhost:3000`
2. **Dashboards → New → Import**
3. Upload `workflow-health.json`
4. When prompted, map datasources:
   - Prometheus → `Prometheus`
   - Loki → `Loki`
5. Click **Import**

---

## Postgres: useful commands

> The examples below assume:
> - container name: `wf-postgres`
> - user: `wf_user`
> - db: `wf_db`

### Test connectivity

```bash
docker exec -it wf-postgres psql -U wf_user -d wf_db -c "select now();"
```

### List tables

```bash
docker exec -it wf-postgres psql -U wf_user -d wf_db -c "\dt"
```

### Inspect the `sync_log` table definition

```bash
docker exec -it wf-postgres psql -U wf_user -d wf_db -c "\d+ sync_log"
```

### Query recent logs

```bash
docker exec -it wf-postgres psql -U wf_user -d wf_db -c "select * from sync_log order by created_at desc limit 20;"
```

### Count executions by status (example)

```bash
docker exec -it wf-postgres psql -U wf_user -d wf_db -c "select status, count(*) from sync_log group by status order by count(*) desc;"
```

---

## Operational notes / best practices

- Do not use `runIndex+1` as a primary key. Use an execution identifier (e.g., `{$execution.id}`) or let Postgres generate a surrogate key.
- Treat workflows as production assets:
  - version-control workflow JSON
  - log failures with structured fields
  - monitor latency and failure rates in Grafana

---

## License

Choose a license appropriate for your repository (e.g., MIT, Apache-2.0).

---

*Last updated: 2026-01-05*
