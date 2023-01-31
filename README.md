# sqlservertools
This Repository is dedicated to help CX migrating their workload into AWS, what I am aiming here is to ease the journey and make thing easier through automation and tooling.

This repository has 2 tools:

1-	RdsDiscovery

2-	Sql server assessment 

## RDS Discovery 
RDS Discovery Tool is a lightweight, it provides a capability to scan a fleet of on-prem SQl Servers and does
automated checks for 20+features, validates supportability of the enabled features on RDS, and generates a
report which provides recommendation to migrate to RDS, RDS Custom or EC2 compatible.

## SqlServerAssessment (SSAT)
Sql server assessment tool is intended to simplifies the assessment of your SQL Server workloads on premise to determine system utilization required for
right sizing on Amazon RDS.
The tool captures CPU, Memory, IOPS and Throughput utilization based on predefined timeframe and make RDS suggestion on how to right size on AWS.
The tool can be run against a single or multiple MS SQL Server instance.

## How and When to run those tools 
The tools can run independently or in sequence. If you are starting from square one I suggest to start with RdsDiscovery were you capture all of your on prem Sql server
features and determine if your fleet is RDS, RDS custom compatible or maybe a combination of both.
 
After you run the RdsDiscovery tool you can run the SqlServerAssessment (SSAT) tool to understand your SQl server load in terms of CPU, Ram and IOPS and right Size your
Sql server instances.
SSAT is able (by default) to read the output generated from RdsDiscovery or you can run pass in a list of servers that you would like to run an assessment.


## What’s coming Next 
TCO (Total cost of ownership). A new module is in development at the moment will help in creating a TCO for all your Sql server fleet including cost optimization
and consolidation.

## Migration 
If you are looking for Sql Server DB migration solution check out this repository :
https://github.com/aws-samples/amazon-rds-for-sql-server-custom-log-shipping


