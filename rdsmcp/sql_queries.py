"""
SQL Server Assessment Queries - Exact port from PowerShell RDS Discovery Tool
"""

# Single comprehensive query that matches PowerShell exactly
FULL_ASSESSMENT_QUERY = """
declare @version sql_variant 
declare @versioncheck varchar(2)
declare @sqlbelow2016 char(1)
select @version=SERVERPROPERTY ('productversion')
if (select substring(convert(char(5),@version),1,2))>=12
set @versioncheck ='N'
else set @versioncheck='Y'
if (select substring(convert(char(5),@version),1,2))<=13
set @sqlbelow2016 ='Y'
else set @sqlbelow2016='N'

declare @islinkedserver char(1)
declare @isextendedproc char(1)
declare @isFilestream char(1)
declare @isResouceGov char(1)
declare @issqlTLShipping char(1)
declare @issqlServiceBroker char(1)
declare @issqlTranRepl char(1)
declare @dbcount char(1)
declare @UsedSpaceGB decimal(10,2)
declare @istsqlendpoint char(1)
declare @ispolybase char(20)
declare @isfiletable Char(1)
declare @isbufferpoolextension char(20)
Declare @isstretchDB char(1)
declare @istrustworthy char(1)
declare @Isservertrigger char(1)
declare @isRMachineLearning Char(1)
declare @ispolicybased char(1)
declare @isdqs char(1)
declare @isclrenabled char(1)
declare @IsAOCluster char(1)
declare @isAOAG Char(1)
DECLARE @isreadonly char(1)
DECLARE @role_desc varchar(20)
DECLARE @source varchar(20)
DECLARE @isEEFeature varchar(max)
DECLARE @isSSSIS char(1)
DECLARE @isSSRS char(1)

SET @isEEFeature = ''

select @islinkedserver= case when count(*)=0 then 'N' else 'Y' end from sys.servers where is_linked=1 and product<>'SQL Server' and product <>'oracle'

SELECT @isextendedproc= case when count(*)=0 then 'N' else 'Y' end FROM master.sys.extended_procedures

select @isFilestream = case when value_in_use=0 then 'N' else 'Y' end from sys.configurations where name like 'filestream%'

select @isResouceGov= case when classifier_function_id=0 then 'N' else 'Y'end from sys.dm_resource_governor_configuration

begin try
select @issqlTLShipping = case when count(*)=0 then 'N' else 'Y' end from msdb.dbo.log_shipping_primary_databases
end try
begin Catch
select @source= case when count(*)>=1 then 'RDS'  else 'GCP' end FROM SYS.DATABASES where name='rdsadmin'
end catch

select @issqlServiceBroker= case when count(*)=0 then 'N' else 'Y' end from sys.service_broker_endpoints

select @dbcount= case when count(*) > 100 then 'Y' else 'N' end from sys.databases where database_id>4

-- Get actual database count for DBC output
DECLARE @actual_db_count int
SELECT @actual_db_count = count(*) from sys.databases where database_id>4

IF OBJECT_ID('tempdb.dbo.##subscription') IS NOT NULL
drop table ##subscription
create table ##subscription(is_subscribed int,name varchar(100))
exec sp_MSforeachdb N'USE [?] ;
IF OBJECT_ID (N''dbo.syssubscriptions'', N''U'') IS NOT NULL 
   insert into ##subscription(is_subscribed,name) SELECT 1,''?'' ; else insert into ##subscription(is_subscribed,name) select 0,''?'' '
;with ReplTabe (name,is_published , is_merge_published , is_distributor)
as
(
select '',0,0,0
union
select name,is_published , is_merge_published , is_distributor
from sys.databases where database_id>4 and DATABASEPROPERTYex(name, 'Status')='online'
)
select @issqlTranRepl =case when sum (case when r.is_published=1 or isnull(s.is_subscribed,0)=1 or r.is_merge_published=1 or r.is_distributor=1 then 1 else 0 end )=0 then 'N' else 'Y' end
from ReplTabe r left join ##subscription s on r.name=s.name

SELECT @UsedSpaceGB=isnull(round(sum((cast(size as bigint)*8))/1024/1024,2),0)
FROM master.sys.master_files where database_id>4

-- Get total storage (all databases including system)
DECLARE @TotalStorageGB decimal(10,2)
SELECT @TotalStorageGB=isnull(round(sum((cast(size as bigint)*8))/1024/1024,2),0)
FROM master.sys.master_files

SELECT @istsqlendpoint=case when count(*)= 0 then 'N' else 'Y' end FROM sys.routes WHERE address != 'LOCAL'

if @versioncheck='Y'
begin 
   set @ispolybase='Not Supported'
   set @isbufferpoolextension='Not Supported'
End
else 
Begin 
   -- PolyBase check with error handling (SQL 2016+)
   BEGIN TRY
       IF EXISTS (SELECT * FROM sys.all_objects WHERE name = 'external_data_sources' AND type = 'V')
           SELECT @ispolybase=case when count(*)= 0 then 'N' else 'Y' end FROM sys.external_data_sources
       ELSE
           SET @ispolybase = 'Not Supported'
   END TRY
   BEGIN CATCH
       SET @ispolybase = 'Not Supported'
   END CATCH
   
   -- Buffer Pool Extension check with error handling (SQL 2014+)
   BEGIN TRY
       IF EXISTS (SELECT * FROM sys.all_objects WHERE name = 'dm_os_buffer_pool_extension_configuration' AND type = 'V')
           SELECT @isbufferpoolextension=case when count(*)= 0 then 'N' else 'Y' end FROM sys.dm_os_buffer_pool_extension_configuration WHERE [state] != 0
       ELSE
           SET @isbufferpoolextension = 'Not Supported'
   END TRY
   BEGIN CATCH
       SET @isbufferpoolextension = 'Not Supported'
   END CATCH
end

if (select substring(convert(char(5),@version),1,2))<>'10'
begin
IF OBJECT_ID('tempdb.dbo.##filetable') IS NOT NULL
DROP TABLE ##filetable
CREATE TABLE ##filetable (tablecount INT)
EXEC sp_MSforeachdb N'USE [?] 
IF (SELECT COUNT(*) FROM sys.tables WHERE is_filetable = 1) >0 
BEGIN 
    INSERT INTO ##filetable select 1
end '
SELECT @isfiletable=case when count(*)= 0 then 'N' else 'Y' end from ##filetable
end
else set @isfiletable='Not Supported'

select @isstretchDB =case when value =0 then 'N' else 'Y' end from sys.configurations where name like 'remote data archive'

SELECT @istrustworthy= CASE WHEN COUNT(*)=0 THEN 'N' else 'Y' end FROM sys.databases WHERE DATABASE_ID>4 AND is_trustworthy_on >1

select @Isservertrigger=case when count(*)=0 then 'N' else 'Y' end from sys.server_triggers

select @isRMachineLearning =case when value =0 then 'N' else 'Y' end from sys.configurations where name like 'external scripts enabled'

select @isdqs= case when count(0)=0 then 'N' else 'Y' end from sys.databases where name like 'DQS%'

select @ispolicybased = case when count(0)=0 then 'N' else 'Y' end from msdb.dbo.syspolicy_policy_execution_history_details

select @isclrenabled= case when (value_in_use=1 and @sqlbelow2016='Y') then 'N'
            when (value_in_use=1 and @sqlbelow2016='N') then 'Y'
            else 'N'
        end from sys.configurations where name like 'clr enabled%'

SELECT @isAOAG = CASE WHEN SERVERPROPERTY('IsHadrEnabled') = 1 THEN 'Y' ELSE 'N' END

SELECT @IsAOCluster = CASE WHEN SERVERPROPERTY('IsClustered') = 1 THEN 'Y' ELSE 'N' END

-- Initialize defaults first (CRITICAL FIX)
SET @role_desc = 'Standalone'
SET @isreadonly = 'N'

-- Determine the actual role of this server
IF @isAOAG = 'Y'
BEGIN
    -- Only check for roles if AG is actually enabled
    IF EXISTS (SELECT * FROM sys.dm_hadr_availability_replica_states 
               WHERE is_local = 1 AND role_desc = 'PRIMARY')
    BEGIN
        SET @role_desc = 'Primary'
        SET @isreadonly = 'N'
    END
    ELSE IF EXISTS (SELECT * FROM sys.dm_hadr_availability_replica_states 
                    WHERE is_local = 1 AND role_desc = 'SECONDARY')
    BEGIN
        -- Check if it's configured as readable secondary
        IF EXISTS (SELECT * FROM sys.availability_replicas ar
                   INNER JOIN sys.dm_hadr_availability_replica_states ars 
                   ON ar.replica_id = ars.replica_id
                   WHERE ars.is_local = 1 
                   AND ar.secondary_role_allow_connections_desc IN ('READ_ONLY', 'ALL'))
        BEGIN
            SET @role_desc = 'Readable'
            SET @isreadonly = 'Y'
        END
        ELSE
        BEGIN
            SET @role_desc = 'Secondary'
            SET @isreadonly = 'N'
        END
    END
    -- If AG is enabled but no role found, keep default 'Standalone'
END
-- If AG is not enabled, keep default 'Standalone'

-- Check for Enterprise Edition features in use
BEGIN TRY
    IF OBJECT_ID('tempdb.dbo.##enterprise_features') IS NOT NULL
        DROP TABLE ##enterprise_features
    CREATE TABLE ##enterprise_features (dbname SYSNAME, feature_name VARCHAR(100), feature_id INT)
    
    -- Check if DMV exists before using it (SQL 2012 SP1+)
    IF EXISTS (SELECT * FROM sys.all_objects WHERE name = 'dm_db_persisted_sku_features' AND type = 'V')
    BEGIN
        EXEC sp_MSforeachdb N'USE [?] 
            BEGIN TRY
                IF (SELECT COUNT(*) FROM sys.dm_db_persisted_sku_features) > 0 
                BEGIN 
                    INSERT INTO ##enterprise_features 
                    SELECT dbname=DB_NAME(), feature_name, feature_id FROM sys.dm_db_persisted_sku_features
                    WHERE feature_name COLLATE DATABASE_DEFAULT NOT IN (SELECT feature_name FROM ##enterprise_features)
                END
            END TRY
            BEGIN CATCH
                -- Skip databases where DMV is not accessible
            END CATCH'
    END
    
    SELECT @isEEFeature = COALESCE(@isEEFeature + ', ', '') + feature_name FROM ##enterprise_features
END TRY
BEGIN CATCH
    SET @isEEFeature = ''
END CATCH
IF @isEEFeature IS NULL OR @isEEFeature = '' SET @isEEFeature = ''

-- SSIS (SQL Server Integration Services) Check
IF (SELECT SUBSTRING(CONVERT(CHAR(5), @version), 1, 2)) >= 11
BEGIN
    SELECT @isSSSIS = CASE 
        WHEN EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SSISDB') THEN 'Y'
        ELSE 'N'
    END
    IF @isSSSIS = 'N'
    BEGIN
        BEGIN TRY
            SELECT @isSSSIS = CASE 
                WHEN EXISTS (
                    SELECT 1 FROM msdb.dbo.sysssispackages p
                    INNER JOIN msdb.dbo.sysssispackagefolders f ON p.folderid = f.folderid
                    WHERE f.foldername NOT IN ('Data Collector')
                ) THEN 'Y'
                ELSE 'N'
            END
        END TRY
        BEGIN CATCH
            SET @isSSSIS = 'N'
        END CATCH
    END
END
ELSE
BEGIN
    BEGIN TRY
        SELECT @isSSSIS = CASE 
            WHEN EXISTS (
                SELECT 1 FROM msdb.dbo.sysssispackages p
                INNER JOIN msdb.dbo.sysssispackagefolders f ON p.folderid = f.folderid
                WHERE f.foldername NOT IN ('Data Collector')
            ) THEN 'Y'
            ELSE 'N'
        END
    END TRY
    BEGIN CATCH
        SET @isSSSIS = 'N'
    END CATCH
END

-- SSRS (SQL Server Reporting Services) Check
SELECT @isSSRS = CASE 
    WHEN EXISTS (SELECT 1 FROM sys.databases WHERE name LIKE 'ReportServer%') THEN 'Y'
    ELSE 'N'
END
IF @isSSRS = 'N'
BEGIN
    SELECT @isSSRS = CASE 
        WHEN EXISTS (SELECT 1 FROM sys.databases WHERE name IN ('ReportServer', 'ReportServerTempDB')) THEN 'Y'
        ELSE 'N'
    END
END

select 
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    CAST(SERVERPROPERTY('IsClustered') AS INT) AS IsClustered,
    (select cpu_count from sys.dm_os_sys_info) AS CPU,
    (SELECT CONVERT(int, value_in_use)/1024 FROM sys.configurations WHERE name LIKE 'max server memory%') AS MaxMemory,
    @isextendedproc as isextendedproc,
    @isFilestream AS isFilestream,
    @islinkedserver AS islinkedserver,
    @isResouceGov AS isResouceGov,
    @issqlServiceBroker AS issqlServiceBroker,
    @issqlTLShipping AS issqlTLShipping,
    @issqlTranRepl AS issqlTranRepl,
    @dbcount as dbcount,
    @istsqlendpoint as istsqlendpoint,
    @ispolybase as ispolybase,
    @isfiletable as isfiletable,
    @isbufferpoolextension as isbufferpoolextension,
    @isstretchDB as isstretchDB,
    @istrustworthy as istrustworthy,
    @Isservertrigger as Isservertrigger,
    @isRMachineLearning as isRMachineLearning,
    @isdqs as ISDQS,
    @ispolicybased as ISPolicyBased,
    @isclrenabled as isCLREnabled,
    @UsedSpaceGB as UsedSpaceGB,
    @isAOAG as IsAlwaysOnAG,
    @IsAOCluster as isalwaysonFCI,
    @isreadonly as IsReadReplica,
    @role_desc as DBRole,
    case when @source is null then 'EC2/OnPrem' else @source end as Source,
    @isEEFeature as isEEFeature,
    @isSSSIS as isSSSIS,
    @isSSRS as isSSRS,
    @actual_db_count as ActualDBCount,
    @TotalStorageGB as TotalStorageGB
"""
