[CmdletBinding()] 
 Param  
   (
    [Int]$warning = 5,
    [Int]$critical = 8,
    [Int]$timeout = 10
   )#End Param
 
cd "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\130\Tools\Binn"
$result = .\SQLCMD.EXE -i "C:\Program Files\NSClient++\scripts\check_sqlag-hadrsynccommit.sql" -h -1 -S CRIDBEUUAT.eu.dior.fashion -U 'SQL-CENTREON' -P 'password' -t $timeout
$begin = ""
$end = "|"
$warningCount = 0
$criticalCount = 0

if ($result -eq $null) {
    echo "Error getting SELECT result - CRITICAL"
    exit 2
}

if ($result -eq "Timeout expired") {
    echo "Timeout expired getting SELECT result - CRITICAL"
    exit 2
}

if ($result -ge $warning) {
    $warningCount = $result
    $begin += "Nb Sessions with HADR SYNC COMMIT waits: "
    $end += $warningCount + ";; "
   
}
if ($result -ge $critical) {
    $criticalCount = $result
    $begin += "Nb Sessions with HADR SYNC COMMIT waits: "
    $end += $criticalCount + ";; "
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
