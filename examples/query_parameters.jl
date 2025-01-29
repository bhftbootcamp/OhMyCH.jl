#__ query_parameters

using Dates
using OhMyCH
using OhMyCH: NanoDate, UUID, IPv4, IPv6

client = ohmych_connect(
    "http://127.0.0.1:8123/",
    "default",
    "default",
    "",
)

parameters = (
    uint8 = 1,
    int32 = -42,
    float64 = 3.14159,
    date = Date(2025, 1, 1),
    datetime = DateTime(2025, 1, 1, 12, 0, 0),
    datetime_nano = NanoDate(2025, 1, 1, 12, 0, 0, 123),
    uuid = UUID("61f0c404-5cb3-11e7-907b-a6006ad3dba0"),
    ipv4 = IPv4("192.168.1.1"),
    ipv6 = IPv6("::1"),
    array_uint8 = [1, 2, 3],
    dict_string_to_string = Dict("key1" => "value1", "key2" => "value2"),
    low_cardinality = "example",
    decimal_34_18 = Decimal{34,18}("123.456"),
    fixed_string_5 = FixedString{5}("Hello"),
    nullable_int32 = nothing,
    nullable_string = nothing,
    map_string_to_int = Dict("key1" => 1, "key2" => 2),
    tuple_mixed = (1, "example", 1.23),
)

QUERY = """
    SELECT
         {uint8:UInt8}                                AS uint8
        ,{int32:Int32}                                AS int32
        ,{float64:Float64}                            AS float64
        ,{date:Date}                                  AS date
        ,{datetime:DateTime}                          AS datetime
        ,{datetime_nano:DateTime64(3)}                AS nano_datetime
        ,{uuid:UUID}                                  AS uuid
        ,{ipv4:IPv4}                                  AS ipv4
        ,{ipv6:IPv6}                                  AS ipv6
        ,{array_uint8:Array(UInt8)}                   AS array_uint8
        ,{dict_string_to_string:Map(String, String)}  AS dict_example
        ,{low_cardinality:LowCardinality(String)}     AS low_cardinality
        ,{decimal_34_18:Decimal(34,18)}               AS decimal
        ,{fixed_string_5:FixedString(5)}              AS fixed_string
        ,{nullable_int32:Nullable(Int32)}             AS nullable_int32
        ,{nullable_string:Nullable(String)}           AS nullable_string
        ,{map_string_to_int:Map(String, Int32)}       AS map_example
        ,{tuple_mixed:Tuple(Int32, String,Float64)}   AS tuple_example
"""

query_result = query(client, QUERY, parameters)

collect(query_result)

close(client)
