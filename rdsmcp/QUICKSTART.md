# Quick Start Guide

Get started with RDSMCP in 5 minutes.

## Prerequisites

- Windows OS
- Python 3.8+ installed
- ODBC Driver for SQL Server (any version - auto-detected)
- SQL Server credentials

## Installation (5 minutes)

### Step 1: Install Python
1. Download from https://www.python.org/downloads/
2. Run installer - **CHECK "Add Python to PATH"**
3. Verify: `python --version`

### Step 2: Install Git (if not installed)
1. Download from https://git-scm.com/download/win
2. Run installer with default settings
3. Verify: `git --version`

### Step 3: Install ODBC Driver (if not installed)
1. Download from https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
2. Run installer
3. Verify: Open `odbcad32` → Drivers tab → Look for "ODBC Driver XX for SQL Server"

### Step 4: Clone and Setup
```powershell
# Clone repository
git clone https://github.com/bobtherdsman/RDSMCP.git
cd RDSMCP

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 5: Verify Installation
```powershell
python cli.py --help
```

**Expected output:**
```
Usage: cli.py [OPTIONS] COMMAND [ARGS]...

  SQL Server to RDS Migration Assessment Tool

Options:
  --help  Show this message and exit.

Commands:
  analyze    Analyze SQL Server instance for RDS compatibility
  batch      Analyze multiple SQL Servers from input file
  recommend  Recommend RDS instance type
```

---

## Usage Examples

### Example 1: Analyze Single Server

**Command:**
```powershell
python cli.py analyze --host myserver.company.com --username sa --password MyPass123
```

**Output:**
```
=== SQL Server Analysis: myserver.company.com ===

Edition: Standard Edition (64-bit)
Version: 16.0.4212.1
CPU: 16
Memory: 32768 MB
Database Size: 250.5 GB

RDS Compatible: Yes

Recommended RDS Instance: db.m6i.4xlarge
Alternative instances: db.m5d.4xlarge, db.m5d.24xlarge
```

**What this tells you:**
- ✅ Server is RDS compatible (no blocking features)
- Recommended instance: db.m6i.4xlarge
- Current specs: 16 CPU, 32GB RAM, 250GB data

---

### Example 2: Analyze with Windows Authentication

**Command:**
```powershell
python cli.py analyze --host myserver.company.com --windows-auth
```

Uses your current Windows credentials (no username/password needed).

---

### Example 3: Batch Analysis (Multiple Servers)

**Step 1: Create server list** (`servers.txt`):
```
prod-sql-01.company.com
prod-sql-02.company.com
dev-sql-01.company.com
```

**Step 2: Run batch analysis:**
```powershell
python cli.py batch --input servers.txt --username sa --password MyPass123 --output results.csv --dbc
```

**Output:**
```
Processing servers from servers.txt...
✓ prod-sql-01.company.com - Connected
✓ prod-sql-02.company.com - Connected
✓ dev-sql-01.company.com - Connected

=== Batch Processing Summary ===
Total servers: 3
Successful: 3
Failed: 0
RDS Compatible: 2
RDS Incompatible: 1

Results exported to: results.csv
DBC output exported to: results_DBC.csv
```

**What you get:**
- `results.csv` - Full 39-column technical assessment
- `results_DBC.csv` - 23-column database consolidation format for migration planning

---

### Example 4: Get Instance Recommendations

**Command:**
```powershell
python cli.py recommend --cpu 16 --memory 64 --storage 500
```

**Output:**
```
Recommended Instance: db.m5.4xlarge
Source: 16 vCPU, 64.0 GB RAM, 500.0 GB storage
```

Use this for quick sizing without connecting to SQL Server.

---

## Understanding Results

### RDS Compatible: Yes ✅
Server can migrate to standard RDS for SQL Server. No blocking features detected.

**Next steps:**
1. Review recommended instance type
2. Plan migration using AWS Database Migration Service (DMS)
3. Test application compatibility

### RDS Compatible: No ❌
Server has features not supported in standard RDS.

**Example output:**
```
RDS Compatible: No

Incompatible Features Found:
  - filestream
  - linked_servers
```

**Next steps:**
1. Review incompatible features
2. Consider RDS Custom for SQL Server (supports more features)
3. Or migrate to EC2 for full control
4. Or refactor application to remove dependencies

---

## Common Scenarios

### Scenario 1: Migration Assessment for 50 Servers

```powershell
# Create server list
notepad servers.txt

# Run batch analysis with DBC output
python cli.py batch --input servers.txt --username sa --password MyPass123 --output migration_assessment.csv --dbc

# Open results in Excel
start migration_assessment.csv
start migration_assessment_DBC.csv
```

**Use results for:**
- Identify RDS-compatible vs. RDS Custom vs. EC2-only servers
- Estimate costs using recommended instance types
- Plan migration waves based on complexity

---

### Scenario 2: Quick Check Before Migration

```powershell
# Test single server
python cli.py analyze --host prod-sql-01 --windows-auth

# If compatible, proceed with migration
# If not, review incompatible features
```

---

### Scenario 3: Right-Sizing Existing RDS

```powershell
# Analyze current RDS instance
python cli.py analyze --host myserver.rds.amazonaws.com --username admin --password MyPass123

# Compare recommended vs. current instance type
# Adjust if over/under-provisioned
```

---

## MCP Mode (AI-Assisted Analysis)

### Setup MCP with Kiro CLI

**Step 1: Configure Kiro**

Create/edit `C:\Users\<YourUser>\.kiro\config.json`:
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

**Step 2: Start Kiro CLI**
```powershell
kiro-cli chat
```

**Step 3: Use AI-assisted analysis**
```
You: Analyze SQL Server prod-sql-01.company.com with username sa and password MyPass123

Kiro: [Analyzes server and provides detailed explanation]
      This server is RDS compatible. It's running SQL Server 2022 Standard...
      
You: What about the SSIS packages?

Kiro: SSIS was detected but it's informational only. You'll need to migrate 
      SSIS packages to AWS Glue or run them on EC2...
```

---

## Troubleshooting

### Issue: "python is not recognized"
**Fix:** Python not in PATH. Reinstall Python and check "Add Python to PATH"

### Issue: "git is not recognized"
**Fix:** Install Git from https://git-scm.com/download/win

### Issue: "Connection test failed: Data source name not found"
**Fix:** Install ODBC Driver from https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server

### Issue: "Login timeout expired"
**Fix:** 
- Verify server hostname/IP is correct
- Check firewall allows SQL Server port (1433)
- Verify credentials are correct

**For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**

---

## Next Steps

1. ✅ **Installation complete** - Tool is ready to use
2. 📊 **Run your first analysis** - Test with a single server
3. 📁 **Batch assessment** - Analyze all servers in your environment
4. 📈 **Review results** - Identify migration candidates
5. 🚀 **Plan migration** - Use recommendations for AWS migration planning

---

## Additional Resources

- **Full Documentation:** [README.md](README.md)
- **Troubleshooting Guide:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Use Cases & Examples:** [USE_CASES.md](USE_CASES.md)
- **Version History:** [CHANGELOG.md](CHANGELOG.md)

---

## Support

For issues or questions:
- Open an issue on GitHub: https://github.com/bobtherdsman/RDSMCP/issues
- Review troubleshooting guide: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
