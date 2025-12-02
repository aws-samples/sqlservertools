# RDSMCP Use Cases

## Overview

RDSMCP can be used in two modes: **CLI Mode** for direct command-line operations and **MCP Mode** for AI-assisted workflows. This document outlines practical use cases for each mode.

---

## CLI Mode Use Cases

### Use Case 1: Quick Single Server Assessment

**Scenario:** You need to quickly assess if a single SQL Server can migrate to RDS.

**When to use:**
- Ad-hoc assessments
- Testing connectivity
- Quick compatibility checks

**Example:**
```powershell
# SQL Authentication
python cli.py analyze --host prod-sql-01.company.com --username sa --password MyPass123

# Windows Authentication
python cli.py analyze --host prod-sql-01.company.com --windows-auth
```

**Output:** JSON report showing RDS compatibility, blocking features, and instance recommendations.

---

### Use Case 2: Batch Assessment for Migration Planning

**Scenario:** You have 50+ SQL Servers across your organization and need a comprehensive migration assessment.

**When to use:**
- Large-scale migration projects
- Infrastructure audits
- Capacity planning
- Cost estimation

**Steps:**

1. Create server list (`servers.txt`):
```
prod-sql-01.company.com
prod-sql-02.company.com
dev-sql-01.company.com
test-sql-01.company.com
```

2. Run batch analysis:
```powershell
python cli.py batch --input servers.txt --username sa --password MyPass123 --output migration_assessment.csv --dbc
```

3. **Outputs:**
   - `migration_assessment.csv` - Full 39-column technical assessment
   - `migration_assessment_DBC.csv` - 23-column database consolidation format

**Use the results for:**
- Identifying RDS-compatible vs. RDS Custom vs. EC2-only servers
- Estimating RDS instance types and costs
- Planning migration waves based on complexity
- Identifying servers with blocking features that need remediation

---

### Use Case 3: Instance Sizing Recommendations

**Scenario:** You know your current SQL Server specs and want RDS instance recommendations.

**When to use:**
- Pre-migration planning
- Cost estimation
- Right-sizing discussions

**Example:**
```powershell
python cli.py recommend --cpu 16 --memory 64 --storage 500
```

**Output:**
```
Recommended Instance: db.m5.4xlarge
Source: 16 vCPU, 64.0 GB RAM, 500.0 GB storage
```

---

### Use Case 4: Automated Reporting with Task Scheduler

**Scenario:** Run weekly assessments and email results to migration team.

**When to use:**
- Ongoing migration projects
- Monitoring environment changes
- Regular compliance checks

**Setup:**

1. Create PowerShell script (`weekly_assessment.ps1`):
```powershell
cd C:\RDSMCP
.\venv\Scripts\activate
python cli.py batch --input servers.txt --username sa --password MyPass123 --output "reports\assessment_$(Get-Date -Format 'yyyy-MM-dd').csv" --dbc
# Add email logic here
```

2. Schedule in Windows Task Scheduler to run weekly

---

## MCP Mode Use Cases

### Use Case 5: AI-Assisted Migration Assessment

**Scenario:** Use AI assistant (Kiro CLI) to interactively assess SQL Servers and get migration recommendations.

**When to use:**
- Exploratory analysis
- Learning about RDS compatibility
- Getting contextual recommendations
- Complex migration scenarios requiring interpretation

**Setup:**

Configure Kiro CLI (`~/.kiro/config.json`):
```json
{
  "mcpServers": {
    "rds-discovery": {
      "command": "C:\\RDSMCP\\venv\\Scripts\\python.exe",
      "args": ["C:\\RDSMCP\\server.py"]
    }
  }
}
```

**Example Conversation:**
```
User: "Analyze SQL Server prod-sql-01.company.com using Windows auth"

Kiro: [Uses analyze_sql_server tool]
      "This server is RDS compatible. It's running SQL Server 2019 Standard 
      with 16 vCPUs and 64GB RAM. I recommend db.m5.4xlarge. 
      No blocking features detected."

User: "What about the SSIS packages on that server?"

Kiro: "SSIS was detected on this server. SSIS is not supported in RDS, 
      but it's informational only and doesn't block migration. 
      You'll need to migrate SSIS packages to AWS Glue or run them on EC2."

User: "Analyze all servers in my list and create a summary"

Kiro: [Uses analyze_sql_servers_batch tool]
      "I've analyzed 25 servers. Here's the summary:
      - 18 are RDS compatible
      - 5 require RDS Custom (>16TB databases)
      - 2 need EC2 (FILESTREAM enabled)
      
      CSV reports saved to results.csv and results_DBC.csv"
```

---

### Use Case 6: Interactive Migration Planning

**Scenario:** Work with AI to understand migration blockers and get remediation advice.

**When to use:**
- Complex environments
- Need explanation of compatibility issues
- Want alternative solutions

**Example Conversation:**
```
User: "Check if server app-sql-03 can migrate to RDS"

Kiro: [Analyzes server]
      "This server has FILESTREAM enabled, which blocks RDS migration.
      It's currently using 2TB of storage."

User: "What are my options?"

Kiro: "You have three options:
      1. Migrate to RDS Custom for SQL Server (supports most features)
      2. Migrate to EC2 (full control, supports FILESTREAM)
      3. Refactor application to remove FILESTREAM dependency, then use RDS
      
      Given the 2TB size, RDS Custom or EC2 would be most practical."

User: "What instance type for EC2?"

Kiro: [Uses recommend_rds_instance tool]
      "Based on 16 vCPUs and 64GB RAM, I recommend db.m5.4xlarge 
      equivalent: m5.4xlarge EC2 instance."
```

---

### Use Case 7: Batch Analysis with AI Interpretation

**Scenario:** Analyze multiple servers and get AI-generated insights and recommendations.

**When to use:**
- Need executive summary
- Want prioritized action items
- Require cost-benefit analysis

**Example Conversation:**
```
User: "Analyze all servers in servers.txt and give me a migration strategy"

Kiro: [Runs batch analysis]
      "Analysis complete. Here's your migration strategy:
      
      Wave 1 (Low Risk - 12 servers):
      - All RDS compatible
      - No blocking features
      - Estimated cost: $X/month
      - Recommended: Start here
      
      Wave 2 (Medium Risk - 8 servers):
      - RDS compatible but have Always On AG
      - Need to plan for RDS Multi-AZ setup
      - Estimated cost: $Y/month
      
      Wave 3 (High Risk - 5 servers):
      - Require RDS Custom or EC2
      - Have FILESTREAM or >16TB databases
      - Need architecture review
      - Estimated cost: $Z/month
      
      Total estimated monthly cost: $X+Y+Z
      
      Detailed reports saved to results.csv and results_DBC.csv"
```

---

### Use Case 8: Real-Time Troubleshooting

**Scenario:** Get help understanding assessment results and resolving issues.

**When to use:**
- Unexpected assessment results
- Connection errors
- Need clarification on features

**Example Conversation:**
```
User: "Why is my server showing as not RDS compatible?"

Kiro: [Reviews previous analysis]
      "The server has heterogeneous linked servers (non-SQL Server) 
      which are not supported in RDS. Specifically, it has linked 
      servers to Oracle and MySQL databases."

User: "How do I fix this?"

Kiro: "Options to remediate:
      1. Remove linked servers and use application-level integration
      2. Use AWS Database Migration Service (DMS) for data sync
      3. Migrate to RDS Custom which supports more features
      4. Keep on EC2 if linked servers are critical
      
      Would you like me to check if RDS Custom would work?"
```

---

## Comparison: When to Use CLI vs. MCP

| Scenario | CLI Mode | MCP Mode |
|----------|----------|----------|
| **Batch processing 100+ servers** | ✅ Best choice | ❌ Too slow |
| **Automated scheduled reports** | ✅ Best choice | ❌ Not suitable |
| **Quick single server check** | ✅ Fast | ✅ Good for interpretation |
| **Learning about RDS compatibility** | ❌ Limited context | ✅ Best choice |
| **Need explanation of results** | ❌ Raw data only | ✅ Best choice |
| **Migration strategy planning** | ⚠️ Manual analysis needed | ✅ Best choice |
| **Scripting/automation** | ✅ Best choice | ❌ Not suitable |
| **Interactive exploration** | ❌ Limited | ✅ Best choice |
| **CI/CD pipeline integration** | ✅ Best choice | ❌ Not suitable |
| **Executive reporting** | ⚠️ Requires post-processing | ✅ Can generate summaries |

---

## Hybrid Approach (Best Practice)

**Recommended workflow for large migrations:**

1. **Discovery Phase (CLI)**
   - Use CLI batch mode to assess all servers
   - Generate CSV reports for documentation

2. **Analysis Phase (MCP)**
   - Use MCP mode to interpret results
   - Get AI-assisted migration strategy
   - Identify remediation priorities

3. **Planning Phase (MCP)**
   - Interactive planning with AI
   - Cost estimation and optimization
   - Risk assessment

4. **Execution Phase (CLI)**
   - Automated re-assessment before migration
   - Validation checks
   - Progress tracking

5. **Monitoring Phase (CLI)**
   - Scheduled assessments
   - Automated reporting
   - Compliance checks

---

## Example: Complete Migration Project

**Project:** Migrate 50 SQL Servers to AWS

**Week 1-2: Discovery (CLI)**
```powershell
python cli.py batch --input all_servers.txt --windows-auth --output discovery.csv --dbc
```

**Week 3: Analysis (MCP)**
```
User: "Analyze discovery.csv and create migration waves"
Kiro: [Provides detailed wave plan with priorities]
```

**Week 4-6: Planning (MCP)**
```
User: "For each server in Wave 1, what's the migration approach?"
Kiro: [Provides server-by-server migration plans]
```

**Week 7-12: Execution (CLI + MCP)**
- CLI: Pre-migration validation
- MCP: Troubleshooting and guidance
- CLI: Post-migration verification

**Ongoing: Monitoring (CLI)**
```powershell
# Weekly Task Scheduler job
python cli.py batch --input remaining_servers.txt --windows-auth --output weekly_check.csv
```

---

## Summary

- **Use CLI** for: Automation, batch processing, scheduled tasks, scripting
- **Use MCP** for: Interactive analysis, learning, strategy planning, troubleshooting
- **Use Both** for: Complex migration projects requiring automation AND human insight
