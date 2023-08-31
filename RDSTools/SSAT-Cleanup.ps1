 
Param (
  [Parameter()][string]$auth,
  [Parameter()][string]$login,
  [Parameter()][string]$password,
  [Parameter()]$collectiontime = 60,
  [Parameter()]$sqlserverendpoint = 'C:\RDSTools\out\RdsDiscovery.csv',
  [Parameter()]$sa = 'sa',
  [Parameter()]$DBName = 'sample',
  [parameter()][array]$options,
  [parameter()][String] $Elasticache='N'
)
Function ElasticacheAssessment
{
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Password
  )
  
$ReadOverall='  SELECT 
      case when (sum(convert(bigint,[read]))*100)/(sum(convert(bigint,[read]))+sum(convert(bigint,[written]))) > 90 
      then ''Server qualify for Elasticache'' else ''Not Elasticache compatible,but check the detailed report for db level Metrics''
        end as Elasticache
      FROM [dbo].[SQL_DBIO]
      where [read]>0 and dbname <>''tempdb''
        '

$readPerDB='SELECT 
     sum(convert(int,[read])) as [read] 
      ,sum(convert(int,[Written])) as write
	  ,(sum(convert(int,[read]))+sum(convert(int,[written]))) as total
	  ,(sum(convert(bigint,[read]))*100)/(sum(convert(bigint,[read]))+sum(convert(bigint,[written]))) AS ''PercentageofRead''
	  ,dbname
      
  FROM [dbo].[SQL_DBIO]
  where [read]>0 and dbname <>''tempdb''
  group by dbname '
  if ($auth -eq 's')
      {$ElasticAssessoutput= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $ReadOverall -password $password
       $Elasticreport= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $readPerDB -password $password
      
      }
  else {$ElasticAssessoutput= invoke-sqlcmd -serverInstance $dbserver -Database $dbname  -query $ReadOverall 
        $Elasticreport= invoke-sqlcmd -serverInstance $dbserver -Database $dbname -query $readPerDB 
   }

  $targetfile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_Elasticache.csv"
   #$Elasticreport | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $targetfile
   $Elasticreport|Export-Csv -Path  $targetfile  


  return $ElasticAssessoutput
}

Function Terminate_Job {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$password
  )
  write-host "Terminate Collection Job for Server $dbServer"
  $sql = "update $DBName.dbo.SQL_CollectionStatus set jobstatus='Finished'  ,Current_Sample_ID=Max_Sample_ID"
  if ( $auth -eq 'W')
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -query $sql }
  else { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
}#terminate Job
function DB_level {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Password
  )
  
$DBLEVELsql='dECLARE @total_buffer INT;
                    SELECT @total_buffer = cntr_value
                    FROM sys.dm_os_performance_counters
                    WHERE RTRIM([object_name]) LIKE ''%Buffer Manager''
                    AND counter_name = ''Database Pages'';
                    ;with DBSize (DBNAME,database_id,Size)
                    as
                    (
                    sELECT db_name(database_id),database_id,sum(size*8)/1024/1024.0
                    FROM master.sys.master_files where database_id>4
                    group by database_id
                    ),
                    src AS
                    (
                      SELECT
                      database_id, db_buffer_pages = COUNT_BIG(*)
                      FROM sys.dm_os_buffer_descriptors
                      --WHERE database_id BETWEEN 5 AND 32766
                      GROUP BY database_id
                    ),
                     latency as
                    (
                    SELECT  DB_NAME(vfs.database_id) as dbname,
      UM( CAST((io_stall_read_ms + io_stall_write_ms)/(1.0 + num_of_reads + num_of_writes) AS NUMERIC(10,1)) )AS [Average Total Latency]
                    FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
                    where database_id>4 and database_id<32760
                    group by DB_NAME(vfs.database_id)
                    ),
                    IOPs as
                    (
                    SELECT --top (select  count(distinct database_id) from [$DBName].[dbo].[SQL_DBIO])
                    database_id,sample_id,isnull(sum(Totaliops)/60,0) as Max_IOPS,
                    isnull(((sum(bread+bwritten)/60)/1048576),0) as Max_Throughput
                           FROM [$DBName].[dbo].[SQL_DBIO]
						    where Totaliops>0
            roup by database_id,sample_id
                        --    order by Max_IOPS desc
                    )
					
                    SELECT d.database_id,
                    [db_name] = CASE s.[database_id] WHEN 32767
                    THEN ''Resource DB''
                    ELSE DB_NAME(s.[database_id]) END,
                    db_buffer_pages,
                    db_buffer_MB = db_buffer_pages / 128,
                    db_buffer_percent = CONVERT(DECIMAL(6,3),
                    db_buffer_pages * 100.0 / @total_buffer),
                    d.Size,
                    isnull(i.Max_IOPS,0) as TotalIops,
                    isnull(i.Max_Throughput,0)as Throughput,
                    l.[Average Total Latency]
                    FROM src s left join dbsize d on S.database_id=d.database_id left join latency L  on d.database_id=db_id(l.dbname)
                    left join iops i on db_id(l.dbname)=i.Database_ID
					where d.database_id is not null
                    ORDER BY db_buffer_MB DESC;'   
                                         
  if ($auth -eq 'W')
  { $DBLEVEL = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -query $dblevelsql }
  else { $dblevel = invoke-sqlcmd -serverInstance $dbserver -Database $dbname -user $User -query $dblevelsql -password $Password }
  $targetfile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_dbmem.csv"
 # $dblevel | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $targetfile
  $DBLEVEL |Export-Csv -Path  $targetfile    
      
      #$TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    #$SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile



  
}#function db_memory
function Create-SQLtables {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass,
    [Parameter(Mandatory = $False)]$samples
  )
  #There is a variable for $samples in the SQL statement below.
  #write-host "Calling Create-SQLTables for server $dbserver"
  $sql = "
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIORaw'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIOTotal];
                      END
               IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIO'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIO];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CollectionStatus'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CollectionStatus];
                      END
                     If (EXISTS(SELECT * FROM msdb.dbo.sysjobs WHERE (name = N'SQL_IOCollection')))
                      BEGIN
                                 EXEC msdb.dbo.sp_delete_job @job_name=N'SQL_IOCollection'
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_MemCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_MemCollection];
                      END
                     IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CPUCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CPUCollection];
                     END
        /*******Memory collection table ****/
            create table SQL_MemCollection
            (
            SQL_ColletionTime  Datetime,
           SQLCurrMemUsageMB  decimal(12,2),
            SQLMaxMemTargetMB int,
            OSTotalMemoryMB    int,
            OSAVAMemoryMB      int,
            PLE               int
            )
        /*****Cpu collection table *****/
        create table SQL_CPUCollection
        (
         SqlSerCpuUT int,
         SystemIdle int,
         OtherProCpuUT int,
         Collectiontime datetime
         )
                      /****** Create SQL_CollectionStatus Table ******/
                      CREATE TABLE [dbo].[SQL_CollectionStatus](
                                [JobStatus] [nvarchar](10) NOT NULL,
                                 [SPID] [int] NOT NULL,
                                 [CollectionStartTime] [datetime] NOT NULL,
                                 [CollectionEndTime] [datetime] NULL,
                                 [Max_Sample_ID] [bigint] NOT NULL,
                                 [Current_Sample_ID] [bigint] NOT NULL
                      ) ON [PRIMARY]
                      /****** Insert Data -- INCLUDES VARIABLE FROM PARENT SCRIPT -- ******/
                      Declare @Total_Samples bigint
                      Select @Total_Samples = $Samples
                      INSERT dbo.SQL_CollectionStatus (JobStatus, SPID, CollectionStartTime, Max_Sample_ID, Current_Sample_ID)
                      SELECT 'Running',@@SPID,GETDATE(),@Total_Samples,0;
                      /****** Create SQL_DBIOTotal Table  ******/
                      CREATE TABLE [dbo].[SQL_DBIOTotal](
                                 [Sample_ID] [bigint] NOT NULL,
                                 [Database_ID] [int] NULL,
                                 [DBName] [nvarchar](400) NOT NULL,
                                 [Read] [bigint] NOT NULL,
                                 [Written] [bigint] NOT NULL,
                                 [BRead] [bigint] NOT NULL,
                                 [BWritten] [bigint] NOT NULL,
                                 [Throughput] [bigint] NOT NULL,
                                 [TotalIOPs] [bigint] NOT NULL,
                                 [NetPackets] bigint,
                                 [CollectionTime] [datetime] NOT NULL
                                 ) ON [PRIMARY]
                      /****** Create SQL_DBIO Table  ******/
                      CREATE TABLE [dbo].[SQL_DBIO](
                                 [Sample_ID] [bigint] NOT NULL,
                                 [Database_ID] [bigint] NOT NULL,
                                 [DBName] [nvarchar](400) NOT NULL,
                                -- [MBRead] [real] NOT NULL,
                                 --[MBWritten] [real] NOT NULL,
                                 [Read] [bigint] NOT NULL,
                                 [Written] [bigint] NOT NULL,
                                 [BRead] [bigint] NOT NULL,
                                 [BWritten] [bigint] NOT NULL,
                                 [TotalB] [bigint] NOT NULL,
                                 [TotalIOPs] [bigint] NOT NULL,
                                 [Throuput] [bigint] Not Null,
                                 [Netpackets] bigint ,
                                 [CollectionTime] [datetime] NOT NULL
                                  ) ON [PRIMARY]
                      /****** Create SQL_IOCollection Agent  ******/
                      BEGIN TRANSACTION
                      DECLARE @ReturnCode INT
                      SELECT @ReturnCode = 0
                      /****** Object:  JobCategory [[Uncategorized (Local)]]]                     ******/
                      IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
                      BEGIN
                      EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                      END
                      DECLARE @jobId BINARY(16)
                      EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SQL_IOCollection',
                                            @enabled=1,
                                            @notify_level_eventlog=0,
                                            @notify_level_email=0,
                                            @notify_level_netsend=0,
                                           @notify_level_page=0,
                                            @delete_level=0,
                                           @category_name=N'[Uncategorized (Local)]',
                                           @job_id = @jobId OUTPUT
                   IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                      /****** Object:  Step [Check_Status]                                                                  ******/
                      EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Check_Status',
                                           @step_id=1,
                                            @cmdexec_success_code=0,
                                            @on_success_action=1,
                                         @on_success_step_id=0,
                                           @on_fail_action=2,
                                            @on_fail_step_id=0,
                                            @retry_attempts=0,
                                           @retry_interval=0,
                                           @os_run_priority=0, @subsystem=N'TSQL',
                                            @command=N'SET QUOTED_IDENTIFIER ON
GO
                     Declare @Current_Sample_ID Bigint
                      If (Select Max_Sample_ID - Current_Sample_ID  from SQL_CollectionStatus) >  0
                                 BEGIN
                                 update dbo.SQL_CollectionStatus
                                 set Current_Sample_ID  = Current_Sample_ID  + 1
                                 Set @Current_Sample_ID = (Select Current_Sample_ID from SQL_CollectionStatus);
                                 INSERT dbo.SQL_DBIOTotal
                                            SELECT
                                           @Current_Sample_ID,
                                            d.Database_ID,
                                          d.name,
                                            SUM(fs.num_of_reads ),
                                            SUM(fs.num_of_writes),
                                            SUM(fs.num_of_bytes_read ),
                                            SUM(fs.num_of_bytes_written),
                                            SUM((fs.num_of_bytes_read)+(fs.num_of_bytes_written)) ,
                                            SUM(fs.num_of_reads + fs.num_of_writes) ,
                                            (select Sum(net_packet_size) as Total_net_packets_used from sys.dm_exec_connections),
                                            GETDATE()
                                 FROM sys.dm_io_virtual_file_stats(default, default) AS fs
                                            INNER JOIN sys.databases d (NOLOCK) ON d.Database_ID = fs.Database_ID
                                 WHERE d.name NOT IN (''master'',''model'',''msdb'', ''distribution'', ''ReportServer'',''ReportServerTempDB'')
                                 and d.state = 0
                                 GROUP BY d.name, d.Database_ID;
                                 Insert into SQL_DBIO
                                 Select @Current_Sample_ID,
                                DR1.Database_ID,
                                 DR1.DBName,
                                 DR2.[Read] - DR1.[Read],
                                 DR2.[Written] - DR1.[Written],
                                 DR2.[BRead] - DR1.[BRead],
                                 DR2.[BWritten] - DR1.[BWritten],
                                 DR2.Throughput - DR1.Throughput,
                                 DR2.TotalIOPs - DR1.TotalIOPs,
                                 ((DR2.TotalIOPs - DR1.TotalIOPs)*64)/1024,
                                 DR2.NetPackets - DR1.NetPackets,
                                 DR2.CollectionTime
                                 from dbo.SQL_DBIOTotal as DR1
                                 Inner Join dbo.SQL_DBIOTotal as DR2 ON DR1.Database_ID = DR2.Database_ID
                                 where DR1.Sample_ID = @Current_Sample_ID -1
                                 and DR2.Sample_ID = @Current_Sample_ID;
                                 END
                      Else
                                 BEGIN
                                 update dbo.SQL_CollectionStatus
                                 set [JobStatus] = ''Finished'',
                                 [CollectionEndTime] = GETDATE()
                                 EXEC msdb.dbo.sp_update_job @job_name=N''SQL_IOCollection'',
                                 @enabled=0
                     END
                            go
                        DECLARE @ts_now bigint = (SELECT ms_ticks FROM sys.dm_os_sys_info WITH (NOLOCK));
                            insert into SQL_CPUCollection
                        SELECT TOP(1) SQLProcessUtilization AS [SQL Server Process CPU Utilization],
                                       SystemIdle AS [System Idle Process],
                                       100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization],
                                       DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time]
                        FROM (SELECT record.value(''(./Record/@id)[1]'', ''int'') AS record_id,
                                      record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'',''int'')
                                              AS [SystemIdle],
                                      record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'')
                                              AS [SQLProcessUtilization], [timestamp]
                                 FROM (SELECT [timestamp], CONVERT(xml, record) AS [record]
                                              FROM sys.dm_os_ring_buffers WITH (NOLOCK)
                                              WHERE ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR''
                                              AND record LIKE N''%<SystemHealth>%'') AS x) AS y
                        ORDER BY record_id DESC
                        go
                        insert into SQL_MemCollection
                        select x.*,y.*,z.* from (SELECT       getdate() as collectionTime,(committed_kb/1024) as Commited,(committed_target_kb/1024)  as targetcommited FROM sys.dm_os_sys_info)  as x,
                           (   SELECT        (total_physical_memory_kb/1024) as totalMem,(available_physical_memory_kb/1024) as AvaiMem FROM sys.dm_os_sys_memory) as y,
                           (SELECT sum(cntr_value)/count(*)  as PLE FROM sys.dm_os_performance_counters WHERE counter_name = ''Page Life expectancy''    AND object_name LIKE ''%buffer node%'') as Z',
                                            @database_name=N'$DBName',
                                            @flags=0
                     IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'EveryMinute',
                                 @enabled=1,
                                @freq_type=4,
                                 @freq_interval=1,
                                 @freq_subday_type=4,
                                 @freq_subday_interval=1,
                                 @freq_relative_interval=0,
                                 @freq_recurrence_factor=0,
                                @active_start_date=20160426,
                                 @active_end_date=99991231,
                                 @active_start_time=0,
                                @active_end_time=235959
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
                      IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
                                 COMMIT TRANSACTION
                                 GOTO EndSave
                                 QuitWithRollback:
                      IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
                      EndSave:
                      /********* End ************/
           "
  if ($auth -eq 'W')
  { $SQLCreateStatusTable = Invoke-Sqlcmd -server $dbserver -Database $DBName  -query $sql }
  else
  { $SQLCreateStatusTable = Invoke-Sqlcmd -server $dbserver -Database $DBName -user $User -query $sql -password $Savepass }
  #Write-host "All SQL Collection objects created"
} #Create-SQLtables
function Get-SQLStatus {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$password
  )
  write-host "Checking collection status  for Server $dbServer"
  $sql = "
                      if (exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'SQL_CollectionStatus' ) )
                                 begin
                                            select JobStatus,SPID,CollectionStartTime,CollectionEndTime,Max_Sample_ID,Current_Sample_ID,Max_Sample_ID-Current_Sample_ID as TimeRemaining  from SQL_CollectionStatus
                                 end
                                 else
                                            select 'New' as JobStatus, 0 as Current_Sample_ID, 0 as Max_Sample_ID
           "
  if ($auth -eq 'W')
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -query $sql }
  else
  { $SQLStatus = Invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
  if ($SQLStatus.JobStatus -match "New") { $action = "S" }
  if ($SQLStatus.JobStatus -match "Running") { $action = "R" }
  if ($SQLStatus.JobStatus -match "Finished") { $action = "F" }
  return $action, [int]$SQLStatus.TimeRemaining
}#Function status
function Cleanup-SQLObjects {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass
  )
  $sql = "
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIOTotal'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIOTotal];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_DBIO'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_DBIO];
                      END
                      IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CollectionStatus'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CollectionStatus];
                      END
                        IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_CPUCollection'))
                      BEGIN
                                 DROP TABLE [dbo].[SQL_CPUCollection];
                      END
                       IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' and TABLE_NAME='SQL_MemCollection'))
                     BEGIN
                                 DROP TABLE [dbo].[SQL_MemCollection];
                      END
                      If (EXISTS(SELECT * FROM msdb.dbo.sysjobs WHERE (name = N'SQL_IOCollection')))
                      BEGIN
                                 EXEC msdb.dbo.sp_delete_job @job_name=N'SQL_IOCollection'
                     END
       "
  if ($auth -eq 'W')
  { $SQLCleanup = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $sql }
  else
  { $SQLCleanup = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password }
  Write-host "Cleanup Completed"
}# Function cleanup
function Get-SQLTargetData {
  Param(
    [Parameter(Mandatory = $True)]$dbserver,
    [Parameter(Mandatory = $True)]$DBName,
    [Parameter(Mandatory = $False)]$User,
    [Parameter(Mandatory = $False)]$Savepass
  )
  #write-host "Calling Get-SQLTargetData"
  $sql = "SELECT  [Sample_ID]
                          ,[DBName]
                          ,[Read]
                          ,[Written]
                          ,[BRead]
                          ,[BWritten]
                          ,[TotalIOPs]
                          ,[Throuput]
                          ,[Netpackets]
                          ,convert(varchar, CollectionTime, 121) as CollectionTime
                      FROM [$DBName].[dbo].[SQL_DBIO];
           "
  $cpusql = "SELECT cpu_count AS [Logical CPU Count],  hyperthread_ratio AS [Hyperthread Ratio],cpu_count/hyperthread_ratio AS [Physical CPU Count],virtual_machine_type_desc AS VM_type FROM sys.dm_os_sys_info WITH (NOLOCK) OPTION (RECOMPILE);"
  $memcollectionsql = "SELECT * FROM [$DBName].[dbo].[SQL_MemCollection]"
  $cpucollectionsql = "SELECT *  FROM [$DBName].[dbo].[SQL_CPUCollection]"
  $ation = ''
  if ($auth -eq 'W') {
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $memcollectionsql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_memcollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpucollectionsql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpucollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $cpusql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName  -query $sql
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_SQL_DBIO.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
  }
  else {
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $memcollectionsql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_memcollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpucollectionsql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpucollection.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $cpusql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_cpuinfo.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
    $SQLTargetResponse = invoke-sqlcmd -serverInstance $dbserver -Database $DBName -user $User -query $sql -password $password
    $TargetOutFile = "c:\rdstools\out\" + ($dbserver.replace('\', '~').Toupper()) + "_" + $dbtypeExt + "_" + $timestamp + "_SQL_DBIO.csv"
    $SQLTargetResponse | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | out-file $TargetOutFile
    #Write-host "SQLTargetdata written to $($TargetOutFile)"
  }
}
function Test-SQLConnection {
  [OutputType([bool])]
  Param
  (
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 0)]
    $ConnectionString
  )
  try {
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
    $sqlConnection.Open();
    $sqlConnection.Close();
    return $true;
  }
  catch {
    return $false;
  }
}
$rdscustom = ''
$timestamp = Get-Date -Format "MMddyyyyHHmm "
$FileExists = Test-Path -Path $SqlserverEndpoint
$copywrite = [char]0x00A9
Write-Host ' SQLAssessmentTool Ver 3.00' $copywrite 'BobTheRdsMan' -ForegroundColor Magenta
# set variable to be used in Targetdata function
[System.Collections.ArrayList]$ArrayWithHeader = @() # initialize the array that will store the final recommendation.
if ($options -eq 'upload') {
  if (Test-Path C:\RDSTools\upload\*) {
    $uploadfile = Get-ChildItem C:\RDSTools\upload\* -Filter *.csv
    $uploadfile = $uploadfile.Name
    foreach ($infile in $uploadFile) {
      $dataupload = import-csv C:\RDSTools\upload\$infile  -Header A, B, C, D, E, F, G, H, I, J, K, L, M
      Generate-ManualRecommendation
    }#foreach
    TCO
    Executive_summary $ArrayWithHeader
    exit
  }  #if test-path
  else {
    write-host " No input file in upload dir"
  }
}#options -eq 'upload'
if (-Not $FileExists) {
  Write-host " Input file Doesn't exists"
  exit
}
if ($sqlserverendpoint -eq 'C:\RDSTools\out\RdsDiscovery.csv') {
  $custom = ''
  $rdscustom = @()
  $servers = @()
  $servers
  $data = import-csv C:\RDSTools\out\RdsDiscovery.csv
  $data | ForEach-Object {
    if ($_.'RDS compatible' -eq 'Y')
    { $servers = $servers + $_.'server name' }
    elseif ($_.'RDS compatible' -eq 'N' -and $_.'RDS custom compatible' -eq 'Y') {
      $rdscustom = $rdscustom + $_.'server name'
      $servers = $servers + $_.'server name'
    }
  }#foreach
}#if
else { $servers = Get-Content $SqlserverEndpoint }
foreach ($server in $servers) {
  if ($auth -eq 'W') {
    $Conn = "Data Source=$server;database=master;Integrated Security=True;"
  }
  else {
    $Conn = "Data Source=$server;User ID=$login;Password=$password;"
  }
  if (Test-SqlConnection $Conn) {
    $status = ''
    $ation = ''
    if ($auth -eq 'W')
    { $status = Get-SQLStatus -dbserver $server -DBName $DBName }
    else { $Status = Get-SQLStatus -dbserver $server -DBName $DBName -user $login -password $password }
    if ($Status[0] -eq "S" -and $options -ne 'C') {
      write-host "Action: Start Collection for server $Server"
      if ($auth -eq 'W' )
      { create-SQLtables -dbserver $server -DBName $DBName -samples $collectiontime }
      else { create-SQLtables -dbserver $server -DBName $DBName -user $login -savepass $password -samples $collectiontime }
      #write-host "The SQL collection process has started and will run for $collectiontime minutes. (Note: 1440 mins = 24 hours) Run this script again with -dbtype [t]arget to get the latest status, or to download the data when complete. Check the documentation to cancel, cleanup or run a collection with different parameters."
    }
    if ($status[0] -eq "F" -or $options -eq 'T') {
      if ($options -eq 'T')
      { Terminate_job -dbserver $server -DBName $DBName -user $login -password $password }
      write-host "Collection completed, getting data for Server $server"
      if ($auth -eq 'W' ) {
        Get-SQLTargetData -dbserver $server -DBName $DBName
        if ($options -contains 'dblevel') { $dblevel = DB_level -dbserver $server -DBName master }
      }
      else {
        Get-SQLTargetData -dbserver $server -DBName $DBName -user $login -savepass $password
        if ($options -contains 'dblevel') { $dblevel = DB_level -dbserver $server -DBName master -user $login -password $password }
      }
      if ( $options -eq 'C') {
        Write-host "Cleanup"
        if ($auth -eq 'W' )
        { Cleanup-SQLObjects -dbserver $server -DBName $DBName }
        else { Cleanup-SQLObjects -dbserver $server -DBName $DBName -user $login -savepass $password }
      }
    }
    if ($status[0] -eq "R") {
      $minutesremaining = $status[1]
      if ($options -eq 'L')
      { write-host "Do nothing" }
      write-host "Collection Still running $minutesremaining minutes remaining."
    }
  }
  else {
    #write-host $server
    write-host "***** Can't connect to $server"
  }#else
}#foreach
if ($status[0] -eq 'F') {
  write-host "Do nothing"
}  