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
    $CentralInstance = "SV-DC-SQLBCK001"
    $CentralDB = "CentralDB"

    ##  Check SQL Server services accounts   
    ##  Check SQL Server Agent services accounts  
    ##  Check SSIS, SSAS, SSRS and other services accounts  
        # If named instances exists on the server, service SQLBrowser must be started <br> $SQLAccounts 
    ##  Power Plan must be High Performance  $PowerPlanMgt 
    ##  Check manually VERSION et EDITION installed  => must be the same for same application 
    ##  Check SQL Server dedicated drives  
        # It should be <b>D</b> drive for Installation Path and system databases master model msdb <br> 
        # It should be <b>E</b> drive for user databases data files .mdf .ndf <br> 
        # It should be <b>L</b> drive for user databases log files .ldf <br> 
        # It should be <b>H</b> drive for tempdb files <br> 
        # It should be <b>S</b> drive for database backup files .bak .trn <br> $DefaultPaths

    ## CHECK - Max Size DB Files Near Saturation 
    $strquerysql = "declare @dt datetime
    select @dt = case when datepart(hour, getdate()) between 4 and 13 then convert(varchar(8),getdate()-1, 112) else convert(varchar(8),getdate(), 112) end;
    select [InstanceName], [DBName], [LogicalName], [SizeInMB], [GrowthPct], [GrowthInMB], [MaxSizeInMB], [DateAdded]
    from [DB].[DatabaseFiles]
    where DateAdded between @dt and @dt+1
    and NOT EXISTS (select 1 FROM [DB].[DatabaseInfo] where [DatabaseFiles].[ServerName] = [DatabaseInfo].[ServerName] 
and [DatabaseFiles].[InstanceName] = [DatabaseInfo].[InstanceName] and [DatabaseFiles].[DBName] = [DatabaseInfo].[DBName] and [ReadOnly] =1)
    and MaxSizeInMB <> -1
    and (( GrowthInMB > 0 AND (SizeInMB+GrowthInMB) > MaxSizeInMB)
    or ( GrowthPct > 0 AND (SizeInMB+(SizeInMB*GrowthPct/100)) > MaxSizeInMB) );"

    $results = Invoke-Sqlcmd -Query $strquerysql -ServerInstance $CentralInstance -Database $CentralDB -QueryTimeout $timeout -ErrorAction Stop
            
    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningvalue =""
        #$criticalvalue = ""
        $warningCount = 0
        #$criticalCount = 0
        foreach ($line in $results) {
              $InstanceName=[string]$line.InstanceName
              $DBName = [string]$line.DBName
              $LogicalName=[string]$line.LogicalName
              $SizeInMB=[string]$line.SizeInMB
              $GrowthPct=[string]$line.GrowthPct
              $GrowthInMB=[string]$line.GrowthInMB
              $MaxSizeInMB=[string]$line.MaxSizeInMB
              $DateAdded=[datetime]$line.DateAdded
             
             $warningvalue+= "WARNING - $InstanceName : DB $DBName - DBFile $LogicalName ($MaxSizeInMB MB) will be full at next growth `n"
             $warningCount++

        }
        $warningvalue += "DateCheck: $DateAdded"
    }
    
    ##  CHECK SQLServer dedicated drives Format Size  => All disks except C: must be formatted with cluster size <b>64 kb</b> <br> $DskFormatSize 


    ##  Check MAXMEMORY and MAXDOP 
        # MAXMEMORY must be different than default value 2147483647 <br>
        # MAXDOP should not be equal to 0 if nbCPU > 8; value to calculate depending of $s.AffinityInfo.NumasNodes.Count <br>
        # MAXDOP must be configured with <b>$TotalMemory</b> and <b>$CPUcount</b> <br> $SQLConfig
    ##  Check SQL Server Network Protocols 
        # TcpEnabled should be enabled 1 <br> 
        # NamedPipesEnabled should be disabled 0 <br> 
        # IsHadrEnabled should be enabled if Always On has been setup <br> $SQLConfigOther  
    ##  Check manually Always On configuration  # IF IsHadrEnabled is <b>True</b>, check :<br>
        # AAG General config;<br>
        # AAG backup preferences;<br>
        # AAG ReadOnly Routing;<br>
        # AAG Listener; <br>
    ##  Check number of tempdb data files  # It must be splitted with <b>$CPUcount</b> remaining within limit of 8: Actual number of files=<b>$NbTempdb</b><br> $sqltempdb
    ##  Check model database configuration $sqlModel
    ##  Check Database Mail is configured for SQL Server Agent and DBA operator is created $sqlDBMail 
    ##  Check DBAdb database has been created $sqlDBAdb
    ##  Check DBA Maintenance Jobs have been created $sqlDBAMaintjobs
    ##  Check Default backup Compression is set to True  $DefaultBckCompression
    ##  Check Audit Specifications have been created  $sqlAudits
    ##  Check ITReader login has been created   $sqlITReader
    ##  Check SQL Server Alerts have been created  $sqlAlerts
    ##  Check SQL Server instance have been added in CentralDB  $sqlCentraldb <br> $cmdCentralDB
    ##  Check SQL Server Alerts have been added in WSUS for patch management  $sqlWSUS

    ##  Check sa disabled
    $strquerysql = "declare @dt datetime
    select @dt = case when datepart(hour, getdate()) between 4 and 13 then convert(varchar(8),getdate()-1, 112) else convert(varchar(8),getdate(), 112) end;
    select [InstanceName], [LoginType], [DateAdded]
    from [Inst].[Logins]
    where DateAdded between @dt and @dt+1
    and [LoginName] = 'sa'
    and [IsDisabled] = 0
    and [LoginType] = 'SqlLogin';"

    $results = Invoke-Sqlcmd -Query $strquerysql -ServerInstance $CentralInstance -Database $CentralDB -QueryTimeout $timeout -ErrorAction Stop
            
    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningCount = 0
        foreach ($line in $results) {
              $InstanceName=[string]$line.InstanceName
              $DateAdded=[datetime]$line.DateAdded
             
             $warningvalue+= "WARNING - $InstanceName : login sa is not disabled `n"
             $warningCount++

        }
    }

    ##  Check admincdc enabled
    $strquerysql = "declare @dt datetime
    select @dt = case when datepart(hour, getdate()) between 4 and 13 then convert(varchar(8),getdate()-1, 112) else convert(varchar(8),getdate(), 112) end;
    select [InstanceName], [LoginType], [DateAdded]
    from [Inst].[Logins]
    where DateAdded between @dt and @dt+1
    and [LoginName] = 'admincdc'
    and [IsDisabled] <> 1
    and [LoginType] = 'SqlLogin';"

    $results = Invoke-Sqlcmd -Query $strquerysql -ServerInstance $CentralInstance -Database $CentralDB -QueryTimeout $timeout -ErrorAction Stop
            
    # Are there any differences?
    if($results -ne $null -or $results -ne "")
    {
        $warningCount = 0
        foreach ($line in $results) {
              $InstanceName=[string]$line.InstanceName
              $DBName = [string]$line.DBName
              $LogicalName=[string]$line.LogicalName
              $SizeInMB=[string]$line.SizeInMB
              $GrowthPct=[string]$line.GrowthPct
              $GrowthInMB=[string]$line.GrowthInMB
              $MaxSizeInMB=[string]$line.MaxSizeInMB
              $DateAdded=[datetime]$line.DateAdded
             
             $warningvalue+= "WARNING - $InstanceName : DB $DBName - DBFile $LogicalName ($MaxSizeInMB MB) will be full at next growth `n"
             $warningCount++

        }
    }
    
     
      <# if ($criticalCount -ne 0 -and $criticalvalue -ne $null -and $criticalvalue -ne "") {
        echo "CRITICAL - Last backup older than $critical day(s): $criticalvalue"
        exit 2
    } #>

    if ($warningCount -ne 0 -and $warningvalue -ne $null -and $warningvalue -ne "") {
        echo "WARNING - Alerts on $warningCount SQL instances:
        $warningvalue"
        exit 1
    }

    echo "OK - All SQL instances are correctly configured"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}

