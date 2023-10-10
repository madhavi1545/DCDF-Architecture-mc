use database dev_webinar_orders_rl_db;
use schema   tpch;
use warehouse dev_webinar_wh;
CREATE OR REPLACE  TABLE orders (
    dw_order_shk       BINARY(40),     -- Example data type, adjust as needed
    dw_hash_diff       BINARY (40),     -- Example data type, adjust as needed
    dw_version_ts      TIMESTAMP,       -- Example data type, adjust as needed
    o_orderkey         INT,             -- Example data type, adjust as needed
    o_custkey          INT,             -- Example data type, adjust as needed
    o_orderstatus      VARCHAR(1),      -- Example data type, adjust as needed
    o_totalprice       DECIMAL(10, 2),  -- Example data type, adjust as needed
    o_orderdate        DATE,            -- Example data type, adjust as needed
    o_orderpriority    VARCHAR(15),     -- Example data type, adjust as needed
    o_clerk            VARCHAR(20),     -- Example data type, adjust as needed
    o_shippriority     INT,             -- Example data type, adjust as needed
    o_comment          VARCHAR(1000),   -- Example data type, adjust as needed
    last_modified_dt   TIMESTAMP,       -- Example data type, adjust as needed
    dw_file_name       VARCHAR(255),    -- Example data type, adjust as needed
    dw_file_row_no     INT,             -- Example data type, adjust as needed
    dw_load_ts         TIMESTAMP,       -- Example data type, adjust as needed
    dw_update_ts       TIMESTAMP        -- Example data type, adjust as needed
);

execute immediate '

declare
  l_start_dt date;
  l_end_dt   date;
 -- Grab the dates for the logical partitions to process
  c1 cursor for select start_dt, end_dt FROM table(dev_webinar_common_db.util.dw_delta_date_range_f(''week'')) order by 1;
  
begin
  
  --
  -- Loop through the dates to incrementally process based on the logical partitions.  
  -- In this example, the logical partiitons are by week.
  --
  for record in c1 do
    l_start_dt := record.start_dt;
    l_end_dt   := record.end_dt;

    --
    -- Merge Pattern 
    --
    merge into orders tgt using
    (
        with l_stg as
        (
            --
            -- Driving CTE to identify all records in the logical partition to be processed
            --
            select
                -- generate hash key and hash diff to streamline processing
                 sha1_binary( s.o_orderkey )  as dw_order_shk
                -- note that last_modified_dt is not included in the hash diff since it only represents recency of the record versus an 
                -- actual meaningful change in the data
                ,sha1_binary( concat( s.o_orderkey
                                     ,''|'', coalesce( to_char( s.o_custkey ), ''~'' )
                                     ,''|'', coalesce( trim( s.o_orderstatus ), ''~'' )
                                     ,''|'', coalesce( to_char( s.o_totalprice ), ''~'' )
                                     ,''|'', coalesce( to_char( s.o_orderdate, ''yyyymmdd'' ), ''~'' )
                                     ,''|'', coalesce( s.o_orderpriority, ''~'' )
                                     ,''|'', coalesce( s.o_clerk, ''~'' )
                                     ,''|'', coalesce( s.o_shippriority, ''~'' )
                                     ,''|'', coalesce( s.o_comment, ''~'' )
                                    )
            
                            )               as dw_hash_diff
                ,s.*
            from
                orders_stg s
            where
                    s.o_orderdate >= :l_start_dt
                and s.o_orderdate  < :l_end_dt
        )
        ,l_deduped as
        (
            -- 
            -- Dedupe the records from the staging table.
            -- This assumes that there may be late arriving or duplicate data that were loaded
            -- Need to identify the most recent record and use that to update the Current state table.
            -- as there is no reason to process each individual change in the record, the last one would have the most recent updates
            select
                *
            from
                l_stg s
            qualify
                row_number() over( partition by dw_order_shk order by s.last_modified_dt desc ) = 1
        )
        ,l_tgt as
        (
            --
            -- Select the records in the logical partition from the current table. 
            -- Its own CTE, for partition pruning efficiencies
            select *
            from orders
            where
                -- this criteria would be dynamic as a production script, reflecting the range of dates in the _stg table.
                    o_orderdate >= :l_start_dt
                and o_orderdate  < :l_end_dt
        )
        select
             current_timestamp()        as dw_version_ts
            ,s.*
        from
            l_deduped s
            left join l_tgt t on
                t.dw_order_shk = s.dw_order_shk
        where
            -- source row does not exist in target table
            t.dw_order_shk is null
            -- or source row is more recent and differs from target table
            or (
                    t.last_modified_dt  < s.last_modified_dt
                and t.dw_hash_diff     != s.dw_hash_diff
               )
        order by
            s.o_orderdate -- physically sort rows by logical partitioning date
    ) src
    on
    (
            tgt.dw_order_shk = src.dw_order_shk
        and tgt.o_orderdate >= :l_start_dt 
        and tgt.o_orderdate  < :l_end_dt 
    )
    when matched then update set
         tgt.dw_hash_diff      = src.dw_hash_diff
        ,tgt.dw_version_ts     = src.dw_version_ts
        ,tgt.o_orderkey        = src.o_orderkey
        ,tgt.o_custkey         = src.o_custkey
        ,tgt.o_orderstatus     = src.o_orderstatus
        ,tgt.o_totalprice      = src.o_totalprice
        ,tgt.o_orderdate       = src.o_orderdate
        ,tgt.o_orderpriority   = src.o_orderpriority
        ,tgt.o_clerk           = src.o_clerk
        ,tgt.o_shippriority    = src.o_shippriority
        ,tgt.o_comment         = src.o_comment
        ,tgt.last_modified_dt  = src.last_modified_dt
        ,tgt.dw_file_name      = src.dw_file_name
        ,tgt.dw_file_row_no    = src.dw_file_row_no
        ,tgt.dw_update_ts      = src.dw_version_ts
    when not matched then insert
    (
         dw_order_shk
        ,dw_hash_diff
        ,dw_version_ts
        ,o_orderkey
        ,o_custkey
        ,o_orderstatus
        ,o_totalprice
        ,o_orderdate
        ,o_orderpriority
        ,o_clerk
        ,o_shippriority
        ,o_comment
        ,last_modified_dt
        ,dw_file_name
        ,dw_file_row_no
        ,dw_load_ts
        ,dw_update_ts
    )
    values
    (
         src.dw_order_shk
        ,src.dw_hash_diff
        ,src.dw_version_ts
        ,src.o_orderkey
        ,src.o_custkey
        ,src.o_orderstatus
        ,src.o_totalprice
        ,src.o_orderdate
        ,src.o_orderpriority
        ,src.o_clerk
        ,src.o_shippriority
        ,src.o_comment
        ,src.last_modified_dt
        ,src.dw_file_name
        ,src.dw_file_row_no
        ,src.dw_load_ts
        ,src.dw_version_ts
    )
    ;

  end for;
  
  return ''SUCCESS'';

end;
'
;
select * 
from dev_webinar_orders_rl_db.tpch.orders 
where o_orderkey = 5722076550;