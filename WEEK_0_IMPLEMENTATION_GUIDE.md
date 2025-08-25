# Week 0 Implementation Guide: Agentic AI Lead Enrichment System

## 📋 Project Overview
This guide provides step-by-step instructions for setting up the foundational infrastructure for your Agentic AI Lead Enrichment System, focusing on cost-effective local deployment.

## 🎯 Week 0 Objectives
- ✅ Set up Docker-based n8n workflow automation platform
- ✅ Configure PostgreSQL database for persistent data storage
- ✅ Install and configure Ollama with Phi-3 model for local AI inference
- ✅ Create GitHub repository for version control
- ✅ Establish project architecture and documentation structure

## 📁 Project Structure
```
AgenticAI/
├── AGENTIC_AI_JOURNEY_MASTERPLAN_V2.md     # Master learning roadmap
├── WEEK_0_IMPLEMENTATION_GUIDE.md           # This file
├── Architecture-Documents/                  # System architecture docs
│   ├── n8n-system-design.md
│   ├── database-schema.md
│   └── ai-integration-architecture.md
├── Learning-Documents/                      # Learning resources & notes
│   ├── n8n-learning-path.md
│   ├── workflow-patterns.md
│   └── ai-prompt-engineering.md
└── n8n-docker/                             # Docker deployment files
    ├── docker-compose.yml
    ├── .env
    ├── .env.example
    └── local-files/                        # Shared volume for n8n
```

## 🛠️ Prerequisites

### System Requirements
- **Docker Desktop/Engine**: Latest version
- **Docker Compose**: v2.0+
- **Git**: For version control
- **PowerShell**: Windows terminal (pre-installed)
- **Available RAM**: Minimum 8GB (4GB for n8n + PostgreSQL + Ollama)
- **Storage**: 10GB+ free space

### Port Requirements
- **5678**: n8n web interface
- **5432**: PostgreSQL database
- **11434**: Ollama API server

## 📝 Step-by-Step Implementation

### Step 1: Verify Docker Installation
```powershell
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Test Docker functionality
docker run hello-world
```

### Step 2: Create Project Structure
Navigate to your project directory and ensure the folder structure is created:
```powershell
cd "d:\Qaariah\AgenticAI"
ls  # Verify all folders exist
```

### Step 3: Set Up n8n with Docker Compose
1. Navigate to n8n-docker directory
2. Create Docker Compose configuration
3. Set up environment variables
4. Start services

### Step 4: Configure PostgreSQL Database
- Set up persistent data storage
- Configure connection parameters
- Create initial database schema

### Step 5: Install Ollama + Phi-3
- Install Ollama locally
- Pull Phi-3 model for cost-effective AI inference
- Configure n8n integration

### Step 6: Initialize GitHub Repository
- Create new repository
- Set up initial commit
- Configure .gitignore

## 🔧 Configuration Files

### Docker Compose Configuration
Located in `n8n-docker/docker-compose.yml` - defines all services including n8n, PostgreSQL, and networking.

### Environment Variables
Located in `n8n-docker/.env` - contains all sensitive configuration including database credentials and n8n settings.

### Local Files Directory
Located in `n8n-docker/local-files/` - shared volume for workflow data exchange.

## 🧪 Verification Steps
After completing setup:
1. Access n8n interface at http://localhost:5678
2. Create first workflow
3. Test PostgreSQL connection
4. Verify Ollama model availability
5. Test AI inference in workflow

## 📚 Next Steps
- Complete Week 1: Basic workflow creation
- Learn n8n node types and patterns
- Set up lead data sources
- Create AI enrichment templates

## 🔗 Quick Links
- [n8n Documentation](https://docs.n8n.io/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [Ollama Documentation](https://ollama.ai/docs)

---
*This guide is part of the 8-week Agentic AI Lead Enrichment System development program.*
