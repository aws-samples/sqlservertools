"""
Batch processing for multiple SQL Server assessments
"""
from typing import List, Dict, Any
from core import analyze_sql_server
from recommendation import get_rds_recommendation
import csv


def read_servers_file(file_path: str) -> List[str]:
    """Read servers from text file (one per line)"""
    servers = []
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                servers.append(line)
    return servers


def process_batch(file_path: str, username: str = None, password: str = None, port: int = 1433, use_windows_auth: bool = False) -> Dict[str, Any]:
    """Process multiple SQL Servers from file"""
    servers = read_servers_file(file_path)
    results = []
    errors = []
    
    for server in servers:
        print(f"  Testing {server}...", end=" ", flush=True)
        try:
            # Analyze server (includes connection test)
            result = analyze_sql_server(server, username, password, port, use_windows_auth=use_windows_auth)
            print("✓ Connected")
            
            # Add recommendation
            cpu = result['resources']['cpu']
            memory_gb = result['resources']['max_memory_mb'] / 1024
            edition = 'EE' if 'Enterprise' in result['server_info']['edition'] else 'SE'
            version = int(result['server_info']['version'].split('.')[0])
            
            recommendation = get_rds_recommendation(cpu, memory_gb, edition=edition, version=version)
            result['recommendation'] = recommendation
            result['server'] = server
            
            results.append(result)
        except Exception as e:
            error_msg = str(e)
            
            # Categorize error type for better output
            if "Connection test failed" in error_msg:
                print("✗ Connection Failed")
            elif "timeout" in error_msg.lower():
                print("✗ Timeout")
            elif "login failed" in error_msg.lower():
                print("✗ Auth Failed")
            else:
                print("✗ Error")
            
            errors.append({'server': server, 'error': error_msg})
    
    # Calculate summary
    compatible_count = sum(1 for r in results if r['rds_compatible'])
    incompatible_count = len(results) - compatible_count
    
    return {
        'results': results,
        'errors': errors,
        'summary': {
            'total': len(servers),
            'successful': len(results),
            'failed': len(errors),
            'compatible': compatible_count,
            'incompatible': incompatible_count
        }
    }


def export_batch_results(batch_results: Dict[str, Any], output_path: str):
    """Export batch results to CSV in PowerShell-compatible format"""
    results = batch_results['results']
    
    if not results:
        return
    
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Header - matches PowerShell technical columns (skipping business questions)
        writer.writerow([
            'Server Name',
            'SQL Server Current Edition',
            'SQL Server current Version',
            'Sql server Source',
            'SQL Server Replication',
            'Heterogeneous linked server',
            'Database Log Shipping',
            'FILESTREAM',
            'Resource Governor',
            'Service Broker Endpoints',
            'Non Standard Extended Proc',
            'TSQL Endpoints',
            'PolyBase',
            'File Table',
            'buffer Pool Extension',
            'Stretch DB',
            'Trust Worthy On',
            'Server Side Trigger',
            'R & Machine Learning',
            'Data Quality Services',
            'Policy Based Management',
            'CLR Enabled',
            'DB count Over 100',
            'Total DB Size in GB',
            'Always ON AG enabled',
            'Always ON FCI enabled',
            'Read Only Replica',
            'Server Role Desc',
            'RDS Compatible',
            'RDS Custom Compatible',
            'EC2 Compatible',
            'Elasticache',
            'Enterprise Level Feature Used',
            'Memory',
            'CPU',
            'Instance Type',
            'isSSIS',
            'isSSRS',
            'Note'
        ])
        
        # Data rows
        for result in results:
            features = result['features']
            
            # Determine RDS Custom compatibility (>16TB not compatible)
            rds_custom_compatible = 'Y' if result['resources']['total_db_size_gb'] <= 16000 else 'N'
            
            # Build note with SSIS/SSRS info if present
            note = 'Assessment completed successfully'
            if features['ssis'] == 'Y' or features['ssrs'] == 'Y':
                ssis_ssrs_info = []
                if features['ssis'] == 'Y':
                    ssis_ssrs_info.append('SSIS')
                if features['ssrs'] == 'Y':
                    ssis_ssrs_info.append('SSRS')
                note += f". {' and '.join(ssis_ssrs_info)} detected - informational only, does not affect RDS compatibility"
            
            writer.writerow([
                result['server'],
                result['server_info']['edition'],
                result['server_info']['version'],
                result['server_info']['source'],
                features['transaction_replication'],
                features['linked_servers'],
                features['log_shipping'],
                features['filestream'],
                features['resource_governor'],
                features['service_broker'],
                features['extended_procedures'],
                features['tsql_endpoints'],
                features['polybase'],
                features['file_tables'],
                features['buffer_pool_extension'],
                features['stretch_database'],
                features['trustworthy_databases'],
                features['server_triggers'],
                features['machine_learning'],
                features['data_quality_services'],
                features['policy_based_management'],
                features['clr_enabled'],
                features['database_count'],
                result['resources']['total_db_size_gb'],
                features['always_on_ag'],
                features['always_on_fci'],
                features['read_only_replica'],
                features['server_role'],
                'Y' if result['rds_compatible'] else 'N',
                rds_custom_compatible,
                'Y',  # EC2 always compatible
                'N',  # Elasticache - not implemented yet
                features['enterprise_features'],
                result['resources']['max_memory_mb'],
                result['resources']['cpu'],
                result['recommendation']['primary_recommendation'],
                features['ssis'],
                features['ssrs'],
                note
            ])



def export_dbc_results(batch_results: Dict[str, Any], output_path: str = 'DBC.csv'):
    """Export batch results to DBC.csv format (23 columns)"""
    results = batch_results['results']
    
    if not results:
        return
    
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Header - 23 columns
        writer.writerow([
            'ServerName',
            'VCPU',
            'Memory',
            'Edition',
            'IsPartOfCluster',
            'IsAlwaysonAG',
            'IsAlwaysonFCI',
            'DBRole',
            'IsReadReplica',
            'InstanceType',
            'Optimized Instance Type',
            'IsEEFeatureUsed',
            'DBSize(GB)',
            'TotalStorage(GB)',
            'CpuUtilization',
            'MemoryUtilization',
            'NoOfDB',
            'VMType',
            'EBSType',
            'IOPS',
            'Throughput',
            'Elasticach',
            'Source'
        ])
        
        # Data rows
        for result in results:
            features = result['features']
            
            # IsEEFeatureUsed - Y if enterprise features detected, N otherwise
            ee_used = 'Y' if features.get('enterprise_features', '').strip() else 'N'
            
            writer.writerow([
                result['server'],
                result['resources']['cpu'],
                result['resources']['max_memory_mb'],
                result['server_info']['edition'],
                'Y' if result['server_info']['is_clustered'] else 'N',
                features['always_on_ag'],
                features['always_on_fci'],
                features['server_role'],
                features.get('read_only_replica', 'N'),
                result['recommendation']['primary_recommendation'],
                '',  # Optimized Instance Type - placeholder for manual input
                ee_used,
                result['resources']['total_db_size_gb'],
                result['resources']['total_storage_gb'],
                '0',  # CpuUtilization - placeholder for manual input
                '0',  # MemoryUtilization - placeholder for manual input
                result['resources']['actual_db_count'],
                'HYPERVISOR',  # VMType - default
                '0',  # EBSType - placeholder for manual input
                '0',  # IOPS - placeholder for manual input
                '0',  # Throughput - placeholder for manual input
                '',  # Elasticache - placeholder
                result['server_info'].get('source', 'EC2/OnPrem')
            ])
