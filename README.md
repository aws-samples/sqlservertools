https://aws.amazon.com/blogs/database/automate-sql-server-discovery-and-assessment-to-accelerate-migration-to-aws/

# SqlServerTools
SQLServerTools is a repository dedicated to helping customers migrate their workload into AWS. The aim of this project is to ease the journey and make migration easier through automation and tooling.
# Would love to hear from you  please take few minutes to tell me what you think about the tool
https://app.smartsheet.com/b/form/8d23ba71313048b884876896b30a68d9


This repository has two tools:


1. RDS Discovery
2. SQL Server Assessment

 
The following sections will discuss each of the previous tools.

## RDS Discovery 
The RDS Discovery Tool is a lightweight tool that provides the capability to scan a fleet of on-prem SQL Servers and does automated checks for 20+ features. It validates supportability of the enabled features on RDS and generates a report that provides recommendations to migrate to RDS, RDS Custom or EC2 compatible.

## SqlServerAssessment (SSAT)
SQLServerAssessment (SSAT) The SQL Server Assessment Tool simplifies the assessment of your SQL Server workloads on-premise to determine the system utilization required for right-sizing on Amazon RDS. The tool captures CPU, Memory, IOPS and Throughput utilization based on a predefined timeframe and makes RDS suggestions on how to right-size on AWS. The tool can be run against a single or multiple MS SQL Server instances.

## How and when to run those tools 
 The tools can run independently or in sequence. If you are starting from square one, we suggest starting with RDS Discovery where you capture all of your on-prem SQL Server features and determine if your fleet is RDS, RDS custom compatible, or maybe a combination of both.
 
After running the RDS Discovery tool, you can run the SQLServerAssessment (SSAT) tool to understand your SQL Server load in terms of CPU, Ram, and IOPS and right-size your SQL Server instances. SSAT is able (by default) to read the output generated from RDS Discovery or you can run pass on a list of servers that you would like to run an assessment against.
## Youtube RDSTools Videos and Demos 
https://www.youtube.com/@RdsTools



