IF OBJECT_ID('tempdb..#SQL_DBIOTotal') IS NOT NULL drop table #SQL_DBIOTotal 
        IF OBJECT_ID('tempdb..#SQL_DBIO') IS NOT NULL drop table #SQL_DBIO
        IF OBJECT_ID('tempdb..#SQL_MemCollection') IS NOT NULL drop table #SQL_MemCollection
        IF OBJECT_ID('tempdb..#SQL_CPUCollection') IS NOT NULL drop table #SQL_CPUCollection
        IF OBJECT_ID('tempdb..#SQL_CollectionStatus') IS NOT NULL drop table #SQL_CollectionStatus
        declare @CollectionTime int
        declare @Current_Sample_ID Bigint
            set @collectiontime=5 -- in minutes 


                      
 
        /*******Memory collection table ****/
            create table #SQL_MemCollection
            (
            SQL_ColletionTime  Datetime,
            SQLCurrMemUsageMB  decimal(12,2),
            SQLMaxMemTargetMB int,
            OSTotalMemoryMB    int,
            OSAVAMemoryMB      int,
            PLE               int
            )
        /*****Cpu collection table *****/
        create table #SQL_CPUCollection
        (
         SqlSerCpuUT int,
         SystemIdle int,
         OtherProCpuUT int,
         Collectiontime datetime
         )
      
                      /****** Create SQL_CollectionStatus Table ******/
                      CREATE TABLE #SQL_CollectionStatus(
                                [JobStatus] [nvarchar](10) NOT NULL,
                                [SPID] [int] NOT NULL,
                                 [CollectionStartTime] [datetime] NOT NULL,
                                 [CollectionEndTime] [datetime] NULL,
                                 [Max_Sample_ID] [bigint] NOT NULL,
                                 [Current_Sample_ID] [bigint] NOT NULL
                      ) ON [PRIMARY]
                      /****** Insert Data -- INCLUDES VARIABLE FROM PARENT SCRIPT -- ******/
                      Declare @Total_Samples bigint
                      Select @Total_Samples = @collectiontime
                      INSERT #SQL_CollectionStatus (JobStatus, SPID, CollectionStartTime, Max_Sample_ID, Current_Sample_ID)
                      SELECT 'Running',@@SPID,GETDATE(),@Total_Samples,0;
        --              /****** Create SQL_DBIOTotal Table  ******/
                      CREATE TABLE #SQL_DBIOTotal(
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
        --              /****** Create SQL_DBIO Table  ******/
                      CREATE TABLE #SQL_DBIO(
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
while (Select Max_Sample_ID - Current_Sample_ID  from #SQL_CollectionStatus) >  0
                                 BEGIN
                                 update #SQL_CollectionStatus
                                 set Current_Sample_ID  = Current_Sample_ID  + 1
                                 Set @Current_Sample_ID = (Select Current_Sample_ID from #SQL_CollectionStatus);
                                                                  
                                INSERT #SQL_DBIOTotal
                                                   SELECT
    mf.Database_ID,
      @Current_Sample_ID,
      physical_name AS [Physical Name],
    --mf.name,
    SUM(fs.num_of_reads ),
    SUM(fs.num_of_writes),
    SUM(fs.num_of_bytes_read ),
    SUM(fs.num_of_bytes_written),
    SUM((fs.num_of_bytes_read)+(fs.num_of_bytes_written)) ,
    SUM(fs.num_of_reads + fs.num_of_writes) ,
    (select Sum(net_packet_size) as Total_net_packets_used from sys.dm_exec_connections),
     GETDATE()
    FROM sys.dm_io_virtual_file_stats(default, default) AS fs
   --INNER JOIN sys.databases d (NOLOCK) ON d.Database_ID = fs.Database_ID
    inner jOIN sys.master_files AS mf ON fs.file_id = mf.file_id and  mf.Database_ID = fs.Database_ID
   WHERE DB_NAME(mf.database_id) NOT IN ('master','model','msdb', 'distribution', 'ReportServer','ReportServerTempDB')
    -- and d.state = 0
   GROUP BY physical_name ,mf.Database_ID;

                                   --                SELECT
                                 --          @Current_Sample_ID,
                                 --           d.Database_ID,
                                 --          d.name,
                                 --           SUM(fs.num_of_reads ),
                                 --           SUM(fs.num_of_writes),
                                 --           SUM(fs.num_of_bytes_read ),
                                 --          SUM(fs.num_of_bytes_written),
                                 --           SUM((fs.num_of_bytes_read)+(fs.num_of_bytes_written)) ,
                                 --           SUM(fs.num_of_reads + fs.num_of_writes) ,
                                 --           (select Sum(net_packet_size) as Total_net_packets_used from sys.dm_exec_connections),
                                 --           GETDATE()
                                 --FROM sys.dm_io_virtual_file_stats(default, default) AS fs
                                 --           INNER JOIN sys.databases d (NOLOCK) ON d.Database_ID = fs.Database_ID
                                 --WHERE d.name NOT IN ('master','model','msdb', 'distribution', 'ReportServer','ReportServerTempDB')
                                 --and d.state = 0
                                 --GROUP BY d.name, d.Database_ID;
                               Insert into #SQL_DBIO
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
                                 from #SQL_DBIOTotal as DR1
                                 Inner Join #SQL_DBIOTotal as DR2 ON DR1.Database_ID = DR2.Database_ID
                                 where DR1.Sample_ID = @Current_Sample_ID -1
                                 and DR2.Sample_ID = @Current_Sample_ID;
                        DECLARE @ts_now bigint = (SELECT ms_ticks FROM sys.dm_os_sys_info WITH (NOLOCK)); 
                            insert into #SQL_CPUCollection
                        SELECT TOP(1) SQLProcessUtilization AS [SQL Server Process CPU Utilization], 
                                       SystemIdle AS [System Idle Process], 
                                       100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization], 
                                       DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] 
                        FROM (SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
                                      record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int') 
                                              AS [SystemIdle], 
                                      record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
                                              AS [SQLProcessUtilization], [timestamp] 
                                 FROM (SELECT [timestamp], CONVERT(xml, record) AS [record] 
                                              FROM sys.dm_os_ring_buffers WITH (NOLOCK)
                                              WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
                                              AND record LIKE N'%<SystemHealth>%') AS x) AS y 
                        ORDER BY record_id DESC
                        
                        insert into #SQL_MemCollection
                        select x.*,y.*,z.* from (SELECT       getdate() as collectionTime,(committed_kb/1024) as Commited,(committed_target_kb/1024)  as targetcommited FROM sys.dm_os_sys_info)  as x,
                           (   SELECT        (total_physical_memory_kb/1024) as totalMem,(available_physical_memory_kb/1024) as AvaiMem FROM sys.dm_os_sys_memory) as y,
                           (SELECT sum(cntr_value)/count(*)  as PLE FROM sys.dm_os_performance_counters WHERE counter_name = 'Page Life expectancy'    AND object_name LIKE '%buffer node%') as Z
waitfor delay '00:00:59'
end
          declare @cpuutilization int
          declare @one_or_zero int
          declare @cpurecomm varchar(50)
          declare @Memrecomm Varchar(50)
          declare @memutilization int
          declare @Cpupercentile int
          declare @MaxMemory int 
          declare @Throughput int
          declare @totaliops int
          declare @edition varchar(2)
          declare @ProductVersion int
             declare @servername  varchar(100)
             select  @servername=@@servername

    ;    with  Cpu_util (one_or_zero) as
                (
                    SELECT  case when sqlsercpUut>=80  then 1 else 0 end FROM #SQL_CPUCollection
                ) 
            select   @cpuutilization=count(*)*100/(select count(*)  from Cpu_util )  , @one_or_zero=one_or_zero from cpu_util where one_or_zero=1
                group by one_or_zero
                order by 2 desc
                set @cpuutilization=isnull(@cpuutilization,0)
                if  @cpuutilization>=80  
                    select @cpurecomm='Need To scale compute  UP'  --,@cpuutilization 
                else If @cpuutilization<80  and @cpuutilization >=30 
                    select @cpurecomm='compute Load is acceptable'  --,@cpuutilization  
                else   select @cpurecomm='compute can be scaled down ' -- ,@cpuutilization 
    --select @cpuutilization=sum([sqlsercpUut])/count(*) FROM #SQL_CPUCollection
    --                    if  @cpuutilization>=80 
    --                            select @cpurecomm='Need To scale compute  UP' -- ,@cpuutilization  
    --                    else If @cpuutilization<80  and @cpuutilization >=30 
    --                            select @cpurecomm='compute Load is acceptable' -- ,@cpuutilization  
    --                    else   select @cpurecomm='compute can be scaled down '-- ,@cpuutilization  

declare @95Percentile int 
                    select @95Percentile=count(*)* 0.95 from #SQL_CPUCollection
                    ;with cpupercentile as 
                    (SELECT row_number () over (order by sqlsercpuUt asc) as rownum,
                               [SqlSerCpuUT]
                              ,[SystemIdle]
                              ,[OtherProCpuUT]
                              ,[Collectiontime]
                              FROM #SQL_CPUCollection
                     ) select @Cpupercentile=[SqlSerCpuUT]   from cpupercentile  where rownum =@95Percentile
                                                                               

declare @Logical_CPU_Count int

SELECT @Logical_CPU_Count=cpu_count   FROM sys.dm_os_sys_info 
 
SELECT top 1 @MaxMemory  =[SQLMaxMemTargetMB]     FROM #SQL_MemCollection
declare @count int
             --declare @MemUtilization int
                ;with Memory_intensive (one_or_zero) as 
                    (
                    select ((case when ([SQLCurrMemUsageMB]*100)/[SQLMaxMemTargetMB]>=80   then 1 else 0 end) 
                             &(case when (([SQLCurrMemUsageMB]/1024)/4)*300< PLE then 0 else 1 end )) FROM #SQL_MemCollection
                    )
                             select @count=count(*) from Memory_intensive where one_or_zero=1 group by one_or_zero
                             select @memutilization=isnull(@count*100/(select count(*) from #SQL_MemCollection),0)
                        if  @MemUtilization>=80  
                            select @Memrecomm='Need To scale Memory UP' --,@MemUtilization  as utilization
                        else If @MemUtilization<80  and @MemUtilization >=50 
                            select @Memrecomm='Memory Load is acceptable'  --,@MemUtilization  as utilization
                        else   select @Memrecomm='Memory can be scaled down '  --,@MemUtilization  as utilization
SELECT @totaliops=isnull(sum(Totaliops)/60,0) ,@Throughput=isnull(((sum(bread+bwritten)/60)/1048576),0)
              FROM #SQL_DBIO
SELECT   @Edition=case  WHEN CONVERT(VARCHAR(128),SERVERPROPERTY('Edition')) like 'Standard%' Then 'SE'
            WHEN CONVERT(VARCHAR(128),SERVERPROPERTY('Edition')) like 'Enterprise%' Then 'EE'
    end  ,
        @ProductVersion=CASE 
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '11%' THEN '11'
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '12%' THEN '12'
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '13%' THEN '13'     
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '14%' THEN '14' 
            WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')) like '15%' THEN '15' 
               Else '12'
        end 
 
 
 
 select @servername as Servername ,@cpurecomm as cpurecomm, @cpuutilization as cpuUtilization,@Cpupercentile as cpu95percentile,@Logical_CPU_Count as CU_count,@MaxMemory as MaxMemory
,@Memrecomm as Memecomm,@MemUtilization as Memutilization,@Throughput as throughput,@totaliops as Totaliops,@edition as edition,
@ProductVersion as ProductVersion,@collectiontime as collectiontime
