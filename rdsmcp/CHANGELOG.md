# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **ODBC Driver Auto-Detection**: Automatically detects and uses installed ODBC driver (supports Driver 18, 17, 13, 11, SQL Server Native Client, or legacy SQL Server driver)

### Fixed
- **RDS Source Detection**: Servers already running on RDS now always show as "RDS Compatible" regardless of detected features (prevents false negatives from RDS internal system objects)

## [3.0.0] - 2025-12-01

### Added
- **CPU:Memory Ratio Logic**: Automatically determines Memory Optimized (M) vs General Purpose (G) based on CPU:Memory ratio (>4 = M, ≤4 = G)
- **Ultra-High Memory Support**: Recommends db.x* instances for servers with >1TB RAM
- **Connection Test Function**: Added `test_sql_connection()` matching PowerShell `Test-SQLConnection` behavior
- **Pre-Assessment Connection Check**: Tests connectivity before running full assessment query
- **Better Batch Output**: Shows connection status (✓ Connected, ✗ Connection Failed, ✗ Timeout, ✗ Auth Failed)
- **SQL Server 2012+ Backward Compatibility**: Added TRY/CATCH blocks and DMV existence checks for graceful handling of older SQL Server versions
- **Feature Support Matrix**: Documents which features are supported on each SQL Server version (2008 R2 through 2022)
- **DBC.CSV output format** - 23-column Database Consolidation format for migration planning
- `--dbc` flag in CLI batch command to generate DBC.csv alongside standard output
- `export_dbc_results()` function in batch.py
- **NoOfDB and TotalStorage** - Actual values from SQL Server instead of placeholders in DBC output
- Simplified output format with placeholders for manual input (CPU/Memory utilization, storage, IOPS, etc.)

### Changed
- **Instance Recommendations**: Now considers CPU:Memory ratio when utilization data not available
- **Memory Optimized Detection**: Automatically recommends db.r* instances for memory-intensive workloads (ratio >4)
- **Connection Flow**: All assessments now test connection first before running full query (10-second timeout)
- **Error Messages**: Categorized error types (Connection Failed, Timeout, Auth Failed) for easier troubleshooting
- **PolyBase Detection**: Now checks for `sys.external_data_sources` existence before querying (SQL 2016+)
- **Buffer Pool Extension**: Now checks for `sys.dm_os_buffer_pool_extension_configuration` existence before querying (SQL 2014+)
- **Enterprise Features Detection**: Added DMV existence check and per-database TRY/CATCH for `sys.dm_db_persisted_sku_features` (SQL 2012 SP1+)
- Batch command now supports dual output: standard 39-column CSV + optional 23-column DBC.CSV
- DBC format focuses on infrastructure planning with fewer technical details

### Fixed
- **Fast Fail**: Connection issues now detected in 10 seconds instead of waiting for full query timeout (30 seconds)
- **Batch Processing**: Failed connections no longer block subsequent servers in batch mode
- SQL queries now execute successfully on SQL Server 2012 RTM and later versions
- Enterprise features detection no longer fails on databases where DMV is inaccessible
- PolyBase and Buffer Pool Extension queries no longer fail on versions that don't support them
- Unsupported features now return "Not Supported" instead of causing query failures

## [2.1.0] - 2025-11-30

### Added
- **Windows Authentication support** - Use `--windows-auth` flag for Trusted Connection
- Works on Windows (automatic) and Linux (with Kerberos)
- No username/password required when using Windows auth

### Changed
- Username and password are now optional (not required for Windows auth)
- MCP tool `analyze_sql_server` now accepts `use_windows_auth` parameter
- MCP tool `analyze_sql_servers_batch` now accepts `use_windows_auth` parameter

## [2.0.0] - 2025-11-29

### Added
- SSIS (SQL Server Integration Services) detection with Data Collector filtering
- SSRS (SQL Server Reporting Services) detection
- Enterprise Features detection (sys.dm_db_persisted_sku_features)
- Read Only Replica detection
- Source detection (RDS/EC2/OnPrem)
- isSSIS and isSSRS columns in CSV output
- Dynamic notes field with SSIS/SSRS detection info
- Batch processing with CSV export
- MCP server mode for AI assistant integration

### Changed
- **BREAKING**: RDS compatibility logic now matches PowerShell exactly (18 feature checks)
- **BREAKING**: SSIS, SSRS, Enterprise Features, Always On AG/FCI, and Server Role are now informational only (don't block RDS)
- Instance recommendations now exclude t3 burstable instances
- General Purpose (G) type now only includes db.m* instances
- Memory Optimized (M) type now excludes db.m*, db.r3*, db.r4*, db.t3*, db.x1*, db.x1e*
- RDS Custom limit corrected to 16TB (was 14.5TB)
- CSV output expanded to 39 columns (from 38)

### Fixed
- SSIS detection now filters out Data Collector system packages
- Instance recommendation primary selection now consistent
- ODBC type converter added for SQL_VARIANT columns
- Empty string handling for Enterprise Features in compatibility check

### Validated
- SQL queries 100% match PowerShell RDSDiscoveryGuidev5.ps1
- RDS compatibility logic matches PowerShell (excludes informational features)
- Instance sizing matches PowerShell (CPU/4 ratio, no t3)
- CSV format compatible with PowerShell (minus 9 business question columns)

## [1.0.0] - 2025-11-25

### Added
- Initial release
- Single server analysis
- Basic RDS compatibility checks
- Instance recommendations
- CLI interface
- JSON output format
