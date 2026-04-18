# Local AI Email Auto-Responder

A fully private, self-hosted email auto-responder that reads incoming messages, generates contextual replies using a local large language model, and sends those replies — all without any data leaving your machine. Built with n8n for workflow automation and Ollama for on-device inference, orchestrated via Docker Compose.

---

## How It Works

When an email arrives at the configured inbox, n8n detects it through an IMAP connection. A loop-prevention check filters out messages sent by the auto-responder itself or already-tagged replies. For valid incoming emails, the content is formatted into a structured prompt and sent to the Ollama API running in an adjacent container. The model generates a reply, which n8n sends back to the original sender via SMTP with proper threading headers so the reply appears in the same conversation.

```
Incoming Email
      |
  IMAP Trigger (n8n)
      |
  Loop Prevention (IF Node)
      |
  Format Prompt (Set Node)
      |
  Ollama API Call (HTTP Request -- POST /api/generate)
      |
  Send Reply (SMTP with In-Reply-To threading)
```

---

## Architecture

| Component      | Role                                               | Technology            |
|----------------|----------------------------------------------------|-----------------------|
| n8n            | Workflow orchestration and email I/O               | n8nio/n8n (Docker)    |
| Ollama         | Local LLM inference server                         | ollama/ollama (Docker) |
| llama3:8b      | Language model for generating email replies        | Pulled at init time   |
| Docker Compose | Multi-service orchestration on a private network   | docker-compose.yml    |

Both containers run on a shared bridge network (`ai_responder_network`) so n8n can address Ollama directly by its service name without exposing ports externally.

---

## Prerequisites

- Docker Engine 24.0 or later
- Docker Compose v2.20 or later
- 8 GB RAM minimum (16 GB recommended for llama3:8b)
- A working email account with IMAP and SMTP access enabled (Gmail users must create an App Password)

---

## Setup

### Step 1 — Clone the repository

```bash
git clone https://github.com/gowthusaidatta/Local-AI-Email-Auto-Responder.git
cd Local-AI-Email-Auto-Responder
```

### Step 2 — Create your environment file

Copy the example file and fill in your real credentials:

```bash
cp .env.example .env
```

Open `.env` and replace every placeholder value with your actual email server settings. For Gmail, the IMAP host is `imap.gmail.com` on port 993, and the SMTP host is `smtp.gmail.com` on port 465. Your password must be an App Password generated from your Google account security settings. Store the 16-character password without spaces.

### Step 3 — Make the initialization script executable

```bash
chmod +x scripts/init-ollama.sh
```

### Step 4 — Start the services

```bash
docker compose up -d
```

This starts n8n and Ollama in detached mode. The `ollama-init` container runs once after Ollama is healthy and pulls the `llama3:8b` model automatically. The first pull requires several minutes depending on your connection speed. Watch the pull progress with:

```bash
docker logs ollama_init -f
```

### Step 5 — Verify both services are healthy

```bash
docker compose ps
```

Both `n8n_responder` and `ollama_responder` must show status `healthy` before proceeding. Allow up to three minutes after startup.

Confirm the model is available:

```bash
docker exec ollama_responder ollama list
```

You should see `llama3:8b` in the output.

---

## Importing the Workflow into n8n

### Step 1 — Open n8n

Navigate to `http://localhost:5678` in your browser.

### Step 2 — Import the workflow

Go to **Workflows** in the left sidebar, click **Add Workflow**, then select **Import from File**. Upload `workflow.json` from the root of this repository.

### Step 3 — Configure credentials

The workflow requires two credential entries.

**IMAP Account**

Go to **Settings → Credentials → Add Credential → IMAP**. Enter the following:

| Field    | Value                                |
|----------|--------------------------------------|
| Host     | imap.gmail.com                       |
| Port     | 993                                  |
| User     | your email address                   |
| Password | your 16-character App Password       |
| SSL      | Enabled                              |

**SMTP Account**

Go to **Settings → Credentials → Add Credential → SMTP**. Enter the following:

| Field    | Value                                |
|----------|--------------------------------------|
| Host     | smtp.gmail.com                       |
| Port     | 465                                  |
| User     | your email address                   |
| Password | your 16-character App Password       |
| SSL      | Enabled                              |

After saving both credentials, open the imported workflow and assign each credential to the correct node. Assign the IMAP credential to the **Email Read (IMAP)** node and the SMTP credential to the **Send Email** node.

### Step 4 — Activate the workflow

Click the toggle in the top right of the workflow editor to set it to **Active**. The workflow will now poll your inbox for new unread messages.

---

## Testing the System

Send an email from a different account to the configured inbox. Within one to two minutes you should receive a reply in the same conversation thread. The reply subject will be prefixed with `Re: AI Auto-Reply:`.

To verify loop prevention is working, send an email from the auto-responder address to itself. The workflow will trigger but stop at the IF node and send nothing.

To inspect executions, go to **Executions** in the n8n sidebar and click any execution to see the data at each node.

---

## Stopping the Services

```bash
docker compose down
```

Workflow data and downloaded models are stored in named Docker volumes (`n8n_responder_data` and `ollama_responder_data`) and persist across restarts.

---

## Environment Variables Reference

| Variable         | Description                                  | Example Value          |
|------------------|----------------------------------------------|------------------------|
| N8N_HOST         | Hostname for the n8n server                  | localhost              |
| N8N_PORT         | Port for the n8n web interface               | 5678                   |
| N8N_PROTOCOL     | Protocol for n8n                             | http                   |
| WEBHOOK_URL      | Full base URL for webhooks                   | http://localhost:5678/ |
| IMAP_HOST        | IMAP server hostname                         | imap.gmail.com         |
| IMAP_PORT        | IMAP server port                             | 993                    |
| IMAP_USER        | Email address for IMAP login                 | you@gmail.com          |
| IMAP_PASSWORD    | App Password for IMAP authentication         | 16characterpassword    |
| SMTP_HOST        | SMTP server hostname                         | smtp.gmail.com         |
| SMTP_PORT        | SMTP server port                             | 465                    |
| SMTP_USER        | Email address for SMTP login                 | you@gmail.com          |
| SMTP_PASSWORD    | App Password for SMTP authentication         | 16characterpassword    |
| OLLAMA_MODEL     | Name of the model used for inference         | llama3:8b              |
| OLLAMA_BASE_URL  | Internal URL to reach the Ollama service     | http://ollama:11434    |

---

## Security Notes

The `.env` file is excluded from version control via `.gitignore` and must never be committed. The `submission.json` file contains real credentials solely for evaluation purposes. Rotate your App Password after evaluation is complete by visiting `https://myaccount.google.com/apppasswords` and deleting the current entry.

---

## Troubleshooting

**n8n cannot connect to Ollama**

Confirm both containers are on `ai_responder_network`. The URL in the HTTP Request node must be `http://ollama:11434/api/generate` — not `localhost`. Run `docker network inspect ai_responder_network` to confirm both containers appear.

**Model not found error**

Run `docker exec ollama_responder ollama list` and confirm `llama3:8b` appears. If it does not, pull it manually with `docker exec ollama_responder ollama pull llama3:8b`.

**Workflow not triggering on new emails**

Confirm the workflow is set to Active in the n8n UI. Verify IMAP credentials are assigned to the Email Read node and that IMAP access is enabled in your Gmail settings at `https://mail.google.com` under Forwarding and POP/IMAP.

**Slow response times**

llama3:8b requires substantial compute. On a CPU-only machine, inference takes 30 to 90 seconds per email. The HTTP Request node has a 120-second timeout set to accommodate this.
