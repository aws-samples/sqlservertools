"""
MCP Server for SQL Server to RDS Migration Assessment
"""
import asyncio
from mcp.server import Server
from mcp.types import Tool, TextContent
from core import analyze_sql_server
from recommendation import get_rds_recommendation
from batch import process_batch
import json


app = Server("rds-discovery")


@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="analyze_sql_server",
            description="Analyze SQL Server instance for RDS compatibility and migration readiness",
            inputSchema={
                "type": "object",
                "properties": {
                    "host": {"type": "string", "description": "SQL Server hostname or IP"},
                    "username": {"type": "string", "description": "SQL Server username (not required for Windows auth)"},
                    "password": {"type": "string", "description": "SQL Server password (not required for Windows auth)"},
                    "port": {"type": "integer", "description": "SQL Server port", "default": 1433},
                    "use_windows_auth": {"type": "boolean", "description": "Use Windows Authentication (Trusted Connection)", "default": False}
                },
                "required": ["host"]
            }
        ),
        Tool(
            name="recommend_rds_instance",
            description="Recommend RDS instance type based on SQL Server resources",
            inputSchema={
                "type": "object",
                "properties": {
                    "cpu": {"type": "integer", "description": "Number of CPUs"},
                    "memory_gb": {"type": "number", "description": "Memory in GB"},
                    "edition": {"type": "string", "description": "SQL Server edition (EE or SE)", "default": "SE"},
                    "version": {"type": "integer", "description": "SQL Server major version", "default": 15},
                    "cpu_util": {"type": "integer", "description": "CPU utilization percentage (optional)"},
                    "mem_util": {"type": "integer", "description": "Memory utilization percentage (optional)"}
                },
                "required": ["cpu", "memory_gb"]
            }
        ),
        Tool(
            name="analyze_sql_servers_batch",
            description="Analyze multiple SQL Servers from a file (one server per line). Creates CSV output file.",
            inputSchema={
                "type": "object",
                "properties": {
                    "file_path": {"type": "string", "description": "Path to file with server list (one per line)"},
                    "username": {"type": "string", "description": "SQL Server username (not required for Windows auth)"},
                    "password": {"type": "string", "description": "SQL Server password (not required for Windows auth)"},
                    "port": {"type": "integer", "description": "SQL Server port", "default": 1433},
                    "use_windows_auth": {"type": "boolean", "description": "Use Windows Authentication (Trusted Connection)", "default": False},
                    "output_file": {"type": "string", "description": "Output CSV file path", "default": "batch_results.csv"},
                    "generate_dbc": {"type": "boolean", "description": "Also generate DBC.csv output (23-column format)", "default": False}
                },
                "required": ["file_path"]
            }
        )
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "analyze_sql_server":
        try:
            result = analyze_sql_server(
                arguments["host"],
                arguments.get("username"),
                arguments.get("password"),
                arguments.get("port", 1433),
                use_windows_auth=arguments.get("use_windows_auth", False)
            )
            
            # Add RDS recommendation
            cpu = result['resources']['cpu']
            memory_gb = result['resources']['max_memory_mb'] / 1024 if isinstance(result['resources']['max_memory_mb'], (int, float)) else 0
            edition = 'EE' if 'Enterprise' in result['server_info']['edition'] else 'SE'
            version = int(result['server_info']['version'].split('.')[0])
            
            recommendation = get_rds_recommendation(cpu, memory_gb, edition=edition, version=version)
            result['recommendation'] = recommendation
            result['recommended_instance'] = recommendation['primary_recommendation']
            
            return [TextContent(type="text", text=json.dumps(result, indent=2))]
        except Exception as e:
            return [TextContent(type="text", text=json.dumps({"error": str(e)}))]
    
    elif name == "recommend_rds_instance":
        cpu = arguments["cpu"]
        memory_gb = arguments["memory_gb"]
        edition = arguments.get("edition", "SE")
        version = arguments.get("version", 15)
        cpu_util = arguments.get("cpu_util")
        mem_util = arguments.get("mem_util")
        
        result = get_rds_recommendation(cpu, memory_gb, edition, version, cpu_util, mem_util)
        return [TextContent(type="text", text=json.dumps(result, indent=2))]
    
    elif name == "analyze_sql_servers_batch":
        try:
            file_path = arguments["file_path"]
            username = arguments.get("username")
            password = arguments.get("password")
            port = arguments.get("port", 1433)
            use_windows_auth = arguments.get("use_windows_auth", False)
            output_file = arguments.get("output_file", "batch_results.csv")
            generate_dbc = arguments.get("generate_dbc", False)
            
            results = process_batch(file_path, username, password, port, use_windows_auth=use_windows_auth)
            
            # Export to CSV
            from batch import export_batch_results, export_dbc_results
            export_batch_results(results, output_file)
            
            # Export DBC if requested
            if generate_dbc:
                dbc_output = output_file.replace('.csv', '_DBC.csv') if output_file.endswith('.csv') else 'DBC.csv'
                export_dbc_results(results, dbc_output)
                results['dbc_output_file'] = dbc_output
            
            # Add output file info to results
            results['output_file'] = output_file
            
            return [TextContent(type="text", text=json.dumps(results, indent=2))]
        except Exception as e:
            return [TextContent(type="text", text=json.dumps({"error": str(e)}))]


async def main():
    from mcp.server.stdio import stdio_server
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
