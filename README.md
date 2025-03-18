

[Automate SQL Server discovery and assessment to accelerate migration to AWS](https://aws.amazon.com/blogs/database/automate-sql-server-discovery-and-assessment-to-accelerate-migration-to-aws/)


## SqlServerTools
SQLServerTools is a repository dedicated to helping customers migrate their workload into AWS. The aim of this project is to ease the journey and make migration easier through automation and tooling.
## Would love to hear from you  please take few minutes to tell me what you think about the tool
https://app.smartsheet.com/b/form/8d23ba71313048b884876896b30a68d9


The tool consists of two main components: RDS Discovery and SQL Server Assessment.

1. RDS Discovery ( RDS Compatability check)
2. SQL Server Assessment

 
The following sections will discuss each of the previous tools.

## RDS Discovery 
The RDS Discovery Tool is a lightweight tool that provides the capability to scan a fleet of on-prem SQL Servers and does automated checks for 20+ features. It validates supportability of the enabled features on RDS and generates a report that provides recommendations to migrate to RDS, RDS Custom or EC2 compatible.

You can perform the initial assessment with RDS Discovery:

1. Gather a detailed SQL Server inventory that includes SQL Server version, edition, features, and high availability configuration such as FCI and Always On availability groups.
2. Assess Amazon RDS compatibility.
3. Identify SQL Server Enterprise edition features in use.


## SQL Server Assessment (SSAT)

The SQLServerAssessment Tool (SSAT) streamlines the evaluation of your on-premises SQL Server workloads to find the necessary system utilization for proper sizing on Amazon RDS. SSAT efficiently measures CPU, memory, IOPS, and throughput usage over a specified time frame, providing tailored suggestions to right-sizing your SQL Server on AWS. This tool is capable of assessing both single and multiple SQL Server instances.

## How and when to run those tools 
 The tools can run independently or in sequence. If you are starting from square one, we suggest starting with RDS Discovery where you capture all of your on-prem SQL Server features and determine if your fleet is RDS, RDS custom compatible, or maybe a combination of both.
 
After running the RDS Discovery tool, you can run the SQLServerAssessment (SSAT) tool to understand your SQL Server load in terms of CPU, Ram, and IOPS to right-size your SQL Server workload. SSAT is able (by default) to read the output generated from RDS Discovery or you can run pass on a list of servers that you would like to run an assessment against.

## Youtube RDSTools Videos and Demos 
https://www.youtube.com/@RdsTools




