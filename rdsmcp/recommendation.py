"""
RDS Instance Recommendation - Exact port from RDSDiscoveryGuide.ps1
"""
import csv
import math
from pathlib import Path


def get_rds_recommendation(cpu: int, memory_gb: float, edition: str = 'EE', version: int = 15, 
                          cpu_util: int = None, mem_util: int = None):
    """
    Recommend RDS instance based on on-prem specs
    Exact port of RDSDiscoveryGuide.ps1 RDSInstance function
    """
    
    # Store original values for ratio calculation
    original_cpu = cpu
    original_memory_gb = memory_gb
    
    # Cap memory at 1025 GB for size calculation
    if memory_gb > 1025:
        memory_gb = 1025
    
    # Divide CPU by 4 and round up
    cpu = math.ceil(cpu / 4)
    
    # Determine size class based on CPU (only if memory < 1025)
    if memory_gb < 1025:
        if cpu >= 25:
            size = '32xlarge'
        elif cpu <= 24 and cpu > 16:
            size = '24xlarge'
        elif cpu <= 16 and cpu > 12:
            size = '16xlarge'
        elif cpu <= 12 and cpu > 8:
            size = '12xlarge'
        elif cpu <= 8 and cpu > 4:
            size = '8xlarge'
        elif cpu <= 4 and cpu > 2:
            size = '4xlarge'
        elif cpu <= 2 and cpu > 1:
            size = '2xlarge'
        elif cpu <= 1:
            size = 'xlarge'
        elif cpu == 0:
            size = 'large'
    else:
        size = '32xlarge'
    
    type_class = 'G'
    remark = ''
    
    # Determine type class based on utilization (if provided) or CPU:Memory ratio
    if cpu_util is not None and mem_util is not None:
        # Handle utilization-based scaling
        if cpu_util >= 80 and mem_util >= 80:
            size_map = {
                '2xlarge': '4xlarge',
                '4xlarge': '8xlarge',
                '8xlarge': '12xlarge',
                '12xlarge': '16xlarge',
                '16xlarge': '24xlarge',
                '24xlarge': '32xlarge',
                '32xlarge': '32xlarge'
            }
            size = size_map.get(size.lower(), size)
            type_class = 'M'
            remark = 'Scaled up due to high CPU and memory utilization'
        elif cpu_util >= 80 and mem_util <= 80:
            size_map = {
                '2xlarge': '4xlarge',
                '4xlarge': '8xlarge',
                '8xlarge': '12xlarge',
                '12xlarge': '16xlarge',
                '16xlarge': '24xlarge',
                '24xlarge': '32xlarge',
                '32xlarge': '32xlarge'
            }
            size = size_map.get(size.lower(), size)
            type_class = 'G'
            remark = 'Scaled up due to high CPU utilization'
        elif cpu_util <= 80 and mem_util >= 80:
            type_class = 'M'
            remark = 'Memory-optimized due to high memory utilization'
        elif cpu_util < 50 and mem_util < 50:
            if size.lower() != 'xlarge':
                size_map = {
                    '2xlarge': 'xlarge',
                    '4xlarge': '2xlarge',
                    '8xlarge': '4xlarge',
                    '12xlarge': '8xlarge',
                    '16xlarge': '12xlarge',
                    '24xlarge': '16xlarge',
                    '32xlarge': '24xlarge'
                }
                size = size_map.get(size.lower(), size)
                remark = 'Scaled down due to low utilization'
            type_class = 'G'
    else:
        # No utilization data - use CPU:Memory ratio to determine type
        # Ratio > 4 indicates memory-intensive workload
        if original_cpu > 0:
            memory_cpu_ratio = original_memory_gb / original_cpu
            if memory_cpu_ratio > 4:
                type_class = 'M'
                remark = 'Memory-optimized based on CPU:Memory ratio'
            else:
                type_class = 'G'
    
    # Check for ultra-high memory (>1024 GB) - use db.x* instances
    if original_memory_gb > 1024:
        type_class = 'X'
        remark = 'Ultra-high memory instance (db.x*) for >1TB RAM'
    
    # Load CSV and find matching instances
    csv_path = Path(__file__).parent / 'AwsInstancescsv.csv'
    instances = []
    
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            instances.append(row)
    
    # Filter instances by size, edition, and version
    matches = [i for i in instances 
              if size in i['Instance Type'].lower()
              and i['Edition'] == edition
              and i['Version'] == str(version)]
    
    # Get unique instance types
    if matches:
        instance_types = list(set([m['Instance Type'].strip() for m in matches]))
        
        # Filter by type preference - match PowerShell logic
        if type_class == 'X':
            # Ultra-high memory: only db.x* instances
            filtered = [i for i in instance_types if i.startswith('db.x')]
            if filtered:
                instance_types = filtered
        elif type_class == 'M':
            # Memory optimized: exclude db.m*, db.r3*, db.r4*, db.t3*, db.x1*, db.x1e*
            filtered = [i for i in instance_types 
                       if not any(x in i for x in ['db.m', 'db.r3', 'db.r4', 'db.t3', 'db.x1', 'db.x1e'])]
            if filtered:
                instance_types = filtered
        elif type_class == 'G':
            # General purpose: only db.m* (no t3)
            filtered = [i for i in instance_types if i.startswith('db.m')]
            if filtered:
                instance_types = filtered
        
        # Sort by instance family and size for consistent primary selection
        # Prefer m6i > m5d, and smaller sizes first for the target size class
        def sort_key(inst):
            # Extract family (m6i, m5d) and size (xlarge, 2xlarge, etc)
            parts = inst.replace('db.', '').split('.')
            family = parts[0] if len(parts) > 0 else ''
            size_str = parts[1] if len(parts) > 1 else ''
            
            # Size priority: xlarge=1, 2xlarge=2, 4xlarge=4, etc
            size_multiplier = 1
            if 'xlarge' in size_str:
                if size_str == 'xlarge':
                    size_multiplier = 1
                else:
                    # Extract number from "24xlarge" -> 24
                    size_multiplier = int(size_str.replace('xlarge', '')) if size_str.replace('xlarge', '').isdigit() else 1
            
            # Family priority: m6i=1, m5d=2, r5=3, etc
            family_priority = {'m6i': 1, 'm5d': 2, 'r5': 3, 'r6i': 4}.get(family, 99)
            
            return (size_multiplier, family_priority)
        
        instance_types = sorted(instance_types, key=sort_key)
        
        return {
            'recommended_instances': instance_types,
            'primary_recommendation': instance_types[0] if instance_types else None,
            'type': type_class,
            'remark': remark
        }
    
    return {
        'recommended_instances': [],
        'primary_recommendation': None,
        'type': type_class,
        'remark': 'No matching instance found'
    }
