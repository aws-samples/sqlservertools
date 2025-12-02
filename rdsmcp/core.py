"""
Core SQL Server assessment logic shared between CLI and MCP server
"""
import pyodbc
from typing import Dict, Any, Tuple
from sql_queries import FULL_ASSESSMENT_QUERY


def get_available_odbc_driver() -> str:
    """Detect available ODBC driver for SQL Server
    
    Returns:
        str: ODBC driver name (e.g., "ODBC Driver 18 for SQL Server")
    
    Raises:
        Exception: If no compatible ODBC driver is found
    """
    drivers = [d for d in pyodbc.drivers() if 'SQL Server' in d]
    
    # Prefer newer drivers first
    preferred_order = [
        'ODBC Driver 18 for SQL Server',
        'ODBC Driver 17 for SQL Server',
        'ODBC Driver 13 for SQL Server',
        'ODBC Driver 11 for SQL Server',
        'SQL Server Native Client 11.0',
        'SQL Server'
    ]
    
    for preferred in preferred_order:
        if preferred in drivers:
            return preferred
    
    if drivers:
        return drivers[0]
    
    raise Exception("No ODBC driver for SQL Server found. Please install ODBC Driver 17 or 18.")


def test_sql_connection(host: str, username: str = None, password: str = None, 
                       port: int = 1433, use_windows_auth: bool = False, 
                       timeout: int = 10) -> Tuple[bool, str]:
    """Test SQL Server connection before running full assessment
    
    Matches PowerShell Test-SQLConnection function behavior:
    - Opens connection
    - Closes connection immediately
    - Returns success/failure
    
    Args:
        host: SQL Server hostname or IP
        username: SQL Server username (not used if use_windows_auth=True)
        password: SQL Server password (not used if use_windows_auth=True)
        port: SQL Server port (default: 1433)
        use_windows_auth: Use Windows Authentication (default: False)
        timeout: Connection timeout in seconds (default: 10)
    
    Returns:
        tuple: (success: bool, error_message: str)
    """
    try:
        driver = get_available_odbc_driver()
    except Exception as e:
        return (False, str(e))
    
    if use_windows_auth:
        conn_str = f"DRIVER={{{driver}}};SERVER={host},{port};Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes"
    else:
        conn_str = f"DRIVER={{{driver}}};SERVER={host},{port};UID={username};PWD={password};Encrypt=yes;TrustServerCertificate=yes"
    
    try:
        conn = pyodbc.connect(conn_str, timeout=timeout)
        conn.close()
        return (True, "")
    except Exception as e:
        return (False, str(e))


def analyze_sql_server(host: str, username: str = None, password: str = None, port: int = 1433, use_windows_auth: bool = False) -> Dict[str, Any]:
    """Analyze SQL Server instance for RDS compatibility"""
    
    # Test connection first (matches PowerShell behavior)
    success, error = test_sql_connection(host, username, password, port, use_windows_auth, timeout=10)
    if not success:
        raise Exception(f"Connection test failed: {error}")
    
    # Get available ODBC driver
    driver = get_available_odbc_driver()
    
    # Proceed with full assessment
    if use_windows_auth:
        # Windows Authentication (Kerberos/NTLM)
        conn_str = f"DRIVER={{{driver}}};SERVER={host},{port};Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes"
    else:
        # SQL Authentication
        conn_str = f"DRIVER={{{driver}}};SERVER={host},{port};UID={username};PWD={password};Encrypt=yes;TrustServerCertificate=yes"
    
    with pyodbc.connect(conn_str, timeout=30) as conn:
        # Add output converter for SQL_VARIANT and other types
        conn.add_output_converter(-150, lambda x: x.decode('utf-16le') if isinstance(x, bytes) else str(x))
        
        cursor = conn.cursor()
        cursor.execute(FULL_ASSESSMENT_QUERY)
        row = cursor.fetchone()
        
        server_info = {
            "edition": str(row.Edition) if row.Edition else "",
            "version": str(row.ProductVersion) if row.ProductVersion else "",
            "is_clustered": bool(row.IsClustered) if row.IsClustered else False,
            "source": str(row.Source).strip() if row.Source else "EC2/OnPrem"
        }
        
        resources = {
            "cpu": int(row.CPU) if row.CPU else 0,
            "max_memory_mb": int(row.MaxMemory) if row.MaxMemory else 0,
            "total_db_size_gb": float(row.UsedSpaceGB) if row.UsedSpaceGB else 0.0,
            "actual_db_count": int(row.ActualDBCount) if row.ActualDBCount else 0,
            "total_storage_gb": float(row.TotalStorageGB) if row.TotalStorageGB else 0.0
        }
        
        features = {
            "linked_servers": str(row.islinkedserver).strip() if row.islinkedserver else "N",
            "filestream": str(row.isFilestream).strip() if row.isFilestream else "N",
            "resource_governor": str(row.isResouceGov).strip() if row.isResouceGov else "N",
            "log_shipping": str(row.issqlTLShipping).strip() if row.issqlTLShipping else "N",
            "service_broker": str(row.issqlServiceBroker).strip() if row.issqlServiceBroker else "N",
            "database_count": str(row.dbcount).strip() if row.dbcount else "N",
            "transaction_replication": str(row.issqlTranRepl).strip() if row.issqlTranRepl else "N",
            "extended_procedures": str(row.isextendedproc).strip() if row.isextendedproc else "N",
            "tsql_endpoints": str(row.istsqlendpoint).strip() if row.istsqlendpoint else "N",
            "polybase": str(row.ispolybase).strip() if row.ispolybase else "N",
            "buffer_pool_extension": str(row.isbufferpoolextension).strip() if row.isbufferpoolextension else "N",
            "file_tables": str(row.isfiletable).strip() if row.isfiletable else "N",
            "stretch_database": str(row.isstretchDB).strip() if row.isstretchDB else "N",
            "trustworthy_databases": str(row.istrustworthy).strip() if row.istrustworthy else "N",
            "server_triggers": str(row.Isservertrigger).strip() if row.Isservertrigger else "N",
            "machine_learning": str(row.isRMachineLearning).strip() if row.isRMachineLearning else "N",
            "data_quality_services": str(row.ISDQS).strip() if row.ISDQS else "N",
            "policy_based_management": str(row.ISPolicyBased).strip() if row.ISPolicyBased else "N",
            "clr_enabled": str(row.isCLREnabled).strip() if row.isCLREnabled else "N",
            "always_on_ag": str(row.IsAlwaysOnAG).strip() if row.IsAlwaysOnAG else "N",
            "always_on_fci": str(row.isalwaysonFCI).strip() if row.isalwaysonFCI else "N",
            "read_only_replica": str(row.IsReadReplica).strip() if row.IsReadReplica else "N",
            "server_role": str(row.DBRole).strip() if row.DBRole else "Standalone",
            "enterprise_features": str(row.isEEFeature).strip() if row.isEEFeature and str(row.isEEFeature).strip() else "",
            "ssis": str(row.isSSSIS).strip() if row.isSSSIS else "N",
            "ssrs": str(row.isSSRS).strip() if row.isSSRS else "N"
        }
        
        # RDS Compatibility - match PowerShell logic exactly
        # Check only these features (exclude: always_on_ag, always_on_fci, server_role, ssis, ssrs, enterprise_features)
        # If source is already RDS, it's always RDS compatible
        if server_info['source'] == 'RDS':
            rds_compatible = True
        else:
            blockers = [
                features['database_count'],
                features['linked_servers'],
                features['log_shipping'],
                features['filestream'],
                features['resource_governor'],
                features['transaction_replication'],
                features['extended_procedures'],
                features['tsql_endpoints'],
                features['polybase'],
                features['file_tables'],
                features['buffer_pool_extension'],
                features['stretch_database'],
                features['trustworthy_databases'],
                features['server_triggers'],
                features['machine_learning'],
                features['policy_based_management'],
                features['data_quality_services'],
                features['clr_enabled']
            ]
            
            rds_compatible = all(v in ['N', 'Not Supported', 'N/A', ''] for v in blockers)
        
        return {
            "server_info": server_info,
            "resources": resources,
            "features": features,
            "rds_compatible": rds_compatible
        }
