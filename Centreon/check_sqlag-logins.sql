SET NOCOUNT ON;
SELECT sp.name, sp.sid, sp.type, sp.is_disabled, sl.is_policy_checked, sl.is_expiration_checked, sl.password_hash
FROM sys.server_principals sp
LEFT OUTER JOIN sys.sql_logins sl ON sp.name = sl.name
WHERE sp.name NOT IN ('sa', 
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