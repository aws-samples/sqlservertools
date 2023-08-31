declare @version sql_variant 
 declare @versionCheck varchar(2)
  declare @sqlbelow2016 char(1)
select   @Version=SERVERPROPERTY ('productversion')
if (select substring(convert(char(5),@Version),1,2))>=12
set  @versioncheck ='N'
else set @versioncheck='Y'
-- this is use for the CLR limitation
  if (select substring(convert(char(5),@Version),1,2))<=13
set @sqlbelow2016 ='Y'
else set @sqlbelow2016='N'
declare @isEEFeature char(1)
declare @islinkedserver char(1)
declare @issysadmin char(1)
declare @isextendedproc char(1)
declare @isFilestream char(1)
declare @isResouceGov char(1)
declare @issqlTLShipping char(1)
declare @issqlServiceBroker char(1)
declare @issqlTranRepl char(1)
declare @DBCount char(1)
declare @usedSpaceGB decimal(10,2)
declare @istsqlendpoint char(1)
declare @ispolybase char(20)
--declare @ismemoptimized char(1)
declare @isfiletable Char(1)
declare @isbufferpoolextension char(20)
Declare @isstretchDB char(1)
declare @istrustworthy char(1)
declare @Isservertrigger char(1)
declare @isrmachineLearning Char(1)
declare @ispolicyBased char(1)
declare @isdqs char(1)
declare @isclrenabled char(1)
Declare @isFree char(1)
declare @source char(3)
declare @IsAOCluster char(1)
declare @isAOAG Char(1)
DECLARE @isreadonly char(1)
DECLARE @role_desc varchar(20)
declare @IsElasticache varchar(100)
select  @islinkedserver= case when count(*)=0 then 'N' else 'Y' end   from sys.servers where is_linked=1 and product<>'SQL Server' and  product <>'oracle'
SELECT   @issysadmin=case when count(*)=0 then 'N' else 'Y' end FROM sys.databases d
                 INNER JOIN sys.server_principals sp ON d.owner_sid = sp.sid
                    WHERE sp.name  in (select  name
                        FROM     master.sys.server_principals
                            WHERE    IS_SRVROLEMEMBER ('sysadmin',name) = 1 and type_desc='SQL_LOGIN') and database_id>4
DECLARE @combinedString VARCHAR(MAX)
IF OBJECT_ID('tempdb.dbo.##enterprise_features') IS NOT NULL
                                   DROP TABLE ##enterprise_features
                                 CREATE TABLE ##enterprise_features
                                       (dbname       SYSNAME,feature_name VARCHAR(100),feature_id   INT )
                                        EXEC sp_msforeachdb N'USE [?] 
                                   IF (SELECT COUNT(*) FROM sys.dm_db_persisted_sku_features) >0 
                                           BEGIN 
                                              inSERT INTO ##enterprise_features 
                                                   SELECT   dbname=DB_NAME(),feature_name,feature_id   FROM sys.dm_db_persisted_sku_features
                                                   where feature_name COLLATE DATABASE_DEFAULT not in (select feature_name from ##enterprise_features )
                                            END '
                                  SELECT  @combinedString =COALESCE(@combinedString + ', ', '') + feature_name              FROM   ##enterprise_features
                                                                                        
 
SELECT @isextendedproc= case when count(*)=0 then 'N' else 'Y' end FROM master.sys.extended_procedures
-- Filestream
select  @isFilestream = case when value_in_use=0 then 'N'
          else  'Y' end  from sys.configurations where name like 'Filestream%'
--Resource Governor
select @isResouceGov= case when classifier_function_id=0 then 'N' else 'Y'end from sys.dm_resource_governor_configuration
--Log Shipping 
begin try
select @issqlTLShipping = case when count(*)=0 then 'N' else 'Y' end  from msdb.dbo.log_shipping_primary_databases
end try
begin Catch
select @source= case when count(*)>=1 then 'RDS'  else 'GCP' end FROM SYS.DATABASES where name='rdsadmin'  
end catch
--Service Broker 
select @issqlServiceBroker= case when count(*)=0 then 'N' else 'Y' end  from sys.service_broker_endpoints
-- Database count
select @dbcount= case when count(*) > 100 then 'Y' else 'N' end  from sys.databases where database_id>4
--Transaction replication 
 
 
IF OBJECT_ID('tempdb.dbo.##subscription') IS NOT NULL
drop table ##subscription
create table ##subscription(is_subscribed int,name varchar(100))
exec  sp_msforeachdb N'USE [?] ;
IF OBJECT_ID (N''dbo.syssubscriptions'', N''U'') IS NOT NULL 
   insert into ##subscription(is_subscribed,name) SELECT  1,''?'' else insert into ##subscription(is_subscribed,name) select 0,''?'' '
;with ReplTabe (name,is_published , is_merge_published , is_distributor)
as
(
select '',0,0,0
union
select   name,is_published , is_merge_published , is_distributor
                            from sys.databases where database_id>4 and  DATABASEPROPERTYex(name, 'Status')='online'
)
--select  isnull(r.name,''),r.is_published , r.is_merge_published , r.is_distributor,isnull(s.is_subscribed,0) from ReplTabe R left join ##subscription s on r.name=s.name
select @issqlTranRepl =case when sum (  case when r.is_published=1 or isnull(s.is_subscribed,0)=1 or r.is_merge_published=1 or r.is_distributor=1  then 1 else 0 end )=0 then 'N' else 'Y' end
from ReplTabe R left join ##subscription s on r.name=s.name
--DB Size
SELECT @UsedSpaceGB=isnull(round(sum((cast(size as bigint)*8))/1024/1024,2),0)
FROM master.sys.master_files where database_id>4
--extendedproc
DECLARE @xplist AS TABLE
(
xp_name sysname,
source_dll nvarchar(255)
)
INSERT INTO @xplist
EXEC sp_helpextendedproc
--Endpoints
SELECT 
    @istsqlendpoint=case when count(*)= 0 then 'N' else 'Y' end 
                    FROM  sys.routes 
                    WHERE address != 'LOCAL'
if @versionCheck='Y'
begin 
   set @ispolybase='Not Supported'
   set @isbufferpoolextension='Not Supported'
End
else 
Begin 
 --polybase
   SELECT
      @ispolybase=case when count(*)= 0 then 'N' else 'Y' end
                    FROM           sys.external_data_sources
-- buffer pool extension
   SELECT
   @isbufferpoolextension=case when count(*)= 0 then 'N' else 'Y' end           
                    FROM           sys.dm_os_buffer_pool_extension_configuration
                            WHERE      [state] != 0
end
 
--filetables
DECLARE @Filetable VARCHAR(MAX)
IF OBJECT_ID('tempdb.dbo.##filetable') IS NOT NULL
                                   DROP TABLE ##filetable
                                 CREATE TABLE ##filetable
                                       (tablecount   INT )
                                        EXEC sp_msforeachdb N'USE [?] 
                                   IF (SELECT COUNT(*)  FROM sys.tables WHERE is_filetable = 1) >0 
                                           BEGIN 
                                               INSERT INTO ##filetable  select  1
                                        end '
                                 SELECT @isfiletable=case when count(*)= 0 then 'N' else 'Y' end     from   ##filetable
--Stretch DB 
select @isstretchDB =case when value =0 then 'N' else 'Y' end from sys.configurations where name like 'remote data archive'
--trustworthy
SELECT @istrustworthy= CASE WHEN COUNT(*)=0 THEN 'N' else 'Y' end FROM sys.databases WHERE DATABASE_ID>4 AND is_trustworthy_on >1
--Server Trigger
select @Isservertrigger=case when count(*)=0 then 'N' else 'Y' end  from sys.server_triggers
--R and Machine Learning 
select @isRMachineLearning =case when value =0 then 'N' else 'Y' end  from sys.configurations where name like 'external scripts enabled'
--Data Quality Service
select @ISDQS= case when  count(0)=0  then 'N' else 'Y' end from sys.databases where name like 'DQS%'
--policy Based management
select @ISPolicyBased = case when  count(0)=0  then 'N' else 'Y' end from msdb.dbo.syspolicy_policy_execution_history_details
--CLR 
select  @isCLREnabled= case when (value_in_use=1 and @sqlbelow2016='Y') then 'N'
            when   (value_in_use=1 and @sqlbelow2016='N') then 'Y'
                     else 'N'
                end  from sys.configurations where name like 'clr enabled%'
--isfree 
SELECT @isfree='N'
--Is AG Always on  Enabled.
SELECT @isAOAG= case  when  count(*)>0  then 'Y' else 'N' end  from sys.dm_hadr_availability_replica_cluster_nodes  
--is Always On FCI enabled.
SELECT @IsAOCluster= case  when  count(*)>0  then 'Y' else 'N' end  FROM sys.dm_os_cluster_nodes; 
--Is read replica created 
DECLARE @result TABLE (
          dbname sysname
    , readonly varchar(10)
);
INSERT INTO @result
EXEC sp_MSforEachDB
'
SELECT  ''?'',convert(varchar(10),DATABASEPROPERTYEX(N''?'',''Updateability''))
';
SELECT @isreadonly= case when count(*)>0 then 'Y' else 'N' end  FROM @result where readonly <>'READ_WRITE'
---DB role
IF NOT EXISTS( SELECT 1 FROM sys.DATABASES d INNER JOIN sys.dm_hadr_availability_replica_states hars ON d.replica_id = hars.replica_id)
SELECT @role_desc = 'Standalone'
ELSE
-- else return if there is AN PRIMARY availability group PRIMARY else 'SECONDARY
IF EXISTS( SELECT distinct hars.role_desc FROM sys.DATABASES d INNER JOIN sys.dm_hadr_availability_replica_states hars ON d.replica_id = hars.replica_id WHERE hars.role_desc = 'PRIMARY' )
SELECT @role_desc = 'Primary' 
ELSE
SELECT @role_desc = 'Secondary' 
if  @isreadonly='Y' set @role_desc='Readable'
--Elasticache 
--declare  @totalread bigint 
declare @totalWrite bigint
declare @totalread int 
declare @readoverwrite char(1)
;WITH Read_WriteIO (execution_count,query_test,[Total Logical Reads (MB)],TotalLogicalRead,TotalPhysicalRead,total_logical_writes,total_grant_kb)
as 
(
SELECT    qs.execution_count
          , query_text = SUBSTRING( qt.text, qs.statement_start_offset / 2 + 1
            , ( CASE
                WHEN qs.statement_end_offset = -1 THEN LEN( CONVERT( nvarchar(MAX), qt.text )) * 2
                ELSE qs.statement_end_offset
                END - qs.statement_start_offset ) / 2 )
          ,(qs.total_logical_reads)*8/1024.0 AS [Total Logical Reads (MB)],
qs.total_logical_reads as [TotalLogicalRead],qs.total_physical_reads as TotalPhysicalRead,
qs.total_logical_writes, qs.total_grant_kb  
FROM        sys.dm_exec_query_stats               AS qs
CROSS APPLY sys.dm_exec_sql_text( qs.sql_handle ) AS qt
), ReadOverWrite ( totalLogicalread,total_logical_writes, overallreadweight,readoverwriteweight)
as
(
select  top 10 totalLogicalread,total_logical_writes,([Total Logical Reads (MB)]*100)/(SELECT sum([Total Logical Reads (MB)]) from Read_WriteIO  ) as overallreadweight 
 ,((TotalLogicalRead*100)/nullif(totalLogicalread+total_logical_writes,0)) as readoverwriteweight --,
 --sum(((TotalLogicalRead*100)/nullif(totalLogicalread+total_logical_writes,0)))
 from Read_WriteIO order by overallreadweight desc
 )

  select @IsElasticache=case when sum(readoverwriteweight)/10 >90 then 'Server/DB can benefit from Elasticache,check detailed read vs write query in rdstools\in\queries' else 'N' end from ReadOverWrite

  ------------------------
select @combinedString as isEEFeature,@isextendedproc as isextendedproc,@isFilestream AS isFilestream,@islinkedserver AS islinkedserver,
@isResouceGov AS isResouceGov,@issqlServiceBroker AS issqlServiceBroker ,@issqlTLShipping AS issqlTLShipping,@issqlTranRepl AS issqlTranRepl ,
@issysadmin AS issysadmin,@dbcount as dbcount, @istsqlendpoint as istsqlendpoint,@ispolybase as ispolybase,@isfiletable as isfiletable,
@isbufferpoolextension as isbufferpoolextension,@isstretchDB as isstretchDB,@istrustworthy as istrustworthy,@Isservertrigger as Isservertrigger,
@isRMachineLearning as isRMachineLearning,@ISDQS as ISDQS, @ISPolicyBased  as ISPolicyBased , @isCLREnabled as isCLREnabled,@UsedSpaceGB as UsedSpaceGB,@isAOAG as IsAlwaysOnAG,@IsAOCluster as isalwaysonFCI,
@isreadonly as IsReadReplica,@role_desc as DBRole,@IsElasticache as IsElasticache,@isfree as isfree ,case when @source is null then 'EC2/onPrem' else @source end as source

