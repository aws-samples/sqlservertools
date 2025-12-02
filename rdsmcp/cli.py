#!/usr/bin/env python3
"""
Standalone CLI for SQL Server to RDS Migration Assessment
"""
import click
import json
from core import analyze_sql_server


@click.group()
def cli():
    """SQL Server to RDS Migration Assessment Tool"""
    pass


@cli.command()
@click.option('--host', required=True, help='SQL Server hostname or IP')
@click.option('--username', help='SQL Server username (not required for Windows auth)')
@click.option('--password', help='SQL Server password (not required for Windows auth)')
@click.option('--port', default=1433, help='SQL Server port')
@click.option('--windows-auth', is_flag=True, help='Use Windows Authentication (Trusted Connection)')
@click.option('--output', type=click.Choice(['json', 'table']), default='table', help='Output format')
def analyze(host, username, password, port, windows_auth, output):
    """Analyze SQL Server instance for RDS compatibility"""
    try:
        from recommendation import get_rds_recommendation
        
        result = analyze_sql_server(host, username, password, port, use_windows_auth=windows_auth)
        
        # Add RDS recommendation using PowerShell logic
        cpu = result['resources']['cpu']
        memory_gb = result['resources']['max_memory_mb'] / 1024 if isinstance(result['resources']['max_memory_mb'], (int, float)) else 0
        
        # Determine edition from server info
        edition = 'EE' if 'Enterprise' in result['server_info']['edition'] else 'SE'
        version = int(result['server_info']['version'].split('.')[0])
        
        recommendation = get_rds_recommendation(cpu, memory_gb, edition=edition, version=version)
        result['recommendation'] = recommendation
        result['recommended_instance'] = recommendation['primary_recommendation']
        
        if output == 'json':
            click.echo(json.dumps(result, indent=2))
        else:
            click.echo(f"\n=== SQL Server Analysis: {host} ===\n")
            click.echo(f"Edition: {result['server_info']['edition']}")
            click.echo(f"Version: {result['server_info']['version']}")
            click.echo(f"CPU: {result['resources']['cpu']}")
            click.echo(f"Memory: {result['resources']['max_memory_mb']} MB")
            click.echo(f"Database Size: {result['resources']['total_db_size_gb']} GB")
            click.echo(f"\nRDS Compatible: {'Yes' if result['rds_compatible'] else 'No'}")
            
            incompatible = [k for k, v in result['features'].items() if v == 'Y']
            if incompatible:
                click.echo(f"\nIncompatible Features Found:")
                for feature in incompatible:
                    click.echo(f"  - {feature}")
            
            click.echo(f"\nRecommended RDS Instance: {recommendation['primary_recommendation']}")
            if recommendation['remark']:
                click.echo(f"Note: {recommendation['remark']}")
            if len(recommendation['recommended_instances']) > 1:
                click.echo(f"Alternative instances: {', '.join(recommendation['recommended_instances'][1:])}")
    except Exception as e:
        click.echo(f"Error: {e}", err=True)
        raise click.Abort()


@cli.command()
@click.option('--cpu', required=True, type=int, help='Number of CPUs')
@click.option('--memory', required=True, type=float, help='Memory in GB')
@click.option('--storage', required=True, type=float, help='Storage in GB')
def recommend(cpu, memory, storage):
    """Recommend RDS instance type"""
    if cpu <= 2 and memory <= 8:
        instance = "db.m5.large"
    elif cpu <= 4 and memory <= 16:
        instance = "db.m5.xlarge"
    elif cpu <= 8 and memory <= 32:
        instance = "db.m5.2xlarge"
    elif cpu <= 16 and memory <= 64:
        instance = "db.m5.4xlarge"
    else:
        instance = "db.m5.8xlarge"
    
    click.echo(f"\nRecommended Instance: {instance}")
    click.echo(f"Source: {cpu} vCPU, {memory} GB RAM, {storage} GB storage")


@cli.command()
@click.option('--input', 'input_file', required=True, help='Input file with server list (one per line)')
@click.option('--username', help='SQL Server username (not required for Windows auth)')
@click.option('--password', help='SQL Server password (not required for Windows auth)')
@click.option('--port', default=1433, help='SQL Server port (default: 1433)')
@click.option('--windows-auth', is_flag=True, help='Use Windows Authentication (Trusted Connection)')
@click.option('--output', default='batch_results.csv', help='Output CSV file')
@click.option('--dbc', is_flag=True, help='Also generate DBC.csv output (23-column format)')
def batch(input_file, username, password, port, windows_auth, output, dbc):
    """Analyze multiple SQL Servers from input file"""
    from batch import process_batch, export_batch_results, export_dbc_results
    
    click.echo(f"Processing servers from {input_file}...")
    
    results = process_batch(input_file, username, password, port, use_windows_auth=windows_auth)
    
    # Export results
    export_batch_results(results, output)
    
    # Export DBC if requested
    if dbc:
        dbc_output = output.replace('.csv', '_DBC.csv') if output.endswith('.csv') else 'DBC.csv'
        export_dbc_results(results, dbc_output)
        click.echo(f"DBC output exported to: {dbc_output}")
    
    # Print summary
    summary = results['summary']
    click.echo(f"\n=== Batch Processing Summary ===")
    click.echo(f"Total servers: {summary['total']}")
    click.echo(f"Successful: {summary['successful']}")
    click.echo(f"Failed: {summary['failed']}")
    click.echo(f"RDS Compatible: {summary['compatible']}")
    click.echo(f"RDS Incompatible: {summary['incompatible']}")
    
    # Print errors
    if results['errors']:
        click.echo(f"\n=== Errors ===")
        for error in results['errors']:
            click.echo(f"  {error['server']}: {error['error']}")
    
    click.echo(f"\nResults exported to: {output}")


if __name__ == '__main__':
    cli()
