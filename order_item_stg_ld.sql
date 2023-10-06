use database dev_webinar_orders_rl_db;
use schema   tpch;
use warehouse dev_webinar_wh;
CREATE TABLE orders_stg (
    o_orderkey INT,
    o_custkey INT,
    o_orderstatus CHAR(1),
    o_totalprice DECIMAL(10, 2),
    o_orderdate DATE,
    o_orderpriority VARCHAR(20),   -- Adjust the length accordingly
    o_clerk VARCHAR(50),           -- Adjust the length accordingly
    o_shippriority INT,
    o_comment TEXT,                -- You can adjust the data type and length as needed
    last_modified_dt TIMESTAMP,
    dw_file_name VARCHAR(255),     -- Adjust the length accordingly
    dw_file_row_no INT,
    dw_load_ts TIMESTAMP
);
truncate table orders_stg;
copy into
    orders_stg
from
    (
    select
         s.$1                                            -- o_orderkey
        ,s.$2                                            -- o_custkey
        ,s.$3                                            -- o_orderstatus
        ,s.$4                                            -- o_totalprice
        ,s.$5                                            -- o_orderdate
        ,s.$6                                            -- o_orderpriority
        ,s.$7                                            -- o_clerk
        ,s.$8                                            -- o_shippriority
        ,s.$9                                            -- o_comment
        ,s.$10                                           -- last_modified_dt
        ,metadata$filename                               -- dw_file_name
        ,metadata$file_row_number                        -- dw_file_row_no
        ,current_timestamp()                             -- dw_load_ts
    from
        @~ s
    )
purge         = true
pattern       = '.*orders/data.*\.csv\.gz'
file_format   = ( type=csv field_optionally_enclosed_by = '"' )
on_error      = skip_file