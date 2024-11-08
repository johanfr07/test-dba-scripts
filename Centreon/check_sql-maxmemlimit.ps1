[CmdletBinding()] 
 Param  
   (
    #[Int]$memtoapps = 2048,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation") | Out-Null

$strquerysql = "SELECT (SELECT [physical_memory_kb] / 1024 FROM sys.dm_os_sys_info) as PhysicalMemory,
			[value]  AS [ConfiguredMaxServerMemoryMB],
           SERVERPROPERTY ('InstanceName') as InstanceName
		FROM sys.configurations
		WHERE [name] = 'max server memory (MB)';"

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

    #echo $results


    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $diffvalue = ""
        $criticalCount = 0
        $percent=0
        foreach ($line in $results) {
                $percent+= ($line.ConfiguredMaxServerMemoryMB*100/$line.PhysicalMemory)              
                $diffvalue += ($line.InstanceName) + ": "+ ($line.ConfiguredMaxServerMemoryMB).ToString() +"MB - Total Memory: " + ($line.PhysicalMemory).ToString()+"MB;"
                $criticalCount++
        }
    }
    #$criticalCount 
    #$percent

    if ($criticalCount -ne 0 -and $percent -ne $null -and $percent -ne "" -and $percent -lt 75) { # less than 75 percent
        echo "WARNING - SQL Max Memory Limit : $diffvalue"
        exit 1
    }

    echo "OK - SQL Max Memory Limit is correctly set"
    exit 0
}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}



