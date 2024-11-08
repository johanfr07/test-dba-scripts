[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 1,
    [Int]$critical = 7,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

try {

    $HOSTNAME=Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name
    $password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd2023' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes2023.key')
    # $credential = New-Object System.Management.Automation.PsCredential("SQL-CENTREON",$password)
    $password2= [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(($password)))

    # FULL backup checks 
    $strquerysql = "
    SELECT bs.database_name, MAX(backup_start_date) as LastBackupDate,@@servicename, count(d.replica_id) as NbReplicas
    FROM sys.databases d
    INNER JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
    INNER JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id 
    WHERE type='D' 
    AND bmf.physical_device_name LIKE '%bak'
    AND NOT EXISTS (SELECT 1 FROM sys.availability_databases_cluster d 
				    WHERE d.database_name=bs.database_name 
				    AND sys.fn_hadr_backup_is_preferred_replica (d.database_name)  = 0)
    GROUP BY bs.database_name;"
    
    $srvr = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $computerName
    $instances = $srvr | ForEach-Object {$_.ServerInstances} |  select Name     
    #echo $instances     
    $results = @()

    Foreach($Inst in $instances) {
    #echo $Inst
        if ($Inst.NAME -eq 'MSSQLSERVER') 
        {  $INSTANCE=$HOSTNAME
     
        }
        else 
        {  $INSTANCE=$HOSTNAME+"\"+$Inst.name
       
        } 

    $results += Invoke-Sqlcmd -Query $strquerysql -ConnectionString "Data Source=$INSTANCE;Initial Catalog=master;User Id=SQL-CENTREON;Password=$password2;TrustServerCertificate=True"
  
    # $results += Invoke-Sqlcmd -Query $strquerysql -ServerInstance $INSTANCE -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
  
    }
      
    #echo $results
    $EndDate=(GET-DATE)

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningvalue =""
        $criticalvalue = ""
        $warningCount = 0
        $criticalCount = 0
        foreach ($line in $results) {
              $StartDate=[datetime]$line.LastBackupDate
              $DBName=$line.database_name
              $NbReplicas=$line.NbReplicas

              if ($NbReplicas -ne 0) {
                $strListReplicas = "SELECT ar.replica_server_name as Replica
                FROM sys.availability_groups ag
                inner join sys.availability_replicas ar on ag.group_id = ar.group_id;"
                      
                $strquerymaxbackupdt = "SELECT MAX(backup_start_date) as LastBackupDate
                FROM sys.databases d
                INNER JOIN msdb.dbo.backupset bs ON d.name = bs.database_name
                INNER JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id 
                WHERE type='D' 
                AND bmf.physical_device_name LIKE '%bak'
                AND bs.database_name = '$DBName'
                GROUP BY bs.database_name;"         
                
                $listReplica += Invoke-Sqlcmd -Query $strListReplicas -ConnectionString "Data Source=$INSTANCE;Initial Catalog=master;User Id=SQL-CENTREON;Password=$password2;TrustServerCertificate=True"
                # $listReplica = Invoke-Sqlcmd -Query $strListReplicas -ServerInstance $INSTANCE -Database master -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
   
                foreach ($r in $ListReplica) {       
                    $Replica = $r.Replica
                    $results2=Invoke-Sqlcmd -Query $strquerymaxbackupdt -ServerInstance $Replica -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
                    $lastdt=$results2.LastBackupDate
                    if($results2.LastBackupDate -ne $null -and $StartDate -lt $lastdt) { #take the most recent backup date) {
                        $lastdt=[datetime]$results2.LastBackupDate
                        $StartDate = $lastdt
                    }
                }
              }      
                                     

              $ts = NEW-TIMESPAN -Start $StartDate -End $EndDate
          
              if ($ts.Days -gt $critical) {
                $criticalvalue += $line.database_name +"; "
                $criticalCount++
              }
              else {if ($ts.Days -le $critical -and $ts.Days -gt $warning) {
                $warningvalue += $line.database_name +"; "
                $warningCount++
              }}
        }
    }

    if ($criticalCount -ne 0 -and $criticalvalue -ne $null -and $criticalvalue -ne "") {
        echo "CRITICAL - Last backup older than $critical day(s): $criticalvalue"
        exit 2
    }

    if ($warningCount -ne 0 -and $warningvalue -ne $null -and $warningvalue -ne "") {
        echo "WARNING - Last backup older than $warning day(s): $warningvalue"
        exit 1
    }

    echo "OK - All Backups are in time"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}

