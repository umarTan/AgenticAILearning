# Week 1 Integration Tests

## 🧪 Test Overview
This document provides comprehensive tests to verify Week 1 implementations are working correctly. All tests should pass before proceeding to Week 2.

## 🔧 Pre-Test Setup
```powershell
# Ensure all services are running
cd "d:\Qaariah\AgenticAI\n8n-docker"
docker compose up -d

# Wait for services to be ready
Start-Sleep 10

# Verify service status
docker compose ps
```

## Test Suite 1: Infrastructure Validation

### Test 1.1: Service Health Check
```powershell
# Test n8n accessibility
$n8nHealth = try { 
  Invoke-RestMethod -Uri "http://localhost:5678" -TimeoutSec 5
  "✅ PASS"
} catch { "❌ FAIL: $_" }
Write-Host "n8n Service: $n8nHealth"

# Test PostgreSQL connectivity
$pgHealth = try {
  docker compose exec -T postgres psql -U n8n -d n8n -c "SELECT 1;" -q
  "✅ PASS"
} catch { "❌ FAIL: $_" }
Write-Host "PostgreSQL Service: $pgHealth"

# Test Ollama connectivity
$ollamaHealth = try {
  Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 5
  "✅ PASS"
} catch { "❌ FAIL: $_" }
Write-Host "Ollama Service: $ollamaHealth"
```

### Test 1.2: Database Schema Validation
```sql
-- Run in PostgreSQL (docker compose exec -T postgres psql -U n8n -d n8n)
-- Test table existence
SELECT 
  tablename,
  CASE WHEN tablename IN ('leads', 'lead_enrichment', 'prompt_experiments') THEN '✅ EXISTS' 
       ELSE '❌ MISSING' END as status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('leads', 'lead_enrichment', 'prompt_experiments')
ORDER BY tablename;

-- Test table permissions
SELECT 
  table_name,
  CASE WHEN has_table_privilege('n8n', table_name, 'INSERT,SELECT,UPDATE,DELETE') 
       THEN '✅ FULL ACCESS' 
       ELSE '❌ LIMITED ACCESS' END as permissions
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('leads', 'lead_enrichment', 'prompt_experiments');
```

**Expected Results:**
- All custom tables should exist
- User 'n8n' should have full access to all tables

## Test Suite 2: AI Model Integration

### Test 2.1: Direct Ollama Communication
```powershell
# Simple generation test
$basicTest = @{
    model = "phi3:mini"
    prompt = "Say hello in exactly 3 words"
    stream = $false
    options = @{
        temperature = 0.1
        num_predict = 10
    }
} | ConvertTo-Json -Depth 3

$response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $basicTest -ContentType "application/json"
Write-Host "Basic Generation Test: $($response.response.Trim())"
```

### Test 2.2: JSON Structure Test
```powershell
# Test structured JSON response
$jsonTest = @{
    model = "phi3:mini"
    prompt = @"
Respond with valid JSON only, no other text:
{
  "test": "successful",
  "number": 42,
  "array": ["item1", "item2"]
}
"@
    stream = $false
    options = @{
        temperature = 0.1
        num_predict = 100
    }
} | ConvertTo-Json -Depth 3

$jsonResponse = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST -Body $jsonTest -ContentType "application/json"

# Validate JSON response
try {
    $parsed = $jsonResponse.response | ConvertFrom-Json
    Write-Host "✅ JSON Structure Test: Valid JSON returned"
    Write-Host "  - Test field: $($parsed.test)"
    Write-Host "  - Number field: $($parsed.number)"
    Write-Host "  - Array length: $($parsed.array.Count)"
} catch {
    Write-Host "❌ JSON Structure Test: Invalid JSON - $($_)"
    Write-Host "Raw response: $($jsonResponse.response)"
}
```

**Expected Results:**
- Basic generation returns 3-word response
- JSON test returns valid, parseable JSON

## Test Suite 3: n8n Workflow Tests

### Test 3.1: Webhook Connectivity Test
```powershell
# Test webhook endpoint accessibility (assuming webhook is set up)
try {
    $webhookTest = @{
        test_field = "connectivity_check"
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json

    $webhookResponse = Invoke-RestMethod -Uri "http://localhost:5678/webhook/test" -Method POST -Body $webhookTest -ContentType "application/json" -TimeoutSec 10
    Write-Host "✅ Webhook Test: Connection successful"
} catch {
    Write-Host "❌ Webhook Test: $($_)"
    Write-Host "Note: If webhook doesn't exist yet, this is expected"
}
```

### Test 3.2: Lead Qualification End-to-End Test
```powershell
# Complete lead qualification test
$leadTestData = @{
    company_name = "TestCorp Inc"
    website = "https://testcorp.example.com"
    employee_count = 150
    industry = "Software"
    description = "B2B SaaS platform providing project management solutions for mid-market companies"
} | ConvertTo-Json -Depth 3

try {
    $qualificationResult = Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $leadTestData -ContentType "application/json" -TimeoutSec 30
    
    Write-Host "✅ Lead Qualification Test: Workflow completed"
    Write-Host "  - Company: $($qualificationResult.qualification.company)"
    Write-Host "  - Score: $($qualificationResult.qualification.score)"
    Write-Host "  - Next Action: $($qualificationResult.qualification.next_action)"
    Write-Host "  - Processing Time: $($qualificationResult.metadata.processing_time)ms"
    
    # Validate response structure
    $isValid = (
        $qualificationResult.qualification.score -is [int] -and
        $qualificationResult.qualification.score -ge 0 -and
        $qualificationResult.qualification.score -le 100 -and
        $qualificationResult.qualification.reasons.Count -gt 0 -and
        $qualificationResult.qualification.next_action -in @('qualify', 'nurture', 'disqualify', 'research')
    )
    
    if ($isValid) {
        Write-Host "✅ Response Validation: Structure is correct"
    } else {
        Write-Host "❌ Response Validation: Structure issues detected"
    }
    
} catch {
    Write-Host "❌ Lead Qualification Test: $($_)"
}
```

### Test 3.3: Database Integration Test
```sql
-- Run in PostgreSQL to verify data was stored
-- docker compose exec -T postgres psql -U n8n -d n8n
SELECT 
    lead_id,
    model,
    (output_json->>'score')::numeric as score,
    output_json->>'next_action' as next_action,
    created_at
FROM lead_enrichment 
ORDER BY created_at DESC 
LIMIT 5;

-- Check for test data
SELECT COUNT(*) as test_records
FROM lead_enrichment 
WHERE lead_id LIKE 'TestCorp Inc%';
```

**Expected Results:**
- At least one record should exist with TestCorp data
- Score should be between 0-100
- Next_action should be one of the valid options

## Test Suite 4: JSON Validation & Error Handling

### Test 4.1: Malformed Input Handling
```powershell
# Test with missing required fields
$incompleteData = @{
    company_name = "Incomplete Corp"
    # Missing other required fields
} | ConvertTo-Json

try {
    $incompleteResult = Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $incompleteData -ContentType "application/json" -TimeoutSec 20
    Write-Host "✅ Incomplete Input Test: Handled gracefully"
    Write-Host "  - Score: $($incompleteResult.qualification.score)"
    Write-Host "  - Success: $($incompleteResult.success)"
} catch {
    Write-Host "❌ Incomplete Input Test: $($_)"
}
```

### Test 4.2: JSON Schema Compliance
```powershell
# Test that responses match expected schema
$schemaTest = @{
    company_name = "Schema Test Corp"
    website = "https://schematest.com"
    employee_count = 50
    industry = "Testing"
    description = "A company specifically for testing JSON schema compliance"
} | ConvertTo-Json

try {
    $schemaResult = Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $schemaTest -ContentType "application/json" -TimeoutSec 20
    
    # Validate all required fields exist and have correct types
    $validations = @{
        "score is number" = ($schemaResult.qualification.score -is [int] -or $schemaResult.qualification.score -is [double])
        "score in range" = ($schemaResult.qualification.score -ge 0 -and $schemaResult.qualification.score -le 100)
        "reasons is array" = ($schemaResult.qualification.reasons -is [array])
        "reasons not empty" = ($schemaResult.qualification.reasons.Count -gt 0)
        "next_action valid" = ($schemaResult.qualification.next_action -in @('qualify', 'nurture', 'disqualify', 'research'))
        "confidence exists" = ($null -ne $schemaResult.qualification.confidence)
    }
    
    $passCount = 0
    foreach ($validation in $validations.GetEnumerator()) {
        if ($validation.Value) {
            Write-Host "✅ $($validation.Key)"
            $passCount++
        } else {
            Write-Host "❌ $($validation.Key)"
        }
    }
    
    Write-Host "`nSchema Validation: $passCount/$($validations.Count) tests passed"
    
} catch {
    Write-Host "❌ Schema Test: $($_)"
}
```

## Test Suite 5: Performance & Reliability

### Test 5.1: Response Time Test
```powershell
# Test response times with multiple requests
$responseTimes = @()
$testData = @{
    company_name = "Performance Test Corp"
    website = "https://perftest.com"
    employee_count = 200
    industry = "Technology"
    description = "Testing response time performance for AI qualification pipeline"
} | ConvertTo-Json

for ($i = 1; $i -le 5; $i++) {
    $startTime = Get-Date
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $testData -ContentType "application/json" -TimeoutSec 30
        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalMilliseconds
        $responseTimes += $responseTime
        Write-Host "Request $i`: $($responseTime)ms"
    } catch {
        Write-Host "Request $i`: FAILED - $($_)"
    }
}

if ($responseTimes.Count -gt 0) {
    $avgTime = ($responseTimes | Measure-Object -Average).Average
    $maxTime = ($responseTimes | Measure-Object -Maximum).Maximum
    $minTime = ($responseTimes | Measure-Object -Minimum).Minimum
    
    Write-Host "`nPerformance Summary:"
    Write-Host "  Average: $([math]::Round($avgTime, 2))ms"
    Write-Host "  Min: $([math]::Round($minTime, 2))ms"
    Write-Host "  Max: $([math]::Round($maxTime, 2))ms"
    
    if ($avgTime -lt 5000) {
        Write-Host "✅ Performance: Average under 5 seconds"
    } else {
        Write-Host "❌ Performance: Average over 5 seconds"
    }
}
```

### Test 5.2: JSON Validity Rate Test
```powershell
# Test JSON validity across multiple runs
$jsonValidTests = 0
$jsonValidPasses = 0

$testCompanies = @(
    @{ name = "Tech Innovators LLC"; industry = "Technology"; employees = 75 },
    @{ name = "Manufacturing Solutions Inc"; industry = "Manufacturing"; employees = 300 },
    @{ name = "Healthcare Analytics Corp"; industry = "Healthcare"; employees = 150 },
    @{ name = "Financial Services Group"; industry = "Finance"; employees = 500 },
    @{ name = "Retail Dynamics Ltd"; industry = "Retail"; employees = 1200 }
)

foreach ($company in $testCompanies) {
    $testPayload = @{
        company_name = $company.name
        industry = $company.industry
        employee_count = $company.employees
        description = "Testing JSON validity with $($company.name)"
    } | ConvertTo-Json

    $jsonValidTests++
    try {
        $result = Invoke-RestMethod -Uri "http://localhost:5678/webhook/qualify-lead" -Method POST -Body $testPayload -ContentType "application/json" -TimeoutSec 25
        
        # Check if response structure is valid
        if ($result.qualification.score -is [int] -and 
            $result.qualification.reasons.Count -gt 0 -and
            $result.qualification.next_action -in @('qualify', 'nurture', 'disqualify', 'research')) {
            $jsonValidPasses++
            Write-Host "✅ $($company.name): Valid response"
        } else {
            Write-Host "❌ $($company.name): Invalid structure"
        }
    } catch {
        Write-Host "❌ $($company.name): Request failed - $($_)"
    }
}

$validityRate = if ($jsonValidTests -gt 0) { ($jsonValidPasses / $jsonValidTests) * 100 } else { 0 }
Write-Host "`nJSON Validity Rate: $([math]::Round($validityRate, 1))% ($jsonValidPasses/$jsonValidTests)"

if ($validityRate -ge 95) {
    Write-Host "✅ JSON Validity: Meets 95% target"
} else {
    Write-Host "❌ JSON Validity: Below 95% target"
}
```

## Test Suite 6: Data Persistence & Audit Trail

### Test 6.1: Database Logging Verification
```sql
-- Run this in PostgreSQL to verify comprehensive logging
-- docker compose exec -T postgres psql -U n8n -d n8n

-- Check recent enrichment records
SELECT 
    lead_id,
    model,
    (output_json->>'score')::numeric as score,
    output_json->>'next_action' as action,
    CASE WHEN output_json->>'is_valid' = 'true' THEN '✅ Valid' ELSE '❌ Invalid' END as validity,
    created_at
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- Calculate success metrics from recent data
SELECT 
    COUNT(*) as total_requests,
    COUNT(CASE WHEN (output_json->>'is_valid')::boolean THEN 1 END) as valid_responses,
    ROUND(AVG((output_json->>'score')::numeric), 2) as avg_score,
    ROUND(AVG((output_json->>'processing_time')::numeric), 2) as avg_processing_time_ms
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '1 hour';

-- Check for experiment tracking (if A/B testing implemented)
SELECT 
    experiment_name,
    prompt_variant,
    COUNT(*) as requests,
    AVG(score_given) as avg_score,
    AVG(response_time_ms) as avg_response_time
FROM prompt_experiments 
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY experiment_name, prompt_variant;
```

**Expected Results:**
- All test requests should be logged in lead_enrichment table
- Valid response rate should be >95%
- Average scores should be reasonable (20-80 range)
- Processing times should be <5000ms

## Test Suite 7: Workflow Export & Import Test

### Test 7.1: Workflow Export Verification
```powershell
# Check if workflow files exist
$workflowPath = "d:\Qaariah\AgenticAI\n8n-docker\workflows"

$expectedWorkflows = @(
    "lead-qualification-v1.json",
    "data-extraction-v1.json",
    "prompt-ab-testing-v1.json"
)

foreach ($workflow in $expectedWorkflows) {
    $filePath = Join-Path $workflowPath $workflow
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length
        Write-Host "✅ $workflow exists ($fileSize bytes)"
        
        # Validate JSON structure
        try {
            $content = Get-Content $filePath -Raw | ConvertFrom-Json
            if ($content.nodes -and $content.connections) {
                Write-Host "  ✅ Valid n8n workflow structure"
            } else {
                Write-Host "  ❌ Invalid workflow structure"
            }
        } catch {
            Write-Host "  ❌ Invalid JSON format"
        }
    } else {
        Write-Host "❌ $workflow missing"
    }
}
```

## 🎯 Test Results Summary

After running all tests, you should see:

### ✅ Passing Criteria
- **All services healthy**: n8n, PostgreSQL, Ollama responding
- **Database integration working**: Tables exist with proper permissions
- **AI responses structured**: JSON validity rate >95%
- **Performance acceptable**: Average response time <5 seconds
- **Data persistence**: All requests logged with complete audit trail
- **Workflows exportable**: JSON files are valid and importable

### 🚨 Common Issues & Fixes

#### Issue: JSON Validity <95%
**Symptoms**: Malformed AI responses, parsing errors
**Fix**: 
```powershell
# Lower temperature for more consistent responses
# In Ollama HTTP request node, modify options:
{
  "temperature": 0.1,
  "num_predict": 200,
  "top_p": 0.9
}
```

#### Issue: Slow Response Times
**Symptoms**: >5 second average processing
**Fix**: 
- Reduce `num_predict` parameter in Ollama calls
- Optimize database queries with indexes
- Consider using smaller AI model

#### Issue: Database Connection Errors
**Symptoms**: Cannot insert/select from tables
**Fix**:
```sql
-- Reset permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
```

#### Issue: Webhook 404 Errors
**Symptoms**: n8n webhook endpoints not found
**Fix**: 
- Ensure workflows are saved and activated
- Check webhook path matches exactly
- Verify n8n service is fully started

## 📊 Success Metrics Dashboard

Create this simple monitoring query for ongoing validation:

```sql
-- Quick health check query
-- Run: docker compose exec -T postgres psql -U n8n -d n8n -c "..."

SELECT 
    'Total Requests (24h)' as metric,
    COUNT(*)::text as value
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'JSON Valid Rate (24h)' as metric,
    ROUND((COUNT(CASE WHEN (output_json->>'is_valid')::boolean THEN 1 END)::numeric / COUNT(*)) * 100, 1)::text || '%' as value
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'Avg Response Time (24h)' as metric,
    ROUND(AVG((output_json->>'processing_time')::numeric), 0)::text || 'ms' as value
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
    'Avg Score (24h)' as metric,
    ROUND(AVG((output_json->>'score')::numeric), 1)::text as value
FROM lead_enrichment 
WHERE created_at > NOW() - INTERVAL '24 hours';
```

---

## 🎉 Week 1 Completion Criteria

**All tests must pass before proceeding to Week 2:**

1. ✅ Infrastructure tests pass (services healthy)
2. ✅ AI integration working (structured responses)
3. ✅ n8n workflows functional (end-to-end processing)
4. ✅ JSON validation >95% success rate
5. ✅ Performance <5s average response time
6. ✅ Database logging complete (audit trail)
7. ✅ Workflows exported and documented

**If any test fails**, revisit the implementation steps in `WEEK_1_STEP_BY_STEP_TASKS.md` before continuing to Week 2.

*Total test execution time: ~30 minutes*
