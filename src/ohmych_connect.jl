#__ ohmych_connect

"""
    HttpConfig

Defines the configuration for the HTTP connection to the database.

## Fields
- `url::String`: Database server URL.
- `database::String`: Name of the database.
- `user::String`: Username for authentication.
- `password::String`: Password for authentication.
- `verify_ssl::Bool`: Verify SSL certificates for HTTPS.
"""
struct HttpConfig
    url::String
    database::String
    user::String
    password::String
    verify_ssl::Bool
end

"""
    HttpClient

Defines an HTTP client to connect to the database.

## Fields
- `config::HttpConfig`: Connection configuration, including URL, database name, and credentials.
- `curl_client::CurlClient`: Handles HTTP communication with the database server.
"""
mutable struct HttpClient
    config::HttpConfig
    curl_client::CurlClient

    function HttpClient(config::HttpConfig, curl_client::CurlClient)
        c = new(config, curl_client)
        finalizer(close, c)
        return c
    end
end

function Base.show(io::IO, c::HttpClient)
    print(io, "HttpClient(url = $(c.config.url), database = $(c.config.database), user = $(c.config.user), ssl = $(c.config.verify_ssl ? "on" : "off"))")
end

"""
    isopen(client::HttpClient) -> Bool

Checks that the `client` is connected to the database.
"""
Base.isopen(c::HttpClient) = isopen(c.curl_client)

"""
    close(client::HttpClient)

Closes the `client` connection to the database.
"""
Base.close(c::HttpClient) = close(c.curl_client)

"""
    ohmych_connect(url::String, database::String, user::String, password::String) -> HttpClient
    ohmych_connect(config::HttpConfig) -> HttpClient
    ohmych_connect(f::Function, args...) -> HttpClient

Creates an [`HttpClient`](@ref) instance to connect to a database.
Once the connection is no longer needed, it must be closed using the [`close`](@ref) method.
The method that takes a function `f` as the first argument will close the connection automatically.

## Keyword arguments
- `verify_ssl::Bool`: Whether to verify the SSL certificate (default: `true`).
"""
function ohmych_connect(
    url::String,
    database::String,
    user::String,
    password::String;
    verify_ssl::Bool = true,
)::HttpClient
    return HttpClient(HttpConfig(url, database, user, password, verify_ssl), CurlClient())
end

ohmych_connect(c::HttpConfig) = HttpClient(c, CurlClient())

function ohmych_connect(f::Function, x...; kw...)
    c = ohmych_connect(x...; kw...)
    try
        f(c)
    finally
        close(c)
    end
end

#___

function _perform_query(
    client::HttpClient,
    sql_query::String;
    parameters::NamedTuple = NamedTuple(),
    body::Vector{UInt8} = UInt8[],
    use_compression::Bool = true,
    compression::Type{<:Codec} = Lz4,
    options...,
)::Vector{UInt8}
    headers = Pair{String,String}[
        "x-clickhouse-user"     => client.config.user,
        "x-clickhouse-key"      => client.config.password,
        "x-clickhouse-database" => client.config.database,
    ]
    if use_compression
        push!(headers, "accept-encoding"  => content_encoding(compression))
        push!(headers, "content-encoding" => content_encoding(compression))
    end
    query = Dict{String,Any}(
        "query" => sql_query,
        "enable_http_compression" => use_compression ? "1" : "0",
        parameters_to_strings(parameters)...,
        (string(k) => v for (k, v) in options)...,
    )
    req = try
        http_request(
            client.curl_client,
            "POST",
            client.config.url,
            headers = headers,
            query = query,
            body = use_compression ? encode(compression, body) : body,
            ssl_verifyhost = client.config.verify_ssl,
            status_exception = false,
            accept_encoding = nothing,
        )
    catch e
        throw(e isa AbstractCurlError ? CHClientException(e.message) : e)
    end
    encoding = http_header(req, "content-encoding", nothing)
    iscompressed = use_compression && encoding == content_encoding(compression)
    body = iscompressed ? decode(compression, req.body) : req.body
    code = http_header(req, "x-clickhouse-exception-code", nothing)
    isnothing(code) || throw(CHServerException(code, body))
    check_and_throw_exception(body)
    return body
end

"""
    execute(client::HttpClient, query::String [, parameters::NamedTuple]; options...) -> Nothing

Sends a `query` to the database using the [`HttpClient`](@ref) `client`.
Values that need to be substituted into the `query` can be specified as `parameters` (see more in [Queries with parameters](https://clickhouse.com/docs/en/interfaces/cli#cli-queries-with-parameters)).

!!! info
    This type of request does not imply the return of any result (Fire and Forget).

## Keyword arguments
- `use_compression::Bool`: Flag for enabling data compression (default: `true`). See more in [`Content encoding`](@ref content_encoding) section.
- `max_execution_time::Int`: Maximum allowed execution time in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

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
    client::HttpClient,
    sql_query::String,
    parameters::NamedTuple = NamedTuple();
    use_compression::Bool = true,
    max_execution_time::Int = 60,
    options...,
)::Nothing
    _perform_query(
        client,
        sql_query,
        parameters = parameters,
        use_compression = use_compression,
        max_execution_time = max_execution_time,
        options...,
    )
    return nothing
end

"""
    insert(client::HttpClient, query::String, values::Vector; options...) -> Nothing

Sends a `query` to insert `values` into the database using the [`HttpClient`](@ref) `client`

!!! info
    This type of request does not imply the return of any result (Fire and Forget).

## Keyword arguments
- `chunk_size::Int`: Specifies the approximate size (in bytes) of one chunk of data being sent (default: `256 * 1024` bytes).
- `use_compression::Bool`: Flag for enabling data compression (default: `true`). See more in [`Content encoding`](@ref content_encoding) section.
- `max_execution_time::Int`: Maximum allowed execution time in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> insert(client, "INSERT INTO employees (name, age, position, salary)", [
    (name = "Alice", age = Int32(29), position = "Developer", salary = 75000.5),
    (name = "Bob", age = Int32(35), position = "Manager", salary = 92000.75),
    (name = "Clara", age = Int32(28), position = "Designer", salary = 68000.0),
    (name = "David", age = Int32(40), position = "Developer", salary = 81000.3),
])
```
"""
function insert(
    client::HttpClient,
    sql_query::String,
    values::Vector{T};
    chunk_size::Int = 256 * 1024,
    use_compression::Bool = true,
    max_execution_time::Int = 60,
    options...,
)::Nothing where {T}
    for batch in RowToBinaryIter(values, chunk_size)
        _perform_query(
            client,
            sql_query * " FORMAT RowBinary",
            body = batch,
            use_compression = use_compression,
            max_execution_time = max_execution_time,
            options...,
        )
    end
    return nothing
end

"""
    insert_binary(client::HttpClient, query::String, values::RowBinary; options...) -> RowBinary

Works similarly to the [`insert`](@ref) method, except that the sending data must be a [`RowBinary`](@ref) object.

!!! tip
    This method is effective when sending small portions of data frequently.
    Intended use in conjunction with [`query_binary`](@ref) for fast data transfer between databases.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> binary_data = query_binary(client, "SELECT * FROM employees")
RowBinary(107-bytes)

julia> insert_binary(client, "INSERT INTO another_employees", binary_data)
```
"""
function insert_binary(
    client::HttpClient,
    sql_query::String,
    values::T;
    use_compression::Bool = true,
    max_execution_time::Int = 60,
    options...,
)::Nothing where {T<:RowBinaryResult}
    _perform_query(
        client,
        sql_query * " FORMAT RowBinary",
        body = readavailable(values.s),
        use_compression = use_compression,
        max_execution_time = max_execution_time,
        options...,
    )
    return nothing
end

"""
    query(client::HttpClient, query::String [, parameters::NamedTuple]; options...) -> RowBinaryWithNamesAndTypes

Sends a `query` to the database using the [`HttpClient`](@ref) `client`.
Values that need to be substituted into the `query` can be specified as `parameters` (see more in [Queries with parameters](https://clickhouse.com/docs/en/interfaces/cli#cli-queries-with-parameters)).

!!! info
    This type of query involves returning the result from the database.
    The returned data is represented as a [`RowBinaryWithNamesAndTypes`](@ref) object.

## Keyword arguments
- `use_compression::Bool`: Flag for enabling data compression (default: `true`). See more in [`Content encoding`](@ref content_encoding) section.
- `max_execution_time::Int`: Maximum allowed execution time in seconds (default: `60` seconds).
- `options...`: Additional [options](https://clickhouse.com/docs/en/operations/settings/settings) passed to the query execution function.

See also [`eachrow`](@ref), [`collect`](@ref).

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> query(client, "SELECT * FROM employees")
RowBinaryWithNamesAndTypes(161-bytes):
 name::String
 age::Int32
 position::String
 salary::Float64
```
"""
function query(
    client::HttpClient,
    sql_query::String,
    parameters::NamedTuple = NamedTuple();
    use_compression::Bool = true,
    max_execution_time::Int = 60,
    options...,
)::RowBinaryWithNamesAndTypes
    query_result = _perform_query(
        client,
        sql_query * " FORMAT RowBinaryWithNamesAndTypes",
        parameters = parameters,
        use_compression = use_compression,
        max_execution_time = max_execution_time,
        options...,
    )
    return RowBinaryWithNamesAndTypes(query_result)
end

"""
    query_binary(client::HttpClient, query::String [, parameters::NamedTuple]; options...) -> RowBinary

Works similarly to the [`query`](@ref) method, except that the retrieved data is represented as a [`RowBinary`](@ref) object.

!!! tip
    This method is effective when requesting small portions of data frequently, since the response does not include information about names and data types.
    However, in this case, the user will be required to describe the column types and names themselves using his own type `T`.

See also [`eachrow`](@ref), [`collect`](@ref).

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> query_binary(client, "SELECT * FROM employees")
RowBinary(107-bytes)
```
"""
function query_binary(
    client::HttpClient,
    sql_query::String,
    parameters::NamedTuple = NamedTuple();
    use_compression::Bool = true,
    max_execution_time::Int = 60,
    options...,
)::RowBinary
    query_result = _perform_query(
        client,
        sql_query * " FORMAT RowBinary",
        parameters = parameters,
        use_compression = use_compression,
        max_execution_time = max_execution_time,
        options...,
    )
    return RowBinary(query_result)
end
