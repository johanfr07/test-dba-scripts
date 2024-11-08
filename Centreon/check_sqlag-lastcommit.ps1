[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 180,
    [Int]$critical = 300,
    [Int]$timeout = 10
   )#End Param
 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.RMO") | Out-Null

#cd "D:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn"
#$result = .\SQLCMD.EXE -i "C:\Program Files\NSClient++\scripts\check_sqlag-lastcommit.sql" -h -1 -S AAGListener.eu.dior.fashion -U 'ITReader' -P 'xxxxxxxxxxx' -t $timeout

$password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd2023' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes2023.key')
$credential = New-Object System.Management.Automation.PsCredential("SQL-CENTREON",$password)

$SQLListener = Invoke-Sqlcmd -Query "Select dns_name From sys.availability_group_listeners" -ServerInstance localhost -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
 if ($SQLListener -eq $null) {
        echo "CRITICAL - ERROR getting Listener name"
        exit 1
}
$SQLClusterName = $SQLListener.dns_name

$result = Invoke-Sqlcmd -InputFile "C:\Program Files\NSClient++\scripts\check_sqlag-lastcommit.sql" -ServerInstance $SQLClusterName -Credential $credential -QueryTimeout $timeout -ErrorAction Stop

if ($result -eq $null) {
    echo "Error getting SELECT result - CRITICAL"
    exit 2
}

if ($result -eq "Timeout expired") {
    echo "Timeout expired getting SELECT result - CRITICAL"
    exit 2
}

$begin = ""
$end = "|"
$warningCount = 0
$criticalCount = 0
foreach ($line in $result) {
    $db = $line.database_name
    $state = $line.synchronization_health_desc
    $diff = [int]$line.timediff_seconds

    $begin += "$db is $state and sync lag is $diff second(s), "
    $end += "'$db'=$diff" + "s;" + $warning + ";" + $critical + ";; "
    if ($diff -gt $critical) {
        $criticalCount++
    }
    elseif ($diff -gt $warning) {
        $warningCount++
    }
}
if ($criticalCount -ne 0) {
    echo "CRITICAL - $begin $end"
    exit 2
}

if ($warningCount -ne 0) {
    echo "WARNING - $begin $end"
    exit 1
}

echo "OK - $begin $end"
exit 0
