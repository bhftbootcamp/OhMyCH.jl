# OhMyCH.jl

[![DeepWiki](https://img.shields.io/badge/DeepWiki-bhftbootcamp%2FOhMyCH.jl-blue.svg?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAC0ElEQVR4nO2XT2hTRxDGf7vvJX+aGFPBijVKFUEt1YIepIKKJ72IFy8ePHixJ+8igiiIICIiHkREPCiieCkFkSp4MBVBKVVQW0ulWiP+qxqbpMl7b3ZmvSRpYtoX46V+8Hh8s9/ON/PtLMzjf9cMUBUVOf6jOaDeUMf3MgFwCKiKnJwJABRlCcC+W0EGAIuq8m0c8T0wsRGYxbMzgZlAI0C1Aj4MYDZwStVaSQu+BAwgqgPYDkQn4WYCSRViRYAqyNkGUAKwDHgowERx2kBm4AIsCMGMFEhEZgP3AJ2KSr3WGh8L2AbEJmEmAdsU5SDwBbgQ2q0r0kqN8EbFGVrwNiJPAnBjAJWAZcj5EehsJrAM8B0YC5woW3gIXAQ2GOv64C2UGywA+BhGz5NAFYBRzXJZ4FngOXAwyS7/wPOqBmAGwCp3XJ54BzwBmNePL4YeBHYC2fSiulJwB5V+Z6AvhfYpCrf1QN94FfAk8BJVT7zn+OtYLOAQ/7UOgB+Am4DFhTxTcBewALsBe5v5HGAHcB94C7gc3K8i0V+Q5Y7i9gnKrtjpE+BPxcxQHn/M/7AOtU9I77Kj4M3AEmKrk/gnJrgI8BY4oC0cAKoEfBRhVNELgHWiD0fQmJw7hPYFlm/WOgO3AS2K2IP3JCOY7/dQAHfCGJJwBfAieA+4FZSYaAHp+YTcBtVfkR0KMhEZe8F7gN7FXEY8D5A3dVJF8BLANN8ixQSW/LE8QA8BTYZ0tNlYDFwIEI8Qlw1he4BWyNkB4BPqUqSxepSBawJSJlEPvXFmAh8COWeSoxCdgJnI1oGgIMAf1AezwyS4HlQDvQBrQCLUAz0Ag0APVAHVCrYl0AGPLBFrADOK0q3wRufY3AvYD9AWMNVRlWkW4F3A88D5h7BPgwxoMnn7VEj/4gEN0L9P4HXANM07CcZo7qH/8AAAAldEVYdGRhdGU6Y3JlYXRlADIwMjUtMDItMjdUMDk6NTM6MTArMDA6MDA5vDiFAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDI1LTAyLTI3VDA5OjUzOjEwKzAwOjAwSGGAOQAAAABJRU5ErkJggg==)](https://deepwiki.com/bhftbootcamp/OhMyCH.jl)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://bhftbootcamp.github.io/OhMyCH.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://bhftbootcamp.github.io/OhMyCH.jl/dev/)
[![Build Status](https://github.com/bhftbootcamp/OhMyCH.jl/actions/workflows/Coverage.yml/badge.svg?branch=master)](https://github.com/bhftbootcamp/OhMyCH.jl/actions/workflows/Coverage.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/bhftbootcamp/OhMyCH.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/bhftbootcamp/OhMyCH.jl)
[![Registry](https://img.shields.io/badge/registry-Green-green)](https://github.com/bhftbootcamp/Green)

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

## Usage

### Connecting

```julia
using OhMyCH

client = connect("http://127.0.0.1:8123")

# With credentials and options
client = connect("http://127.0.0.1:8123";
    database = "analytics",
    user     = "admin",
    password = "secret",
)
```

Use the do-block form for automatic cleanup:

```julia
connect("http://127.0.0.1:8123") do client
    result = query(client, "SELECT 1")
    collect(result)
end
```

### DDL

```julia
execute(client, """
    CREATE TABLE IF NOT EXISTS employees (
        name   String,
        age    Int32,
        salary Float64
    ) ENGINE = MergeTree() ORDER BY name
""")
```

### Insert

```julia
struct Employee
    name::String
    age::Int32
    salary::Float64
end

insert(client, "employees", [
    Employee("Alice",   29, 75000.5),
    Employee("Bob",     35, 92000.0),
    Employee("Charlie", 42, 110000.0),
])
```

The columns are named after the row's fields — `INSERT INTO employees (name, age, salary)` —
so the field order does not have to follow the table, and every value is written as its
column's own type: an `Int` into an `Int32` column, a `DateTime` into a `DateTime64(3)`,
a `Float64` into a `Decimal(18, 8)`, `missing` into a `Nullable`. The table's schema is
asked of the server once per client (`table_schema`). A field that names no column is
an error before anything is sent; a full `INSERT INTO t (b, a)` statement is sent as
written, positionally.

### Query

```julia
result = query(client, "SELECT * FROM employees WHERE salary > {min_salary:Float64}", (min_salary = 80000.0,))

for row in result
    println(row.name, " — ", row.salary)
end
```

### Fetch helpers

```julia
# All rows as Vector{Employee}
employees = fetch_all(client, "SELECT * FROM employees", Employee)

# Single row (throws if 0 rows)
top = fetch_one(client, "SELECT * FROM employees ORDER BY salary DESC LIMIT 1", Employee)

# Optional row (returns nothing if 0 rows)
row = fetch_optional(client, "SELECT * FROM employees WHERE name = {n:String}", Employee, (n = "Unknown",))
```

Columns are matched to the fields of `Employee` by name, in any order and with extra
columns ignored, and each value is coerced to the field's type: an `Int32` column fills
an `Int` field, a `DateTime64` a `DateTime`, a `Decimal` a `Float64`, a `Nullable` a
`Union{Missing,T}` (or `Union{Nothing,T}`). A field without a column, or a `NULL` for a
field that cannot hold one, is an `ArgumentError` naming it. `Tuple` row types are
filled by position.

### Inserter

Streaming insert with automatic flushing by row count, byte size, or time period:

```julia
inserter(client, "employees", Employee; max_rows = 1000, period = 5.0) do ins
    for i in 1:10_000
        write(ins, Employee("user_$i", i % 50, 50000.0 + i))
        commit!(ins)  # flushes only when a threshold is reached
    end
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

These are the types a `NamedTuple` row carries. A typed row (`fetch_all(client, sql, T)`)
may declare any field type the column's value converts to; a `DateTime64` column is always
decoded by its declared precision when the result carries a schema (`query`), and only
guessed from the value's magnitude without one (`query_binary`).

## Useful links

- [ClickHouse HTTP Interface](https://clickhouse.com/docs/en/interfaces/http) – HTTP protocol reference
- [RowBinary format](https://clickhouse.com/docs/en/interfaces/formats#rowbinary) – wire format used by OhMyCH
- [Query parameters](https://clickhouse.com/docs/en/interfaces/cli#cli-queries-with-parameters) – parameterized queries syntax

## Contributing

Contributions to OhMyCH are welcome! If you encounter a bug, have a feature request, or would like to contribute code, please open an issue or a pull request on GitHub.
