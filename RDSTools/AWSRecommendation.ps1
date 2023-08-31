Param (
     [Parameter()][int]$VCPU,
     [Parameter()][int]$Memory,
     [Parameter()][int]$IOPS,
     [Parameter()][int] $throughput,
     [parameter()]$VCPUUtilization,
     [parameter()]$MemoryUtilization
)
function RDSInstance {
     Param (
          [Parameter()][int]$cpuonprem,
          [Parameter()][int]$Memoryprem,
          [Parameter()][int]$TotalIOPS,
          [Parameter()][int]$Throughput,
          [Parameter()][int ]$cpuutilization,
          [Parameter()][int]$Memutilization,
          [parameter()]$options
     )
     #$classonaws = ''
     $class = ''
     $custom = 'N'
     $version = 15
     $Edition = 'EE'
     $remark = ' '
     if ($Cpuonprem -lt 2 )
     { $cpuonprem = 4 }
     $vcpu = $cpuonprem
     $Ratio = $Memoryprem / $cpuonprem
     $cpuonprem = [math]::ceiling($cpuonprem / 4)
     if ($ratio -le 4) {
          $Ratio = 4
          $type = 'G'
     }
     elseif ($ratio -gt 4 -and $ratio -le 8) {
          $ratio = 8
          $type = 'M'
     }
     elseif ($ratio -gt 8 -and $ratio -le 15) {
          $ratio = 15
          $type = 'M'
     }
     elseif ($ratio -gt 15) {
          $ratio = 30
          $type = 'M'
     }
     if ( $ratio -eq 15 -and $vcpu -lt 64)
     { $ratio = 30 }
     if ($ratio -lt 15 ) {
          #new
          if ($cpuonprem -ge 25)
          { $class = '32xlarge' }
          if ($cpuonprem -le 24 -and $cpuonprem -gt 16)
          { $class = '24xlarge' }
          if ($cpuonprem -le 16 -and $cpuonprem -gt 12)
          { $class = '16xlarge' }
          if ($cpuonprem -le 12 -and $cpuonprem -gt 8)
          { $class = '12xlarge' }
          if ($cpuonprem -le 8 -and $cpuonprem -gt 4)
          { $class = '8xlarge' }
          if ($cpuonprem -le 4 -and $cpuonprem -gt 2)
          { $class = '4xlarge' }
          if ($cpuonprem -le 2 -and $cpuonprem -gt 1)
          { $class = '2xlarge' }
          if ($cpuonprem -le 1 )
          { $class = 'xlarge' }
          if ($cpuonprem -eq 0  )
          { $class = 'large' }
     }
     if ($ratio -gt 15 ) {
          #new
          if ($cpuonprem -ge 25)
          { $class = '32xlarge' }
          if ($cpuonprem -le 24 -and $cpuonprem -gt 16)
          { $class = '24xlarge' }
          if ($cpuonprem -le 16 -and $cpuonprem -gt 12)
          { $class = '16xlarge' }
          if ($cpuonprem -le 12 -and $cpuonprem -gt 8)
          { $class = '12xlarge' }
          if ($cpuonprem -le 8 -and $cpuonprem -gt 4)
          { $class = '8xlarge' }
          if ($cpuonprem -le 4 -and $cpuonprem -gt 2)
          { $class = '4xlarge' }
          if ($cpuonprem -le 2 -and $cpuonprem -gt 1)
          { $class = '2xlarge' }
          if ($cpuonprem -le 1 )
          { $class = 'xlarge' }
          if ($cpuonprem -eq 0  )
          { $class = 'large' }
     }
     if ($ratio -eq 15  ) {
          #new
          if ($cpuonprem -gt 16)
          { $class = '32xlarge' }
          if ($cpuonprem -le 16 )
          { $class = '16xlarge' }
     }
     if ($cpuutilization -ge '80' -and $Memutilization -ge '80') { 
          if ( $ratio -lt 15) {
               $CLASS = switch ($class) {
                    'Xlarge' { '2xlarge' }
                    '2Xlarge' { '4xlarge' }
                    '4Xlarge' { '8xlarge' }
                    '8Xlarge' { '12xlarge' }
                    '12Xlarge' { '16xlarge' }
                    '16Xlarge' { '24xlarge' }
                    '24Xlarge' { '32xlarge' }
                    '32Xlarge' { '32xlarge' }
               }
               $type = 'M'
               $remark = 'Scaled up due to High Memory and High CPU'
               $ratio = 8 
          } 
          elseif ( $ratio -ge 15)
          { $vcpu = $vcpu + $vcpu }
        
          $Scale = 'U'
     }
     elseif ($cpuutilization -ge '80' -and $Memutilization -le '80' -and $ratio -lt 15) {
          $CLASS = switch ($class) {
               'Xlarge' { '2xlarge' }
               '2Xlarge' { '4xlarge' }
               '4Xlarge' { '8xlarge' }
               '8Xlarge' { '12xlarge' }
               '12Xlarge' { '16xlarge' }
               '16Xlarge' { '24xlarge' }
               '24Xlarge' { '32xlarge' }
               '32Xlarge' { '32xlarge' }
          }
          $Scale = 'U'
          $remark = 'Scaled up due to High CPU'
     }
     elseif ($cpuutilization -le '80' -and $Memutilization -ge '80' -and $ratio -Lt '15') {
          #$cpuonprem=$cpuonprem+4
          $type = 'M'
          $scale = 'N'
          $ratio = 8
          $remark = 'Scaled up due to High Memory '
     }
     elseif ($cpuutilization -lt '50' -and $Memutilization -lt '50' -and $ratio -lt 15) {
          #scale Down.
          if ($class -ne 'Xlarge') {
               $CLASS = switch ($class) {
                    '2Xlarge' { 'xlarge' }
                    '4Xlarge' { '2xlarge' }
                    '8Xlarge' { '4xlarge' }
                    '12Xlarge' { '8xlarge' }
                    '16Xlarge' { '12xlarge' }
                    '24Xlarge' { '16xlarge' }
                    '32Xlarge' { '24xlarge' }
               }
               $Scale = 'D'
          }
          $remark = 'Scaled Down '
     }
     $fileoriginal = import-csv "C:\RDSTools\in\AwsInstancescsv.csv"
     if ($Custom -eq 'Y')
     { $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq $edition -and $_.version -match $version } }
     elseif ($Custom -eq 'N' -and $ratio -lt 15)
     { $file = $fileoriginal | where-Object { $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version } }
     elseif ($Custom -eq 'N' -and $ratio -ge 15) {
          $file = $fileoriginal | where-Object { [int]$_.ratio -eq [int]$ratio -and [int]$_.vcpu -ge [int] $VCPU -and [int]$_.memory -ge [int]$Memoryprem -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq $edition -and $_.version -match $version }
          if (-not $file -and $ratio -eq 30)
          { $file = 'db.x1e.32xlarge' }
     }
     <#if ( $file)
 {$file=$file[0]}#>
     #$file=$file|select-object -unique
     while ( -not $file ) {
          #sclae up
          $CLASS=switch ($class) {
          'Xlarge'  {'2xlarge' }
          '2Xlarge' { '4xlarge' }
          '4Xlarge' { '8xlarge' }
          '8Xlarge' { '12xlarge' }
          '12Xlarge' { '16xlarge' }
          '16Xlarge' { '24xlarge' }
          '24Xlarge' { '32xlarge' }
          '32Xlarge' { '32xlarge' }
     }
     $remark = ' Instance was scalled up due to IOPS requirement'
     $scale = 'I'
     #$classonaws=$CLASS
     if ($Custom -eq 'Y') {
          $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version }
          #$file=$fileoriginal| where-Object {[int]$_.ratio -eq [int]$ratio -and $_.size -eq $classonaws -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq  $SQLVEresult.edition  -and $_.version -match $SQLVEresult.productversion }
     }
     else {
          $file = $fileoriginal | where-Object { $_.size -eq $class -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.edition -eq $edition -and $_.version -match $version }
          # $file=$fileoriginal| where-Object {[int]$_.ratio -eq [int]$ratio -and $_.size -eq $classonaws -and [int]$_.iops -ge [int]$Totaliops -and [int]$_.Throughput -ge [int]$Throughput -and $_.instancetype -eq $type -and $_.edition -eq  $SQLVEresult.edition  -and $_.version -match $SQLVEresult.productversion }
     }
     #$file=$file|select-object -unique
     if ($class -match '32xlarge' -and -not $file) {
          $remark = 'No Instance that match your IOPS Requirment'
          if ($Custom -eq 'Y') {
               $file = $fileoriginal | where-Object { $_.RDSCustom -like 'Y' -and $_.size -eq '24xlarge' -and $_.edition -eq $edition -and $_.version -match $version }
          }
          elseif ($Custom -eq 'N') {
               $file = $fileoriginal | where-Object { $_.size -eq $class -and $_.edition -eq $edition -and $_.version -match $version }
          }
     }
}
return $type, $remark, $file
}
$fileprem = ''
#$Fileprem=Import-Csv "C:\Users\brifa\Downloads\InstanceSizes.csv"
$i = 0
$rowMaxprem = ($fileprem).Count
foreach ($server in $Fileprem) {
     $cpuonprem = $server.processorcount
     $ramonprem = $server.PhysicalMemoryingb
     $classonaws = RDSInstance  $vcpu $Memory $iops $throughput $Vcpuutilization $Memoryutilization
     $remark = $classonaws[1]
     $type = $classonaws[0]
     $classonaws = @($classonaws[2])
     $classtemp = $classonaws
     if ($type -eq 'M') {
          $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | Where-Object { $_ -like "db.r*" -or $_ -like "db.x*" -or $_ -like "db.x1*" -or $_ -like "db.z1d"}
          #$classonaws = $Classonaws | Where-Object { $_ -like "db.X1e*" } #| Select-Object -Unique
          if (-not $classonaws)
          { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
     }
     if ($type -eq 'G' ) {
          $classonaws = $Classonaws."Instance Type" | Select-Object -Unique | where-object { $_ -like "db.m*" -or $_ -like "db.t*" }
          if (-not $classonaws)
          { $classonaws = $classtemp."Instance Type" | Select-Object -Unique } 
     }
     #$classonaws=($classonaws -join ",")
     $RDSInstance = @($classonaws)
     #$classonaws=($classonaws -join ",")
     #$server.instancename + ' Memory:' +$server.PhysicalMemoryInGB+' VCPU: '+$server.ProcessorCount+' RDS Instance : '+$RDSInstance
     $RDSInstance
}