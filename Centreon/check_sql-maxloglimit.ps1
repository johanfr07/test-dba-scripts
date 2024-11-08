[CmdletBinding()] 
 Param  
   (
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

$strquerysql = "IF SERVERPROPERTY ('IsHadrEnabled') = 0  OR (SERVERPROPERTY ('IsHadrEnabled') = 1 
AND EXISTS(SELECT 1 FROM sys.availability_groups_cluster AS AGC
  INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS ON  RCS.group_id = AGC.group_id
  INNER JOIN sys.dm_hadr_availability_replica_states AS ARS ON ARS.replica_id = RCS.replica_id
  INNER JOIN sys.availability_group_listeners AS AGL ON AGL.group_id = ARS.group_id
WHERE  ARS.role_desc = 'PRIMARY' AND RCS.replica_server_name = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) ))
BEGIN
    -- check transaction log files saturation
   		 select d.name as DBName,
			m.name as LogName,-- m.physical_name, m.state_desc,
		 (8*size/1024) as LOG_Current_Size_MB,
		 (8*convert(bigint,max_size)/1024) as LOG_Current_MaxSize_MB,
		 is_percent_growth,
		 case when is_percent_growth=0 then (8*growth/1024) else growth end as LOG_Growth
		 FROM sys.master_files m
          INNER JOIN sys.databases d ON d.database_id = m.database_id
         where   d.name not in ('master','msdb','model','tempdb', 'DBAdb')
			and m.type_desc='LOG'
			and m.state_desc = 'ONLINE'
			and max_size > 0
			and ((is_percent_growth=0 and (8*growth/1024)+(8*size/1024) > (8*convert(bigint,max_size)/1024) )
				or (is_percent_growth<> 0 and ((growth*(8*size/1024))/100)+(8*size/1024) > (8*convert(bigint,max_size)/1024)))
			
END"

try {
   $HOSTNAME=Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name

     $password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd2023' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes2023.key')
    #$credential = New-Object System.Management.Automation.PsCredential("SQL-CENTREON",$password)
    $password2= [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(($password)))

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
    #$results += Invoke-Sqlcmd -Query $strquerysql -ServerInstance $INSTANCE -Username 'SQL-CENTREON' -Password $password2 -QueryTimeout $timeout -ErrorAction Stop
  
    }

    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $diffvalue = ""
        $criticalCount = 0
        foreach ($line in $results) {
                $diffvalue += ($line.DBName).ToString() +" - "+ ($line.LogName).ToString() +" current file size is " + ($line.LOG_Current_Size_MB).ToString() + "MB for max limit (" + ($line.LOG_Current_MaxSize_MB).ToString() + ");"
                $criticalCount++
        }
    }


    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "WARNING - Transaction logs need to increase max limit: $diffvalue"
        exit 1
    }

    echo "OK - All Transaction logs files size are ok"
    exit 0
}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}



