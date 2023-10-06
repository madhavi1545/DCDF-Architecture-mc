use database DEV_WEBINAR_ORDERS_RL_DB;
use schema   TPCH;
use warehouse dev_webinar_wh;
CREATE TABLE orders (
    o_orderkey INTEGER,
    o_custkey INTEGER,
    o_orderstatus STRING,
    o_totalprice DECIMAL(15, 2),
    o_orderdate DATE,
    o_orderpriority STRING,
    o_clerk STRING,
    o_shippriority INTEGER,
    o_comment STRING,
    last_modified_dt TIMESTAMP
);
copy into
    @~/orders
from
(
    with l_order as
    (
        select
              row_number() over(order by uniform( 1, 60, random() ) ) as seq_no
             ,o.o_orderkey
             ,o.o_custkey
             ,o.o_orderstatus
             ,o.o_totalprice
             ,o.o_orderdate
             ,o.o_orderpriority
             ,o.o_clerk
             ,o.o_shippriority
             ,o.o_comment
        from
            snowflake_sample_data.tpch_sf1000.orders o
        where
                o.o_orderdate >= dateadd( day, -16, to_date( '1998-07-02', 'yyyy-mm-dd' ) )
            and o.o_orderdate  < dateadd( day,   1, to_date( '1998-07-02', 'yyyy-mm-dd' ) )
    )
    select
         lo.o_orderkey
        ,lo.o_custkey
        -- simulate modified data by randomly changing the status
        ,case uniform( 1, 100, random() )
            when  1 then 'A'
            when  5 then 'B'
            when 20 then 'C'
            when 30 then 'D'
            when 40 then 'E'
            else lo.o_orderstatus
         end                            as o_orderstatus
        ,lo.o_totalprice
        ,lo.o_orderdate
        ,lo.o_orderpriority
        ,lo.o_clerk
        ,lo.o_shippriority
        ,lo.o_comment
        ,current_timestamp()            as last_modified_dt -- generating a last modified timestamp as part of data acquisition.
    from
        l_order lo
    order by
        lo.o_orderdate
)
file_format      = ( type=csv field_optionally_enclosed_by = '"' )
overwrite        = false
single           = false
include_query_id = true
max_file_size    = 16000000
;

list @~/orders;