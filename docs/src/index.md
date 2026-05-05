# OhMyCH.jl

OhMyCH is a typed Julia client for [ClickHouse](https://clickhouse.com/) that communicates over the HTTP interface using the [RowBinary](https://clickhouse.com/docs/en/interfaces/formats#rowbinary) format.

## Installation

If you haven't installed our [local registry](https://github.com/bhftbootcamp/Green) yet, do that first:
```
] registry add https://github.com/bhftbootcamp/Green.git
```

Then install the package:
```
] add OhMyCH
```

## Quick start

```julia
using OhMyCH

connect("http://127.0.0.1:8123") do client
    execute(client, """
        CREATE TABLE IF NOT EXISTS employees (
            name   String,
            age    Int32,
            salary Float64
        ) ENGINE = MergeTree() ORDER BY name
    """)

    insert(client, "employees", [
        (name = "Alice",   age = Int32(29), salary = 75000.5),
        (name = "Bob",     age = Int32(35), salary = 92000.0),
        (name = "Charlie", age = Int32(42), salary = 110000.0),
    ])

    for row in query(client, "SELECT * FROM employees")
        println(row.name, " — ", row.salary)
    end

    execute(client, "DROP TABLE employees")
end
```

## Type mapping

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
