use database dev_webinar_orders_rl_db;
use schema   tpch;
use warehouse dev_webinar_wh;
CREATE TABLE partsupp_stg (
    ps_partkey INT,
    ps_suppkey INT,
    ps_availqty INT,
    ps_supplycost DECIMAL(10, 2),
    ps_comment TEXT,              -- You can adjust the data type and length as needed
    last_modified_dt TIMESTAMP,
    dw_file_name VARCHAR(255),    -- Adjust the length accordingly
    dw_file_row_no INT,
    dw_load_ts TIMESTAMP
);
truncate table partsupp_stg;
copy into
    partsupp_stg
from
    (
    select
         s.$1                                            -- ps_partkey
        ,s.$2                                            -- ps_suppkey
        ,s.$3                                            -- ps_availqty
        ,s.$4                                            -- ps_supplycost
        ,s.$5                                            -- ps_comment
        ,s.$6                                            -- last_modified_dt
        ,metadata$filename                               -- dw_file_name
        ,metadata$file_row_number                        -- dw_file_row_no
        ,current_timestamp()                             -- dw_load_ts
    from
        @~ s
    )
purge         = true
pattern       = '.*partsupp/data.*\.csv\.gz'
file_format   = ( type=csv field_optionally_enclosed_by = '"' )
on_error      = skip_file