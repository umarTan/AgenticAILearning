# Week 0 Step-by-Step Implementation Tasks

## 🚀 Quick Start Commands

### Task 1: Docker Environment Setup
```powershell
# Navigate to project directory
cd "d:\Qaariah\AgenticAI\n8n-docker"

# Create required Docker volumes
docker volume create n8n_data
docker volume create postgres_data

# Verify volumes created
docker volume ls

# Make init script executable (if using Git Bash)
# chmod +x init-data.sh
```

### Task 2: Configure Environment Variables
```powershell
# Copy example environment file
copy .env.example .env

# Edit .env file with your preferred text editor
notepad .env
```

**Required Changes in .env file:**
1. Replace all password placeholders with strong passwords
2. Generate a 32-character encryption key for N8N_ENCRYPTION_KEY
3. Set your timezone in GENERIC_TIMEZONE
4. Update email addresses for pgAdmin

### Task 3: Start n8n Services
```powershell
# Start all services in detached mode
docker compose up -d

# Check service status
docker compose ps

# View logs (optional)
docker compose logs -f n8n
docker compose logs -f postgres
```

### Task 4: Verify n8n Installation
1. **Open your browser** and navigate to: `http://localhost:5678`
2. **Login** with credentials from your .env file:
   - Username: `admin` (or your N8N_BASIC_AUTH_USER)
   - Password: Your N8N_BASIC_AUTH_PASSWORD
3. **Complete setup wizard** and create your first workflow

### Task 5: Test Database Connection
```powershell
# Connect to PostgreSQL container
docker compose exec postgres psql -U n8n -d n8n

# Run test query
\dt

# Exit PostgreSQL
\q
```

### Task 6: Install Ollama for Local AI
```powershell
# Download and install Ollama
# Visit: https://ollama.ai/download
# Or use winget (if available)
winget install Ollama.Ollama

# Start Ollama service
ollama serve

# In a new PowerShell window, pull Phi-3 model
ollama pull phi3:mini

# Verify model installation
ollama list
```

### Task 7: Test AI Integration in n8n

Follow these steps to call your local Ollama server from n8n and verify the AI response end-to-end.

1) Prerequisites (on Windows host)
```powershell
# Ollama service responding?
Test-NetConnection -ComputerName localhost -Port 11434

# Ensure model is available
ollama list
# If not present, install (one-time)
ollama pull phi3:mini
```

2) Create a new workflow in n8n
- Open http://localhost:5678
- Click New → Add node → “HTTP Request”

3) Configure HTTP Request node (Ollama Generate)
- Method: POST
- URL: http://host.docker.internal:11434/api/generate
- Headers:
  - Content-Type: application/json
- Body (JSON):
```json
{
  "model": "phi3:mini",
  "prompt": "Say hi in one short sentence.",
  "stream": false
}
```
- Send: Body
- Response: JSON

4) Execute the node
- Click “Execute node” and wait for the result pane.
- Expected: A JSON object containing fields like `response`, `model`, and timing information. The `response` should be a short greeting.

5) Optional: Store result for later use
- Add a “Set” node after the HTTP node to pick `response` into a field such as `ai_message`.
- Or add a “Postgres” node to insert the response into the `lead_enrichment` table (if you applied the optional schema).

6) Troubleshooting tips
- Connection refused from n8n: Ensure Docker Desktop is running and `host.docker.internal:11434` works from inside Docker. You can test from a one-off container:
  ```powershell
  docker run --rm --network n8n_network curlimages/curl:8.9.1 -s http://host.docker.internal:11434/api/version
  ```
- Model not found: Run `ollama pull phi3:mini` then retry the node.
- Empty/long responses: Add options in body (e.g., `"temperature": 0.3`, `"max_tokens": 100`) to control style/length:
  ```json
  {
    "model": "phi3:mini",
    "prompt": "Summarize this in one sentence: Hello, how are you?",
    "stream": false,
    "options": { "temperature": 0.3, "num_predict": 100 }
  }
  ```

### Task 8: Create GitHub Repository
```powershell
# Initialize git repository (if not already done)
cd "d:\Qaariah\AgenticAI"
git init

# Create .gitignore file
@"
# Environment files
*.env
!*.env.example

# Docker volumes
docker-data/

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/

# Logs
*.log
logs/

# Node modules (if any)
node_modules/
"@ | Out-File -FilePath .gitignore -Encoding utf8

# Add files to git
git add .
git commit -m "Initial commit: Week 0 setup complete"

# Create GitHub repository (via GitHub CLI or web interface)
# gh repo create AgenticAI-LeadEnrichment --public
```

## 🔍 Verification Checklist

### ✅ Docker Services Running
- [ ] n8n container is running on port 5678
- [ ] PostgreSQL container is running on port 5432
- [ ] All containers show "healthy" status

### ✅ n8n Web Interface Access
- [ ] Can access http://localhost:5678
- [ ] Can login with configured credentials
- [ ] Can create and execute test workflow

### ✅ Database Connectivity
- [ ] n8n can connect to PostgreSQL
- [ ] Database tables are created automatically
- [ ] Can query database directly

### ✅ AI Integration Ready
- [ ] Ollama is installed and running
- [ ] Phi-3 model is downloaded and available
- [ ] Can make API calls from n8n to Ollama

### ✅ Development Environment
- [ ] Git repository initialized
- [ ] .gitignore configured properly
- [ ] All documentation files created

## 🛠️ Troubleshooting Commands

### Check Docker Status
```powershell
# View running containers
docker ps

# Check container logs
docker compose logs [service-name]

# Restart services
docker compose restart

# Stop all services
docker compose down

# Complete cleanup (removes volumes - BE CAREFUL!)
docker compose down -v
```

### Database Issues
```powershell
# Reset database volume
docker compose down
docker volume rm postgres_data
docker volume create postgres_data
docker compose up -d
```

### Port Conflicts
```powershell
# Check what's using port 5678
netstat -an | findstr :5678

# Kill process using port (if needed)
# Get PID from netstat and use:
# taskkill /PID [PID_NUMBER] /F
```

## 📊 Performance Monitoring

### Resource Usage
```powershell
# Monitor Docker resource usage
docker stats

# Check disk usage
docker system df

# Clean up unused resources
docker system prune -f
```

## 🎯 Success Metrics

After completing all tasks, you should have:
1. **Functional n8n instance** running on Docker
2. **PostgreSQL database** with persistent storage
3. **Local AI model** (Phi-3) ready for inference
4. **Version-controlled project** with proper documentation
5. **Test workflow** demonstrating AI integration

## 📝 Next Steps

Once Week 0 is complete:
1. **Explore n8n nodes** and workflow patterns
2. **Set up data sources** for lead information
3. **Create enrichment templates** using AI
4. **Begin Week 1** of the masterplan

---
*Total estimated time: 2-3 hours for complete setup*
