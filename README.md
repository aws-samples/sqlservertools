New Release: SSATWeb

Try it here: https://srepimhwyj.us-east-1.awsapprunner.com/

We’re excited to announce SSATWeb, a fully web-based version of the SQL Server Assessment Tool (SSAT).
Your feedback is welcome and appreciated as we continue improving the experience.

🔒 Note: Registration is required, but no data is collected, stored, or persisted. All information is processed in-memory to protect your privacy and security.

👉 Traditional method is still available for users who prefer running SSAT locally or via the original command-line workflow.

🔍 Automate SQL Server Discovery & Assessment for AWS Migrations

📘 AWS Blog:
Automate SQL Server discovery and assessment to accelerate migration to AWS
https://aws.amazon.com/blogs/database/automate-sql-server-discovery-and-assessment-to-accelerate-migration-to-aws/

📘 GitHub Project: SQLServerTools
A toolkit designed to help customers accelerate SQL Server migrations to AWS by automating discovery and workload assessment.

📣 Feedback Form:
We’d love to hear from you:
https://app.smartsheet.com/b/form/8d23ba71313048b884876896b30a68d9

🎥 Video Demos & Tutorials:
https://www.youtube.com/@RdsTools

🧰 Overview of SQLServerTools

SQLServerTools contains two core components that simplify and accelerate SQL Server modernization on AWS:

1️⃣ RDS Discovery (Compatibility Check)

A lightweight fleet-scanning tool that automatically evaluates 20+ SQL Server features for RDS supportability.

Key Capabilities:

Collects SQL Server inventory (version, edition, HA like FCI/AOAG, and enabled features)

Determines compatibility with RDS, RDS Custom, or EC2

Highlights dependency on Enterprise Edition features

Provides migration recommendations based on compatibility findings

This forms your starting point for understanding what migration paths are feasible.

2️⃣ SQL Server Assessment (SSAT)

SSAT analyzes SQL Server workload patterns to ensure accurate right-sizing on AWS.

What SSAT Measures:

CPU utilization

Memory consumption

IOPS and throughput

Peak vs average workload patterns

Output:
Tailored recommendations for RDS instance classes, storage types, and sizing options—based on your real SQL Server usage.

SSAT works with:

A list of servers you specify

Or automatically consumes results from RDS Discovery

🔄 Recommended Workflow (If Starting Fresh)
Step 1 — Run RDS Discovery

→ Understand SQL Server features and compatibility constraints

Step 2 — Run SSAT (or SSATWeb)

→ Right-size based on CPU/memory/IOPS workload patterns

This combined approach gives you feature readiness + performance sizing, eliminating guesswork and reducing migration friction.

🙏 We Welcome Your Feedback

Your input directly shapes future enhancements to RDS Discovery, SSAT, and SSATWeb.

👉 Feedback Form:
https://app.smartsheet.com/b/form/8d23ba71313048b884876896b30a68d9


