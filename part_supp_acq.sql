use database DEV_WEBINAR_ORDERS_RL_DB;
use schema   TPCH;
use warehouse dev_webinar_wh;
CREATE TABLE partsupp (
    seq_no              INT,
    ps_partkey          INT,
    ps_suppkey          INT,
    ps_availqty         INT,
    ps_supplycost       DECIMAL(10, 2), -- Adjust precision and scale as needed
    ps_comment          STRING,          -- Adjust data type as needed
    last_modified_dt    TIMESTAMP
);

copy into
    @~/partsupp
from
(
    with l_partsupp as
    (
        select
              row_number() over(order by uniform( 1, 60, random() ) ) as seq_no
             ,p.ps_partkey
             ,p.ps_suppkey
             ,p.ps_availqty
             ,p.ps_supplycost
             ,p.ps_comment
        from
            snowflake_sample_data.tpch_sf1000.partsupp p
    )
    select
         p.ps_partkey
        ,p.ps_suppkey
        ,p.ps_availqty
        ,p.ps_supplycost
        ,p.ps_comment
        ,current_timestamp()            as last_modified_dt -- generating a last modified timestamp as partsupp of data acquisition.
    from
        l_partsupp p
    order by
        p.ps_partkey
)
file_format      = ( type=csv field_optionally_enclosed_by = '"' )
overwrite        = false
single           = false
include_query_id = true
max_file_size    = 16000000
;