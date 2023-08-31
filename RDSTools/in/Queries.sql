declare @version sql_variant 
 declare @versionCheck varchar(2)
declare @sqlbelow2016 char(1)
select   @Version=SERVERPROPERTY ('productversion')
if (select substring(convert(char(5),@Version),1,2))>=12
set  @versioncheck ='N'
else set @versioncheck='Y'
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
declare @istsqlendpoint char(1)
declare @ispolybase char(1)
declare @ismemoptimized char(1)
declare @isfiletable Char(1)
declare @isbufferpoolextension char(1)
declare @isstretchDB char(1)
declare @istrustworthy char(1)
declare @Isservertrigger char(1)
declare @isRMachineLearning char(1)
declare @ISPolicyBased char(1)
declare @ISDQS char(1)
declare @isCLREnabled char(1)
--Select 'Linked Server'
select  *  from sys.servers where is_linked=1 and product<>'SQL Server' and  product <>'oracle'
--select ' sys admin '
SELECT   * FROM sys.databases d
                 INNER JOIN sys.server_principals sp ON d.owner_sid = sp.sid
                    WHERE sp.name  in (select  name
                        FROM     master.sys.server_principals
                            WHERE    IS_SRVROLEMEMBER ('sysadmin',name) = 1 and type_desc='SQL_LOGIN') and database_id>4
--select ' EE feature'
DECLARE @combinedString VARCHAR(MAX)
IF OBJECT_ID('tempdb.dbo.##enterprise_features') IS NOT NULL
                                   DROP TABLE ##enterprise_features
                                 CREATE TABLE ##enterprise_features
                                       (dbname       SYSNAME,feature_name VARCHAR(100),feature_id   INT )
                                        EXEC sp_msforeachdb N'USE [?] 
                                   IF (SELECT COUNT(*) FROM sys.dm_db_persisted_sku_features) >0 
                                           BEGIN 
                                             INSERT INTO ##enterprise_features 
                                                   SELECT   dbname=DB_NAME(),feature_name,feature_id   FROM sys.dm_db_persisted_sku_features
                                                       where feature_name not in (select feature_name from ##enterprise_features )
                                            END '
                                  SELECT  COALESCE(@combinedString + ', ', '') + feature_name              FROM   ##enterprise_features
                                                                                        
--select 'extended Proecdure'
SELECT * FROM master.sys.extended_procedures
--select ' Filestream'
select *  from sys.configurations where name like 'Filestream%'
--select 'Resource Governor'
select *  from sys.dm_resource_governor_configuration
--select 'Log Shipping '
select *  from msdb.dbo.log_shipping_primary_databases
--select 'Service Broker '
select *  from sys.service_broker_endpoints
--select ' Database count'
select count(*) as DBCount  from sys.databases where database_id>4
--select 'Transaction replication '
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
select  isnull(r.name,''),r.is_published , r.is_merge_published , r.is_distributor,isnull(s.is_subscribed,0) from ReplTabe R left join ##subscription s on r.name=s.name

--select 'DB Size'

SELECT round(sum((cast(size as bigint)*8))/1024/1024,2)
FROM master.sys.master_files where database_id>4

--select 'extended proc'
DECLARE @xplist AS TABLE
(
xp_name sysname,
source_dll nvarchar(255)
)
INSERT INTO @xplist
EXEC sp_helpextendedproc
SELECT 
    *                    FROM  sys.routes 
                    WHERE address != 'LOCAL'
--select 'poly base'
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

IF OBJECT_ID('tempdb.dbo.##filetable') IS NOT NULL
                                   DROP TABLE ##filetable
                                 CREATE TABLE ##filetable
                                       (DB Varchar(100),tablename varchar(100) )
                                        EXEC sp_msforeachdb N'USE [?] 
                                   IF exists(SELECT *  FROM sys.tables WHERE is_filetable = 1) 
                                           BEGIN 
                                               INSERT INTO ##filetable  select  ''?'',name FROM sys.tables WHERE is_filetable = 1

                                        end '
                                 SELECT *    from   ##filetable

----select 'Stretch DB '

select * from sys.configurations where name like 'remote data archive'
--select 'trust worthy'
SELECT *  FROM sys.databases WHERE DATABASE_ID>4 AND is_trustworthy_on >1
--select 'Server Trigger'
select *  from sys.server_triggers
--select 'R and Machine Learning '
select *  from sys.configurations where name like 'external scripts enabled'
--select'Data Quality Service'
select * from sys.databases where name like 'DQS%'
--select 'policy Based management'
select * from msdb.dbo.syspolicy_policy_execution_history_details
--Select 'CLR '
select  *  from sys.configurations where name like 'clr enabled%'
select  @isCLREnabled= case when (value_in_use=1 and @sqlbelow2016='Y') then 'N'
            when   (value_in_use=1 and @sqlbelow2016='N') then 'Y'
                     else 'N'
                end  from sys.configurations where name like 'clr enabled%'
       select @isCLREnabled
 
-- Database count
select @dbcount= case when count(*) > 100 then 'Y' else 'N' end  from sys.databases where database_id>4
--Elasticache Detailed report
--Detailed elasticache report RDSDiscovery
declare @totalWrite bigint
declare @totalread int 
declare @readoverwrite char(1)
 ; WITH Read_WriteIO (execution_count,query_text,[Total Logical Reads (MB)],TotalLogicalRead,TotalPhysicalRead,total_logical_writes,total_grant_kb)
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
), 
ReadOverWrite --( totalLogicalread,total_logical_writes, overallreadweight,readoverwriteweight)
as
(
select  top 50 query_text, totalLogicalread,total_logical_writes,([Total Logical Reads (MB)]*100)/(SELECT sum([Total Logical Reads (MB)]) from Read_WriteIO  ) as overallreadweight 
 ,((TotalLogicalRead*100)/nullif(totalLogicalread+total_logical_writes,0)) as readoverwriteweight --,
 --sum(((TotalLogicalRead*100)/nullif(totalLogicalread+total_logical_writes,0)))
 from Read_WriteIO order by overallreadweight desc
 )
 select * from ReadOverWrite 
 
