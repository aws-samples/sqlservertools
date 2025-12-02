# RDS MCP v3.0.0 - Production Release

SQL Server to AWS RDS Migration Assessment Tool - Python implementation with CLI and MCP server modes.

## 🎯 Key Features

### Instance Recommendations
- **CPU:Memory Ratio Logic**: Automatically determines Memory Optimized vs General Purpose based on workload characteristics
- **Ultra-High Memory Support**: Recommends db.x* instances for servers with >1TB RAM
- **Smart Detection**: No utilization data needed - uses server specs to determine optimal instance type

### Connection & Error Handling
- **Pre-Assessment Connection Test**: Fast fail in 10 seconds for unreachable servers
- **Categorized Errors**: Clear messages (Connection Failed, Timeout, Auth Failed)
- **Batch Processing**: Failed connections don't block subsequent servers

### SQL Server Compatibility
- **Backward Compatible**: Works with SQL Server 2012+ (with graceful degradation)
- **DMV Existence Checks**: Queries don't fail on older versions
- **TRY/CATCH Protection**: Handles missing features gracefully

### Output Formats
- **Standard CSV**: 39-column technical assessment format
- **DBC Format**: 23-column Database Consolidation format for migration planning
- **Actual Values**: NoOfDB and TotalStorage from SQL Server (not placeholders)

### Authentication
- **SQL Authentication**: Standard username/password
- **Windows Authentication**: Trusted Connection support (Kerberos on Linux)

## 📦 Installation

### Prerequisites
- Python 3.8+
- Microsoft ODBC Driver for SQL Server (17, 18, 13, 11, or SQL Server Native Client - auto-detected)

### Quick Start
```bash
git clone https://github.com/bobtherdsman/RDSMCP.git
cd RDSMCP
pip install -r requirements.txt

# Test single server
python3 cli.py analyze --host <server> --username <user> --password <pass>

# Batch process
python3 cli.py batch --input servers.txt --output results.csv --dbc
```

## 🔧 Usage Modes

### CLI Mode
- Single server analysis
- Batch processing from file
- CSV and DBC output formats

### MCP Server Mode
- Integration with AI assistants (Claude, etc.)
- Tools: `analyze_sql_server`, `recommend_rds_instance`
- Real-time assessment capabilities

## 📊 What's Assessed

**18 RDS Compatibility Features:**
- Database count (>100 limit)
- Linked servers, Log shipping, Filestream
- Resource Governor, Transaction Replication
- Extended procedures, T-SQL endpoints
- PolyBase, File tables, Buffer pool extension
- Stretch database, Trustworthy databases
- Server triggers, Machine learning
- Data Quality Services, Policy-based management
- CLR enabled

**Informational (Non-Blocking):**
- Always On Availability Groups
- Always On Failover Cluster Instances
- SSIS (Integration Services)
- SSRS (Reporting Services)
- Enterprise Edition features

## 🆕 What's New in v3.0.0

### Major Improvements
- CPU:Memory ratio for automatic Memory Optimized detection
- Ultra-high memory support (>1TB RAM)
- Connection test with fast fail (10 seconds)
- SQL Server 2012+ backward compatibility
- DBC output with actual database count and storage

### Technical Enhancements
- DMV existence checks before querying
- Per-database TRY/CATCH for enterprise features
- Better error categorization and messages
- Batch processing improvements

## 📝 Documentation

- **README.md**: Installation and usage guide
- **CHANGELOG.md**: Complete version history
- **LICENSE**: MIT License

## 🤝 Contributing

Issues and pull requests welcome at https://github.com/bobtherdsman/RDSMCP

## 📄 License

MIT License - See LICENSE file for details
