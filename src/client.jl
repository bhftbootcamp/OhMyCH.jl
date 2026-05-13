"""
    CHConfig

Defines the configuration for the connection to the ClickHouse database.
All fields are plain data types, making the config easily serializable to/from TOML, JSON, etc.

## Fields
- `url::String`: Database server URL.
- `database::String`: Name of the database.
- `user::String`: Username for authentication.
- `password::String`: Password for authentication.
- `compression::Symbol`: Compression codec (`:lz4` or `:none`).
- `connect_timeout::Float64`: TCP connection timeout in seconds.
- `read_timeout::Float64`: Total HTTP operation timeout in seconds.
- `retry::Int`: Number of retry attempts on transient errors.
- `retry_delay::Float64`: Delay between retries in seconds.
- `verify_ssl::Bool`: Verify SSL certificates (both peer and host) for HTTPS.
"""
struct CHConfig
    url::String
    database::String
    user::String
    password::String
    compression::Symbol
    connect_timeout::Float64
    read_timeout::Float64
    retry::Int
    retry_delay::Float64
    verify_ssl::Bool
end

function Base.show(io::IO, c::CHConfig)
    redacted = isempty(c.password) ? "" : "***"
    print(io, "CHConfig(url=$(repr(c.url)), database=$(repr(c.database)), ",
              "user=$(repr(c.user)), password=$(repr(redacted)), ",
              "compression=$(repr(c.compression)), connect_timeout=$(c.connect_timeout), ",
              "read_timeout=$(c.read_timeout), retry=$(c.retry), ",
              "retry_delay=$(c.retry_delay), verify_ssl=$(c.verify_ssl))")
end

"""
    CHClient

Defines a client to connect to the ClickHouse database.
Reuses the underlying TCP connection across requests via the persistent `CurlClient` handle.

A `CHClient` is safe to share between Julia tasks: HTTP operations are serialized through
an internal `ReentrantLock` because the wrapped libcurl handle is not concurrency-safe.

## Fields
- `config::CHConfig`: Connection configuration, including URL, database name, and credentials.
- `curl_client::CurlClient`: Handles HTTP communication with the database server.
- `lock::ReentrantLock`: Serializes access to `curl_client`.
"""
mutable struct CHClient
    config::CHConfig
    curl_client::CurlClient
    lock::ReentrantLock

    function CHClient(config::CHConfig, curl_client::CurlClient)
        c = new(config, curl_client, ReentrantLock())
        finalizer(close, c)
        return c
    end
end

function Base.show(io::IO, c::CHClient)
    cfg = c.config
    ssl = cfg.verify_ssl ? "on" : "off"
    print(io, "CHClient(url = $(cfg.url), database = $(cfg.database), user = $(cfg.user), ssl = $ssl)")
end

"""
    isopen(client::CHClient) -> Bool

Checks that the `client` is connected to the database.
"""
Base.isopen(c::CHClient) = isopen(c.curl_client)

"""
    close(client::CHClient)

Closes the `client` connection to the database.
"""
Base.close(c::CHClient) = close(c.curl_client)

"""
    ping(client::CHClient) -> Bool

Checks connectivity to the ClickHouse server. Returns `true` if the server responds, `false` otherwise.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> ping(client)
true
```
"""
function ping(client::CHClient)
    try
        _perform_query(client, "SELECT 1"; read_timeout = 5)
        return true
    catch e
        e isa InterruptException && rethrow()
        return false
    end
end

"""
    server_version(client::CHClient) -> String

Returns the ClickHouse server version string.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> server_version(client)
"24.3.1.2672"
```
"""
function server_version(client::CHClient)
    res = _perform_query(client, "SELECT version() FORMAT TabSeparated"; read_timeout = 5)
    return strip(String(res))
end

"""
    connect(url::String; database, user, password, compression, connect_timeout, read_timeout, retry, retry_delay, verify_ssl) -> CHClient
    connect(config::CHConfig) -> CHClient
    connect(f::Function, args...; kw...)

Creates a [`CHClient`](@ref) instance to connect to a ClickHouse database.
Once the connection is no longer needed, it must be closed using the [`close`](@ref) method.
The method that takes a function `f` as the first argument will close the connection
automatically when `f` returns or throws, and returns `f`'s return value.

The client reuses the underlying TCP connection across requests (HTTP keep-alive).

## Keyword arguments
- `database::String`: Name of the database (default: `"default"`).
- `user::String`: Username for authentication (default: `"default"`).
- `password::String`: Password for authentication (default: `""`).
- `compression::Symbol`: Compression codec, `:lz4` or `:none` (default: `:lz4`).
- `connect_timeout::Real`: TCP connection timeout in seconds (default: `10`).
- `read_timeout::Real`: Total HTTP operation timeout in seconds (default: `300`).
- `retry::Int`: Number of retry attempts on transient errors (default: `0`).
- `retry_delay::Real`: Delay between retries in seconds (default: `1.0`).
- `verify_ssl::Bool`: Whether to verify SSL certificates (default: `true`).

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> client = connect("http://127.0.0.1:8123"; database="mydb", user="admin", password="secret")

julia> client = connect("http://127.0.0.1:8123"; read_timeout=600, retry=3, compression=:none)
```
"""
function connect(
    url::String;
    database::String = "default",
    user::String = "default",
    password::String = "",
    compression::Symbol = :lz4,
    connect_timeout::Real = 10,
    read_timeout::Real = 300,
    retry::Int = 0,
    retry_delay::Real = 1.0,
    verify_ssl::Bool = true,
)
    resolve_codec(compression)

    config = CHConfig(
        url, database, user, password, compression,
        Float64(connect_timeout), Float64(read_timeout),
        retry, Float64(retry_delay),
        verify_ssl,
    )
    return CHClient(config, CurlClient())
end

function connect(c::CHConfig)
    resolve_codec(c.compression)
    return CHClient(c, CurlClient())
end

function connect(f::Function, x...; kw...)
    c = connect(x...; kw...)
    try
        f(c)
    finally
        close(c)
    end
end

const _RESERVED_QUERY_KEYS = ("query", "enable_http_compression")

function _build_query_params(sql::String, parameters::NamedTuple, options)
    params = Dict{String,Any}()
    for (k, v) in options
        key = string(k)
        if key in _RESERVED_QUERY_KEYS || startswith(key, "param_")
            throw(ArgumentError("option `$key` is reserved by OhMyCH and cannot be passed through `options...`"))
        end
        params[key] = v
    end
    for (k, v) in parameters_to_strings(parameters)
        params[k] = v
    end
    params["query"] = sql
    return params
end

function _perform_query(
    client::CHClient,
    sql::String;
    parameters::NamedTuple = NamedTuple(),
    body::Vector{UInt8} = UInt8[],
    compression::Symbol = client.config.compression,
    connect_timeout::Real = client.config.connect_timeout,
    read_timeout::Real = client.config.read_timeout,
    retry::Int = client.config.retry,
    retry_delay::Real = client.config.retry_delay,
    options...,
)
    codec = resolve_codec(compression)
    compress = !(codec isa NoCompression)
    enc = content_encoding(codec)
    headers = Pair{String,String}[
        "x-clickhouse-user"     => client.config.user,
        "x-clickhouse-key"      => client.config.password,
        "x-clickhouse-database" => client.config.database,
    ]
    if compress
        push!(headers, "accept-encoding"  => enc)
        push!(headers, "content-encoding" => enc)
    end
    params = _build_query_params(sql, parameters, options)
    params["enable_http_compression"] = compress ? "1" : "0"
    req = try
        lock(client.lock) do
            http_request(
                client.curl_client,
                "POST",
                client.config.url,
                headers = headers,
                query = params,
                body = compress ? encode(codec, body) : body,
                connect_timeout = ceil(Int, connect_timeout),
                read_timeout = ceil(Int, read_timeout),
                retry = retry,
                retry_delay = retry_delay,
                ssl_verifyhost = client.config.verify_ssl,
                ssl_verifypeer = client.config.verify_ssl,
                status_exception = false,
                accept_encoding = nothing,
            )
        end
    catch e
        if e isa AbstractCurlError
            msg = try
                e.message
            catch
                "libcurl error (code $(isdefined(e, :code) ? e.code : -1))"
            end
            throw(CHClientException(msg, e))
        elseif e isa OhMyCHException
            rethrow()
        else
            throw(CHClientException(sprint(showerror, e), e))
        end
    end
    encoding = http_header(req, "content-encoding", nothing)
    compressed = compress && encoding == enc
    res = compressed ? decode(codec, req.body) : req.body
    code = http_header(req, "x-clickhouse-exception-code", nothing)
    isnothing(code) || throw(CHServerException(code, res))
    check_and_throw_exception(res)
    req.status >= 400 && throw(CHClientException("HTTP $(req.status): $(String(res))"))
    return res
end

"""
    execute(client::CHClient, sql::String [, parameters::NamedTuple]; options...)

Sends an SQL query to the database using the [`CHClient`](@ref) `client`.
Values that need to be substituted into the query can be specified as `parameters` (see more in [Queries with parameters](https://clickhouse.com/docs/en/interfaces/cli#cli-queries-with-parameters)).

## Keyword arguments
- `compression::Symbol`: Compression codec, `:lz4` or `:none` (default: client's compression).
- `read_timeout::Real`: Total HTTP operation timeout in seconds (default: client's read_timeout).
- `max_execution_time::Int`: ClickHouse server-side query timeout in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> employees_query = \"\"\"
       CREATE TABLE IF NOT EXISTS employees
       (
            name     String
           ,age      Int32
           ,position String
           ,salary   Float64
       )
       ENGINE = MergeTree()
       ORDER BY name
       \"\"\";

julia> execute(client, employees_query)
```
"""
function execute(
    client::CHClient,
    sql::String,
    parameters::NamedTuple = NamedTuple();
    compression::Symbol = client.config.compression,
    read_timeout::Real = client.config.read_timeout,
    max_execution_time::Int = 60,
    options...,
)
    _perform_query(
        client,
        sql;
        parameters = parameters,
        compression = compression,
        read_timeout = read_timeout,
        max_execution_time = max_execution_time,
        options...,
    )
    return nothing
end

_build_insert_sql(table::AbstractString) =
    occursin(r"^\s*INSERT\s"i, table) ?
        string(table, " FORMAT RowBinary") :
        string("INSERT INTO ", table, " FORMAT RowBinary")

function _chunked_insert!(
    client::CHClient,
    sql::String,
    values::AbstractVector;
    chunk_size::Integer = 256 * 1024,
    kw...,
)
    cs = Int(chunk_size)
    total = 0
    for batch in RowToBinaryIter(values, cs)
        _perform_query(client, sql; body = batch, kw...)
        total += length(batch)
    end
    return total
end

"""
    insert(client::CHClient, table::String, values::Vector; options...)

Inserts `values` into the specified `table` using the [`CHClient`](@ref) `client`.
The `table` argument can be a simple table name (e.g. `"my_table"`) or a full `INSERT INTO ...` statement for custom cases.

## Keyword arguments
- `chunk_size::Int`: Specifies the approximate size (in bytes) of one chunk of data being sent (default: `256 * 1024` bytes).
- `compression::Symbol`: Compression codec, `:lz4` or `:none` (default: client's compression).
- `read_timeout::Real`: Total HTTP operation timeout in seconds (default: client's read_timeout).
- `max_execution_time::Int`: ClickHouse server-side query timeout in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

## Examples

```julia-repl
julia> struct Employee
           name::String
           age::Int32
           salary::Float64
       end

julia> client = connect("http://127.0.0.1:8123")

julia> insert(client, "employees", [
           Employee("Alice", Int32(29), 75000.5),
           Employee("Bob",   Int32(35), 92000.0),
       ])
```
"""
function insert(
    client::CHClient,
    table::String,
    values::Vector{T};
    chunk_size::Integer = 256 * 1024,
    compression::Symbol = client.config.compression,
    read_timeout::Real = client.config.read_timeout,
    max_execution_time::Int = 60,
    options...,
) where {T}
    _chunked_insert!(
        client,
        _build_insert_sql(table),
        values;
        chunk_size = chunk_size,
        compression = compression,
        read_timeout = read_timeout,
        max_execution_time = max_execution_time,
        options...,
    )
    return nothing
end

"""
    insert_binary(client::CHClient, sql::String, values::RowBinary; options...)

Works similarly to the [`insert`](@ref) method, except that the sending data must be a [`RowBinary`](@ref) object.

!!! tip
    This method is effective when sending small portions of data frequently.
    Intended use in conjunction with [`query_binary`](@ref) for fast data transfer between databases.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> binary_data = query_binary(client, "SELECT * FROM employees")
RowBinary(107-bytes)

julia> insert_binary(client, "INSERT INTO another_employees", binary_data)
```
"""
function insert_binary(
    client::CHClient,
    sql::String,
    values::T;
    compression::Symbol = client.config.compression,
    read_timeout::Real = client.config.read_timeout,
    max_execution_time::Int = 60,
    options...,
) where {T<:RowBinaryResult}
    _perform_query(
        client,
        sql * " FORMAT RowBinary";
        body = readavailable(values.s),
        compression = compression,
        read_timeout = read_timeout,
        max_execution_time = max_execution_time,
        options...,
    )
    return nothing
end

"""
    query(client::CHClient, sql::String [, parameters::NamedTuple]; options...) -> RowBinaryWithNamesAndTypes

Sends an SQL query to the database using the [`CHClient`](@ref) `client`.
Values that need to be substituted into the query can be specified as `parameters` (see more in [Queries with parameters](https://clickhouse.com/docs/en/interfaces/cli#cli-queries-with-parameters)).

!!! info
    This type of query involves returning the result from the database.
    The returned data is represented as a [`RowBinaryWithNamesAndTypes`](@ref) object.

## Keyword arguments
- `compression::Symbol`: Compression codec, `:lz4` or `:none` (default: client's compression).
- `read_timeout::Real`: Total HTTP operation timeout in seconds (default: client's read_timeout).
- `max_execution_time::Int`: ClickHouse server-side query timeout in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

See also [`eachrow`](@ref), [`collect`](@ref), [`fetch_all`](@ref), [`fetch_one`](@ref), [`fetch_optional`](@ref).

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> query(client, "SELECT * FROM employees")
RowBinaryWithNamesAndTypes(161-bytes):
 name::String
 age::Int32
 position::String
 salary::Float64
```
"""
function query(
    client::CHClient,
    sql::String,
    parameters::NamedTuple = NamedTuple();
    compression::Symbol = client.config.compression,
    read_timeout::Real = client.config.read_timeout,
    max_execution_time::Int = 60,
    options...,
)
    res = _perform_query(
        client,
        sql * " FORMAT RowBinaryWithNamesAndTypes";
        parameters = parameters,
        compression = compression,
        read_timeout = read_timeout,
        max_execution_time = max_execution_time,
        options...,
    )
    return RowBinaryWithNamesAndTypes(res)
end

"""
    query_binary(client::CHClient, sql::String [, parameters::NamedTuple]; options...) -> RowBinary

Works similarly to the [`query`](@ref) method, except that the retrieved data is represented as a [`RowBinary`](@ref) object.

!!! tip
    This method is effective when requesting small portions of data frequently, since the response does not include information about names and data types.
    However, in this case, the user will be required to describe the column types and names themselves using his own type `T`.

See also [`eachrow`](@ref), [`collect`](@ref).

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> query_binary(client, "SELECT * FROM employees")
RowBinary(107-bytes)
```
"""
function query_binary(
    client::CHClient,
    sql::String,
    parameters::NamedTuple = NamedTuple();
    compression::Symbol = client.config.compression,
    read_timeout::Real = client.config.read_timeout,
    max_execution_time::Int = 60,
    options...,
)
    res = _perform_query(
        client,
        sql * " FORMAT RowBinary";
        parameters = parameters,
        compression = compression,
        read_timeout = read_timeout,
        max_execution_time = max_execution_time,
        options...,
    )
    return RowBinary(res)
end

"""
    fetch_all(client::CHClient, sql::AbstractString [, parameters::NamedTuple]; kw...) -> Vector{NamedTuple}
    fetch_all(client::CHClient, sql::AbstractString, ::Type{T} [, parameters::NamedTuple]; kw...) -> Vector{T}

Executes the query and returns all rows as a vector.
Without a type argument, rows are returned as `NamedTuple`s.
With a type `T`, rows are deserialized into objects of type `T`.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> fetch_all(client, "SELECT * FROM employees", Employee)
3-element Vector{Employee}:
 Employee("Alice", 29, 75000.5)
 Employee("Bob", 35, 92000.0)
 ...
```
"""
function fetch_all(client::CHClient, sql::AbstractString, params::NamedTuple = NamedTuple(); kw...)
    return collect(query(client, sql, params; kw...))
end

function fetch_all(client::CHClient, sql::AbstractString, ::Type{T}, params::NamedTuple = NamedTuple(); kw...) where {T}
    return collect(T, query(client, sql, params; kw...))
end

"""
    fetch_one(client::CHClient, sql::AbstractString [, parameters::NamedTuple]; kw...) -> NamedTuple
    fetch_one(client::CHClient, sql::AbstractString, ::Type{T} [, parameters::NamedTuple]; kw...) -> T

Executes the query and returns exactly one row.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> fetch_one(client, "SELECT * FROM employees ORDER BY salary DESC LIMIT 1", Employee)
Employee("Charlie", 42, 110000.0)
```
"""
function fetch_one(client::CHClient, sql::AbstractString, params::NamedTuple = NamedTuple(); kw...)
    rows = fetch_all(client, sql, params; kw...)
    n = length(rows)
    n == 1 || throw(ArgumentError("query returned $n rows, expected exactly 1"))
    return first(rows)
end

function fetch_one(client::CHClient, sql::AbstractString, ::Type{T}, params::NamedTuple = NamedTuple(); kw...) where {T}
    rows = fetch_all(client, sql, T, params; kw...)
    n = length(rows)
    n == 1 || throw(ArgumentError("query returned $n rows, expected exactly 1"))
    return first(rows)
end

"""
    fetch_optional(client::CHClient, sql::AbstractString [, parameters::NamedTuple]; kw...) -> Union{NamedTuple, Nothing}
    fetch_optional(client::CHClient, sql::AbstractString, ::Type{T} [, parameters::NamedTuple]; kw...) -> Union{T, Nothing}

Executes the query and returns one row, or `nothing` if the query returns 0 rows.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> fetch_optional(client, "SELECT * FROM employees WHERE name = 'Unknown'")
nothing
```
"""
function fetch_optional(client::CHClient, sql::AbstractString, params::NamedTuple = NamedTuple(); kw...)
    rows = fetch_all(client, sql, params; kw...)
    return isempty(rows) ? nothing : first(rows)
end

function fetch_optional(client::CHClient, sql::AbstractString, ::Type{T}, params::NamedTuple = NamedTuple(); kw...) where {T}
    rows = fetch_all(client, sql, T, params; kw...)
    return isempty(rows) ? nothing : first(rows)
end
