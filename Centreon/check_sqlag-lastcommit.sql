SET NOCOUNT ON;
SELECT P.replica_server_name,
       P.database_name,
       P.ag_name,
       P.synchronization_health_desc,
       DATEDIFF(SECOND, S.last_commit_time, P.last_commit_time) timediff_seconds
FROM
  (SELECT ar.replica_server_name,
          adc.database_name,
          ag.name AS ag_name,
          drs.last_commit_time,
          drs.is_local,
          drs.is_primary_replica,
          drs.synchronization_state_desc,
          drs.synchronization_health_desc
   FROM sys.dm_hadr_database_replica_states AS drs
   INNER JOIN sys.availability_databases_cluster AS adc ON drs.group_id = adc.group_id
   AND drs.group_database_id = adc.group_database_id
   INNER JOIN sys.availability_groups AS ag ON ag.group_id = drs.group_id
   INNER JOIN sys.availability_replicas AS ar ON drs.group_id = ar.group_id
   AND drs.replica_id = ar.replica_id
   WHERE drs.is_primary_replica=1) P
INNER JOIN
  (SELECT ar.replica_server_name,
          adc.database_name,
          ag.name AS ag_name,
          drs.last_commit_time,
          drs.is_local,
          drs.is_primary_replica,
          drs.synchronization_state_desc,
          drs.synchronization_health_desc
   FROM sys.dm_hadr_database_replica_states AS drs
   INNER JOIN sys.availability_databases_cluster AS adc ON drs.group_id = adc.group_id
   AND drs.group_database_id = adc.group_database_id
   INNER JOIN sys.availability_groups AS ag ON ag.group_id = drs.group_id
   INNER JOIN sys.availability_replicas AS ar ON drs.group_id = ar.group_id
   AND drs.replica_id = ar.replica_id
   WHERE drs.is_primary_replica=0) S ON P.database_name=S.database_name
