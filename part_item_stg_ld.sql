use database dev_webinar_orders_rl_db;
use schema   tpch;
use warehouse dev_webinar_wh;
CREATE TABLE part_stg (
    p_partkey INT,
    p_name VARCHAR(255),        -- Adjust the length accordingly
    p_mfgr VARCHAR(50),          -- Adjust the length accordingly
    p_brand VARCHAR(50),         -- Adjust the length accordingly
    p_type VARCHAR(50),          -- Adjust the length accordingly
    p_size INT,
    p_container VARCHAR(50),    -- Adjust the length accordingly
    p_retailprice DECIMAL(10, 2),
    p_comment TEXT,              -- You can adjust the data type and length as needed
    last_modified_dt TIMESTAMP,
    dw_file_name VARCHAR(255),   -- Adjust the length accordingly
    dw_file_row_no INT,
    dw_load_ts TIMESTAMP
);

truncate table part_stg;

copy into
    part_stg
from
    (
    select
         s.$1                                            -- p_partkeyy
        ,s.$2                                            -- p_name
        ,s.$3                                            -- p_mfgr
        ,s.$4                                            -- p_brand
        ,s.$5                                            -- p_type
        ,s.$6                                            -- p_size
        ,s.$7                                            -- p_container
        ,s.$8                                            -- p_retailprice
        ,s.$9                                            -- p_comment
        ,s.$10                                           -- last_modified_dt
        ,metadata$filename                               -- dw_file_name
        ,metadata$file_row_number                        -- dw_file_row_no
        ,current_timestamp()                             -- dw_load_ts
    from
        @~ s
    )
purge         = true
pattern       = '.*part/data.*\.csv\.gz'
file_format   = ( type=csv field_optionally_enclosed_by = '"' )
on_error      = skip_file