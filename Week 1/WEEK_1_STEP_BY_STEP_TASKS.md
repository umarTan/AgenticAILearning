# Week 1 Step-by-Step Implementation Tasks

## 🚀 Quick Start Commands

### Task 1: Create Prompt Templates Directory
```powershell
# Navigate to project directory
cd "d:\Qaariah\AgenticAI"

# Create prompt templates structure
mkdir prompts
mkdir prompts\lead-qualification
mkdir prompts\data-extraction
mkdir prompts\schemas

# Create workflows export directory
mkdir n8n-docker\workflows
```

### Task 2: Design JSON Schemas
Create validation schemas for consistent AI outputs.

**Create file: `prompts/schemas/lead-qualification-schema.json`**
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["score", "reasons", "next_action"],
  "properties": {
    "score": {
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Lead quality score from 0-100"
    },
    "reasons": {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 1,
      "maxItems": 5,
      "description": "Key reasons for the score"
    },
    "risks": {
      "type": "array", 
      "items": {"type": "string"},
      "maxItems": 3,
      "description": "Potential risks or concerns"
    },
    "next_action": {
      "type": "string",
      "enum": ["qualify", "nurture", "disqualify", "research"],
      "description": "Recommended next step"
    },
    "confidence": {
      "type": "number",
      "minimum": 0,
      "maximum": 1,
      "description": "Confidence in assessment (0-1)"
    }
  }
}
```

### Task 3: Create Lead Qualification Prompt Template
**Create file: `prompts/lead-qualification/qualification-prompt-v1.txt`**
```
You are a B2B lead qualification expert. Analyze the following company and provide a structured assessment.

COMPANY DETAILS:
- Name: {{company_name}}
- Website: {{website || 'Not provided'}}
- Employee Count: {{employee_count || 'Unknown'}}
- Industry: {{industry || 'Unknown'}}
- Description: {{description || 'Not provided'}}

QUALIFICATION CRITERIA:
- Company size and growth potential
- Technology adoption likelihood  
- Budget probability
- Decision maker accessibility
- Strategic fit with our solution

RESPONSE FORMAT (JSON only, no other text):
{
  "score": <number 0-100>,
  "reasons": ["reason1", "reason2", "reason3"],
  "risks": ["risk1", "risk2"],
  "next_action": "qualify|nurture|disqualify|research",
  "confidence": <number 0-1>
}

Important: Respond with valid JSON only. No explanations outside the JSON structure.
```

### Task 4: Build Lead Qualification Workflow in n8n

1. **Open n8n interface**: http://localhost:5678
2. **Create new workflow**: "Lead Qualification Pipeline v1"
3. **Add nodes in sequence**:

#### Node 1: Webhook Trigger
- **Name**: "Lead Input Webhook"
- **HTTP Method**: POST
- **Path**: `/qualify-lead`
- **Response**: "Respond to Webhook"

#### Node 2: Set Variables
- **Name**: "Prepare Prompt Data"
- **Add these fields**:
```javascript
// Extract and validate input data
company_name: {{ $json.body.company_name || 'Unknown Company' }}
website: {{ $json.body.website || '' }}
employee_count: {{ $json.body.employee_count || 0 }}
industry: {{ $json.body.industry || '' }}
description: {{ $json.body.description || '' }}
timestamp: {{ new Date().toISOString() }}
```

#### Node 3: Template Prompt
- **Name**: "Build Qualification Prompt"  
- **Add field**:
```javascript
prompt: `You are a B2B lead qualification expert. Analyze the following company and provide a structured assessment.

COMPANY DETAILS:
- Name: {{ $('Prepare Prompt Data').item.json.company_name }}
- Website: {{ $('Prepare Prompt Data').item.json.website || 'Not provided' }}
- Employee Count: {{ $('Prepare Prompt Data').item.json.employee_count || 'Unknown' }}
- Industry: {{ $('Prepare Prompt Data').item.json.industry || 'Unknown' }}
- Description: {{ $('Prepare Prompt Data').item.json.description || 'Not provided' }}

QUALIFICATION CRITERIA:
- Company size and growth potential
- Technology adoption likelihood  
- Budget probability
- Decision maker accessibility
- Strategic fit with our solution

RESPONSE FORMAT (JSON only, no other text):
{
  "score": <number 0-100>,
  "reasons": ["reason1", "reason2", "reason3"],
  "risks": ["risk1", "risk2"],
  "next_action": "qualify|nurture|disqualify|research",
  "confidence": <number 0-1>
}

Important: Respond with valid JSON only. No explanations outside the JSON structure.`
```

#### Node 4: HTTP Request (Ollama)
- **Name**: "Call Ollama AI"
- **Method**: POST
- **URL**: `http://host.docker.internal:11434/api/generate`
- **Headers**: `Content-Type: application/json`
- **Body**:
```json
{
  "model": "phi3:mini",
  "prompt": "{{ $('Build Qualification Prompt').item.json.prompt }}",
  "stream": false,
  "options": {
    "temperature": 0.3,
    "num_predict": 300
  }
}
```

#### Node 5: Parse & Validate JSON
- **Name**: "Validate AI Response"
- **Code**:
```javascript
// Extract response text
const aiResponse = items[0].json.response;
const startTime = new Date();

try {
  // Parse JSON response
  const parsed = JSON.parse(aiResponse);
  
  // Validate required fields
  const isValid = (
    typeof parsed.score === 'number' &&
    parsed.score >= 0 && parsed.score <= 100 &&
    Array.isArray(parsed.reasons) &&
    parsed.reasons.length > 0 &&
    ['qualify', 'nurture', 'disqualify', 'research'].includes(parsed.next_action)
  );
  
  if (!isValid) {
    throw new Error('Invalid response structure');
  }
  
  return [{
    json: {
      ...parsed,
      is_valid: true,
      processing_time: Date.now() - startTime.getTime(),
      raw_response: aiResponse
    }
  }];
  
} catch (error) {
  // Return default response on parsing error
  return [{
    json: {
      score: 50,
      reasons: ['Unable to process - requires manual review'],
      risks: ['AI processing error'],
      next_action: 'research',
      confidence: 0.1,
      is_valid: false,
      error: error.message,
      raw_response: aiResponse,
      processing_time: Date.now() - startTime.getTime()
    }
  }];
}
```

#### Node 6: Store Results (Postgres)
- **Name**: "Log to Database"
- **Operation**: Insert
- **Table**: `lead_enrichment`
- **Columns**:
```json
{
  "lead_id": "{{ $('Prepare Prompt Data').item.json.company_name }}-{{ $('Prepare Prompt Data').item.json.timestamp }}",
  "run_id": "{{ $runIndex }}",
  "model": "phi3:mini",
  "input_json": "{{ $('Prepare Prompt Data').item.json }}",
  "output_json": "{{ $('Validate AI Response').item.json }}",
  "score": "{{ $('Validate AI Response').item.json.score }}"
}
```

#### Node 7: Return Response
- **Name**: "Format Response"
- **Code**:
```javascript
const result = items[0].json;
return [{
  json: {
    success: result.is_valid,
    qualification: {
      company: $('Prepare Prompt Data').item.json.company_name,
      score: result.score,
      reasons: result.reasons,
      risks: result.risks || [],
      next_action: result.next_action,
      confidence: result.confidence || 0.5
    },
    metadata: {
      processing_time: result.processing_time,
      timestamp: new Date().toISOString(),
      model_used: 'phi3:mini'
    }
  }
}];
```

### Task 5: Test Lead Qualification Workflow
```powershell
# Test the webhook with sample data
$testData = @{
    company_name = "TechCorp Inc"
    website = "https://techcorp.com"
    employee_count = 150
    industry = "Software"
    description = "B2B SaaS platform for project management"
} | ConvertTo-Json

# Send test request
Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $testData -ContentType "application/json"
```

### Task 6: Create Data Extraction Workflow

1. **Create new workflow**: "Data Extraction Pipeline v1"
2. **Follow similar pattern with different prompt**:

**Data Extraction Prompt Template**:
```
Extract structured information from this company description. Focus on key business details.

COMPANY DESCRIPTION:
{{raw_description}}

Extract the following information and respond with JSON only:
{
  "industry": "<primary industry>",
  "company_size": "startup|small|medium|large|enterprise",
  "tech_stack": ["technology1", "technology2"],
  "decision_makers": ["role1", "role2"],
  "key_challenges": ["challenge1", "challenge2"],
  "potential_solutions": ["solution1", "solution2"]
}

Guidelines:
- company_size: startup (<50), small (50-200), medium (200-1000), large (1000-5000), enterprise (5000+)
- Include only technologies explicitly mentioned
- Focus on business challenges, not technical ones
- Suggest realistic solutions based on company profile

Respond with valid JSON only.
```

### Task 7: Implement A/B Testing Framework

1. **Create new workflow**: "Prompt A/B Testing v1"
2. **Add traffic splitting logic**:

#### A/B Split Node (Code):
```javascript
// Simple 50/50 split based on timestamp
const timestamp = Date.now();
const variant = (timestamp % 2 === 0) ? 'A' : 'B';

return [{
  json: {
    ...items[0].json,
    experiment_variant: variant
  }
}];
```

#### Variant A Prompt (Original):
- Use the standard qualification prompt

#### Variant B Prompt (Enhanced):
- Add industry-specific qualification criteria
- Include more detailed scoring rubric
- Add competitive analysis questions

### Task 8: Set Up Performance Monitoring

**Create database table for experiments**:
```sql
-- Connect to database and run this SQL
-- From PowerShell:
docker compose exec -T postgres psql -U n8n -d n8n

CREATE TABLE IF NOT EXISTS prompt_experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  experiment_name VARCHAR(100) NOT NULL,
  prompt_variant VARCHAR(10) NOT NULL,
  company_input JSONB,
  ai_response JSONB,
  is_valid_json BOOLEAN,
  response_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  score_given NUMERIC(5,2)
);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE prompt_experiments TO n8n;

-- Exit database
\q
```

### Task 9: Export Workflows
```powershell
# In n8n interface:
# 1. Go to each workflow
# 2. Click Settings → Export
# 3. Save to n8n-docker/workflows/ directory
# 4. Name files: lead-qualification-v1.json, data-extraction-v1.json, etc.
```

## 🔍 Verification Checklist

### ✅ Workflows Created
- [ ] Lead Qualification Pipeline functional
- [ ] Data Extraction Pipeline working
- [ ] A/B Testing framework operational
- [ ] All workflows saved and exported

### ✅ JSON Validation Working
- [ ] Valid JSON response rate >95%
- [ ] Schema validation preventing malformed data
- [ ] Error handling providing fallback responses
- [ ] Response times logged and tracked

### ✅ Database Integration
- [ ] All results stored in lead_enrichment table
- [ ] Experiment data tracked in prompt_experiments
- [ ] Query performance acceptable (<1 second)
- [ ] Data integrity maintained

### ✅ Performance Targets
- [ ] Average response time <5 seconds
- [ ] JSON validity rate >95%
- [ ] Successful prompt completion >90%
- [ ] A/B test shows measurable difference

## 🛠️ Troubleshooting Commands

### Test Individual Components
```powershell
# Test Ollama directly
$testPrompt = @{
    model = "phi3:mini"
    prompt = "Return valid JSON with a score field containing number 85"
    stream = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $testPrompt -ContentType "application/json"

# Test database connection
docker compose exec -T postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM lead_enrichment;"

# Check n8n logs
docker compose logs n8n --tail=100
```

### Debugging Invalid JSON
- Check prompt template for extra text outside JSON
- Verify temperature setting (lower = more consistent)
- Add explicit JSON formatting instructions
- Implement JSON repair functions in code nodes

### Performance Optimization
- Cache common prompt templates
- Batch similar requests together
- Optimize Postgres queries with indexes
- Monitor and tune Ollama parameters

## 📊 Success Metrics

After completing all tasks, you should have:
1. **Three functional n8n workflows** processing lead data
2. **95%+ JSON validity rate** with proper error handling
3. **Sub-5-second response times** for qualification requests
4. **Complete audit trail** in database for all processing
5. **A/B testing framework** ready for prompt optimization

## 📝 Next Steps

Once Week 1 is complete:
1. **Week 2**: Add vector database (Qdrant) for RAG functionality
2. **Advanced Prompting**: Implement Chain-of-Thought reasoning
3. **Integration**: Connect to real CRM systems
4. **Monitoring**: Build performance dashboard

---
*Total estimated time: 8-12 hours for complete implementation*
