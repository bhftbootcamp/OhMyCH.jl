# API Reference

```@docs
OhMyCH.HttpConfig
OhMyCH.HttpClient
ohmych_connect
isopen
close
```

## Database requests

```@docs
execute
insert
query
insert_binary
query_binary
```

## Row iteration

```@docs
eachrow
collect
```

## [Column types](@id column_types)

Most of the ClickHouse column types are the same as the Julia base types.

| ClickHouse Type      | Julia Type            |
|----------------------|-----------------------|
| Bool                 | Bool                  |
| Int8-128, UInt8-128  | Int8-128, UInt8-128   |
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
| Array(T)             | AbstractVector{T}     |
| Tuple(T1, T2, ...)   | Tuple                 |
| Map(K, V)            | AbstractDict{K,V}     |
| LowCardinality(T)    | T                     |
| Nullable(T)          | Union{Nothing,T}      |

However, some types had to be implemented independently.

### Decimal

```@docs
Decimal
Decimal(::Union{Real,AbstractString,OhMyCH.DecimalFP})
Decimal(::Integer, ::Integer, ::Integer)
```

### FixedString

```@docs
FixedString
FixedString(::AbstractString)
```

## Exceptions

```@docs
OhMyCH.OhMyCHException
CHServerException
CHClientException
```
