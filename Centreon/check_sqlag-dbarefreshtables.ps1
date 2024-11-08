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
            $line1 += $array1[$row_index][$column_index] +"|"
            $line2 += $array2[$row_index][$column_index] +"|"
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

    $strquerysql = "SELECT [table_name],[database_name] FROM [DBAdb].[dbo].[Refresh_tables_to_save]"

    $password = Get-Content 'C:\Program Files\NSClient++\scripts\pwd' | ConvertTo-SecureString -Key (Get-Content 'C:\Program Files\NSClient++\scripts\aes.key')
    $credential = New-Object System.Management.Automation.PsCredential("ITReader",$password)

    $SQLListener = Invoke-Sqlcmd -Query "Select dns_name From sys.availability_group_listeners" -ServerInstance localhost -Credential $credential -QueryTimeout $timeout -ErrorAction Stop
    if ($SQLListener -eq $null) {
        echo "CRITICAL - ERROR getting Listener name"
        exit 1
    }
    $SQLClusterName = $SQLListener.dns_name

    #$resultprimary = Invoke-Sqlcmd -Query $strquerysql -ServerInstance $SQLClusterName -Username 'ITReader' -Password 'xxx' -QueryTimeout $timeout -ErrorAction Stop
    #$resultsecondary = Invoke-Sqlcmd -Query $strquerysql -ServerInstance localhost -Username 'ITReader' -Password 'xxx' -QueryTimeout $timeout -ErrorAction Stop

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
    $diffnb = Compare-Object -ReferenceObject $resultprimary -DifferenceObject $resultsecondary -PassThru

    # Are there any differences?
    if($diffnb -eq $null -or $diffnb -eq "")
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
        foreach ($line in $diffnb) {
                #$tablename = -split $line
                #$diffvalue += $tablename[0] +"; "
                $diffvalue += $line.table_name + " " +$line.database_name +"; "
                $criticalCount++
        }
    }


    if ($diffnb -eq "Timeout expired") {
        echo "CRITICAL - Timeout expired getting SELECT result"
        exit 2
    }

    if ($criticalCount -ne 0 -and $diffvalue -ne $null -and $diffvalue -ne "") {
        echo "CRITICAL - nb: $diffvalue"
        exit 2
    }

    echo "OK - All Refresh_tables_to_save are synchronized"
    exit 0

}
catch {    
    $ex = $_.Exception.Message 
    echo "CRITICAL - error $ex";
    exit 2
}



