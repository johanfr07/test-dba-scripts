[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 180,
    [Int]$critical = 300,
    [Int]$timeout = 10,
    [String]$SQLClusterName = 'DEFAULT'
   )#End Param
   
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null

# Function to do a row-by-row check
function RBAR-Check ($array1, $array2)
{
	$row_index = 0;
    $column_index = 0;

    while($row_index -le $array1.Count){
             
        $line1=""
        $line2=""       
        while($column_index -le $array1.Column.Count){
            $line1 += $array1[$row_index][$column_index] #+"|"
            $line2 += $array2[$row_index][$column_index] #+"|"
            $column_index += 1;
        }

        if($line1 -ne $line2){
             $delta += $line2 +"; "
        }       			
		
		$row_index += 1;
	}
	return $delta;
}


try { 
     $strquerysql = "SET NOCOUNT ON;
    SELECT sp.name, convert(varchar(1000), sp.sid,2) as sid, sp.type, sp.is_disabled, sl.is_policy_checked, sl.is_expiration_checked, sl.password_hash, sp.default_database_name, sp.default_language_name
    FROM sys.server_principals sp
    LEFT OUTER JOIN sys.sql_logins sl ON sp.name = sl.name
    WHERE sp.name NOT IN ('sa', 'admincdc',
        'distributor_admin',
        'NT AUTHORITY\SYSTEM',  
    'NT SERVICE\SQLWriter',
    'NT SERVICE\Winmgmt',
    'NT SERVICE\MSSQLSERVER',
    'NT SERVICE\SQLSERVERAGENT',
    'NT SERVICE\SQLTELEMETRY') 
    AND sp.type NOT IN ('R', 'C') 
    AND sp.name NOT LIKE 'NT SERVICE\MSSQL%'
    AND sp.name NOT LIKE 'NT SERVICE\SQLAgent%'
    AND sp.name NOT LIKE '##MS%'
	AND sp.name NOT LIKE (@@SERVERNAME+'\%')
    order by 1;"

    $password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd2023' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes2023.key')
    $credential = New-Object System.Management.Automation.PsCredential("SQL-CENTREON",$password)

    $SQLListener = Invoke-Sqlcmd -Query "Select dns_name From sys.availability_group_listeners" -ServerInstance localhost -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
    if ($SQLListener -eq $null) {
        echo "CRITICAL - ERROR getting Listener name"
        exit 1
    }
    $SQLClusterName = $SQLListener.dns_name

    $resultprimary = Invoke-Sqlcmd -Query $strquerysql -ServerInstance $SQLClusterName -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
    $resultsecondary = Invoke-Sqlcmd -Query $strquerysql -ServerInstance localhost -Credential $credential -QueryTimeout $timeout -ErrorAction Stop

    if ($resultprimary -eq $null) {
        echo "CRITICAL - ERROR getting PRIMARY result"
        exit 1
    }

    if ($resultsecondary -eq $null) {
        echo "CRITICAL - ERROR getting SECONDARY result"
        exit 1
    }

    # compare number of rows
    $difference = Compare-Object -ReferenceObject $resultprimary -DifferenceObject $resultsecondary -PassThru
    
    # Are there any differences?
    if($difference -eq $null -or $difference -eq "")
    {
	    $diffvalue = RBAR-Check $resultprimary $resultsecondary;

        if ($diffvalue -ne $null -and $diffvalue -ne "")
        {    
            echo "CRITICAL - values: $diffvalue"
            exit 2
        }
    }
    else {
        $diffvalue = ""
        $criticalCount = 0
        foreach ($line in $difference) {
                #$tablename = -split $line
                #$diffvalue += $tablename[0] +"; "
                $diffvalue += $line.name +"; "
                $criticalCount++
        }
    }    

    if ($difference -eq "Timeout expired") {
        echo "CRITICAL - Timeout expired getting SELECT result"
        exit 2
    }


    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "CRITICAL - $diffvalue"
        exit 2
    }

    echo "OK - All Logins are synchronized"
    exit 0


}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}

