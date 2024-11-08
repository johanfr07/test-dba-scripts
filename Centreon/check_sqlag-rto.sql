SELECT    P.replica_server_name,
        P.database_name,
        CAST(s.redo_queue_size/s.redo_rate AS BIGINT) redo_lag_seconds
FROM
(SELECT    ar.replica_server_name,
        db_name(drs.database_id) database_name,
        drs.redo_queue_size,
        drs.redo_rate
FROM    sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
INNER JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id
AND AR.replica_id = HARS.replica_id
WHERE drs.is_primary_replica=1) P
inner join
(SELECT    ar.replica_server_name,
        db_name(drs.database_id) database_name,
        drs.redo_queue_size,
        drs.redo_rate
FROM    sys.dm_hadr_database_replica_states drs
INNER JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
INNER JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id
AND AR.replica_id = HARS.replica_id
WHERE drs.is_primary_replica=0) S  ON P.database_name=S.database_name
