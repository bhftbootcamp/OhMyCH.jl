# API Reference

## Connection

```@docs
CHConfig
CHClient
connect
Base.isopen(::OhMyCH.CHClient)
Base.close(::OhMyCH.CHClient)
ping
server_version
```

## Queries

```@docs
execute
query
query_binary
fetch_all
fetch_one
fetch_optional
```

## Insert

```@docs
insert
insert_binary
```

## Inserter

```@docs
InsertStats
Inserter
Base.write(::OhMyCH.Inserter{T}, ::Any) where {T}
commit!
flush!
Base.close(::OhMyCH.Inserter)
inserter
```

## Binary formats

```@docs
RowBinaryResult
RowBinary
RowBinaryWithNamesAndTypes
parse_column_type
```

## Row iteration

```@docs
Base.eachrow(::OhMyCH.RowBinaryWithNamesAndTypes)
Base.eachrow(::Type, ::OhMyCH.RowBinaryResult)
Base.collect(::OhMyCH.RowBinaryWithNamesAndTypes)
```

## Compression

```@docs
Codec
LZ4
NoCompression
```

## [Column types](@id column_types)

| ClickHouse Type      | Julia Type            |
|----------------------|-----------------------|
| Bool                 | Bool                  |
| Int8 – Int128        | Int8 – Int128         |
| UInt8 – UInt128      | UInt8 – UInt128       |
| Float32, Float64     | Float32, Float64      |
| Decimal(P,S)         | Decimal{P,S}          |
| String               | String                |
| FixedString(N)       | FixedString{N}        |
| Date                 | Date                  |
| DateTime             | DateTime              |
| DateTime64           | NanoDate              |
| Enum8, Enum16        | UInt8, UInt16         |
| UUID                 | UUID                  |
| IPv4, IPv6           | IPv4, IPv6            |
| Array(T)             | Vector{T}             |
| Tuple(T1, T2, ...)   | Tuple{T1, T2, ...}    |
| Map(K, V)            | Dict{K, V}            |
| Nullable(T)          | Union{Nothing, T}     |
| LowCardinality(T)    | T                     |

### Decimal

```@docs
AbstractDecimal
Decimal
```

### FixedString

```@docs
FixedString
```

## Exceptions

```@docs
OhMyCHException
CHServerException
CHClientException
```
