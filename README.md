# OhMyCH.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/OhMyCH.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/OhMyCH.jl/dev/)
[![Build Status](https://github.com/bhftbootcamp/OhMyCH.jl/actions/workflows/Coverage.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/OhMyCH.jl/actions/workflows/Coverage.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/bhftbootcamp/OhMyCH.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/OhMyCH.jl)
[![Registry](https://img.shields.io/badge/registry-Green-green)](https://github.com/bhftbootcamp/Green)

Julia Typed Client for ClickHouse DB

| ClickHouse Type      | Julia Type            | Supported for Input | Supported for Output |
|----------------------|-----------------------|:-------------------:|:--------------------:|
| Bool                 | Bool                  |         ✓           |          ✓           |
| Int8-128, UInt8-128  | Int8-128, UInt8-128   |         ✓           |          ✓           |
| Float32, Float64     | Float32, Float64      |         ✓           |          ✓           |
| Decimal(P,S)         | Decimal{P,S}          |         ✓           |          ✓           |
| String               | String                |         ✓           |          ✓           |
| FixedString(N)       | FixedString{N}        |         ✓           |          ✓           |
| Date                 | Date                  |         ✓           |          ✓           |
| DateTime             | DateTime              |         ✓           |          ✓           |
| DateTime64           | NanoDate              |         ✓           |          ✓           |
| Enum8, Enum16        | UInt8, UInt16         |         ✓           |          ✓           |
| UUID                 | UUID                  |         ✓           |          ✓           |
| IPv4, IPv6           | IPv4, IPv6            |         ✓           |          ✓           |
| Array(T)             | AbstractVector{T}     |         ✓           |          ✓           |
| Tuple(T1, T2, ...)   | Tuple                 |         ✓           |          ✓           |
| Map(K, V)            | AbstractDict{K,V}     |         ✓           |          ✓           |
| LowCardinality(T)    | T                     |         ✓           |          ✓           |
| Nullable(T)          | Union{Nothing,T}      |         ✓           |          ✓           |

## Installation

If you haven't installed our [local registry](https://github.com/bhftbootcamp/Green) yet, do that first:
```
] registry add https://github.com/bhftbootcamp/Green.git
```

Then, to install OhMyCH, simply use the Julia package manager:
```
] add OhMyCH
```

## Usage

Connect to a ClickHouse server using `ohmych_connect`:

```julia
using OhMyCH

client = ohmych_connect(
    "http://127.0.0.1:8123/",
    "analytics_db",
    "analytics_user",
    "OhMyCH@2025!",
)
```

The examples below use the following table as a reference schema:

```sql
CREATE TABLE IF NOT EXISTS my_trades (
    timestamp DateTime64(9),
    trade_id  UInt64,
    symbol    LowCardinality(String),
    side      Enum8('Bid' = 0, 'Ask' = 1),
    price     Decimal(34, 18),
    qty       Float64
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY timestamp
```

Execute `CREATE`, `ALTER`, `DROP`, or `TRUNCATE` DDL commands with `execute`. For example, renaming a column:

```julia
OhMyCH.execute(
    client,
    "ALTER TABLE my_trades RENAME COLUMN qty TO quantity",
    # parameters,
    # options...,
)
```

Use `insert` to insert data into tables. Here is an example of inserting multiple rows at once:

```julia
struct MyTrade
    timestamp::NanoDate
    trade_id::UInt64
    symbol::String
    side::UInt8
    price::Decimal{34,18}
    quantity::Float64
end

OhMyCH.insert(
    client,
    "INSERT INTO my_trades (timestamp, trade_id, symbol, side, price, quantity)",
    MyTrade[
        MyTrade(NanoDate("2025-01-15T08:00:00.123456789"), 1, "AAPL", UInt8(1), Decimal{34,18}("145.321234567890123456"), 100.0),
        MyTrade(NanoDate("2025-01-15T08:05:00.987654321"), 2, "GOOG", UInt8(0), Decimal{34,18}("2745.50000000000000000"), 50.0),
        MyTrade(NanoDate("2025-01-15T08:10:00.111222333"), 3, "TSLA", UInt8(0), Decimal{34,18}("652.801234567890123456"), 200.0),
        MyTrade(NanoDate("2025-01-15T08:15:00.444555666"), 4, "AMZN", UInt8(1), Decimal{34,18}("3301.65000000000000000"), 30.0)
    ],
    chunk_size = 1024 * 1024, # 1 Mbyte
    # options...,
)
```

Use `query` to execute a query and get results in `RowBinaryWithNamesAndTypes`, which can be easily converted to a `NamedTuple` without needing field metadata.

```julia
query_result = OhMyCH.query(
    client,
    "SELECT * FROM my_trades WHERE quantity >= {quantity:Float64}",
    (quantity = 100, ),
    # options...,
)

julia> collect(query_result)
2-element Vector{NamedTuple{(:timestamp, :trade_id, :symbol, :side, :price, :quantity),Tuple{NanoDate,UInt64,String,UInt8,Decimal{34,18},Float64}}}:
 (2025-01-15T08:00:00.123456789, 0x0000000000000001, "AAPL", 0x01, Decimal{34,18}(145.321234567890123456), 100.0)
 (2025-01-15T08:10:00.111222333, 0x0000000000000003, "TSLA", 0x00, Decimal{34,18}(652.801234567890123456), 200.0)

julia> collect(MyTrade, query_result)
2-element Vector{MyTrade}:
 MyTrade(2025-01-15T08:00:00.123456789, 0x0000000000000001, "AAPL", 0x01, Decimal{34,18}(145.321234567890123456), 100.0)
 MyTrade(2025-01-15T08:10:00.111222333, 0x0000000000000003, "TSLA", 0x00, Decimal{34,18}(652.801234567890123456), 200.0)
```

Use `query_binary` for binary results, ideal for performance-critical applications. Deserialize the data into your custom type as needed.

> [!IMPORTANT]  
> The responsibility for correctly matching the deserialized types lies with the developer. If the types do not align, the deserialization may fail or produce incorrect results. This trade-off allows `query_binary` to excel in scenarios where performance is critical and the schema is well-known.

```julia
query_result = OhMyCH.query_binary(
    client,
    "SELECT * FROM my_trades WHERE quantity >= {quantity:Float64}",
    (quantity = 100, ),
    # options...,
)

julia> for item in eachrow(MyTrade, query_result)
           println(item)
       end
MyTrade(2025-01-15T08:00:00.123456789, 0x0000000000000001, "AAPL", 0x01, Decimal{34,18}(145.321234567890123456), 100.0)
MyTrade(2025-01-15T08:10:00.111222333, 0x0000000000000003, "TSLA", 0x00, Decimal{34,18}(652.801234567890123456), 200.0)
```

> [!TIP]
> Always close the client after you’re done:

```julia
try
    # Perform operations
finally
    close(client)
end
```

## Contributing

Contributions to OhMyCH are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
