"""
    InsertStats

Statistics returned by [`commit!`](@ref), [`flush!`](@ref), and [`close`](@ref) on an [`Inserter`](@ref).

## Fields
- `rows::Int`: Number of rows flushed.
- `bytes::Int`: Approximate number of bytes flushed.
- `transactions::Int`: Number of insert transactions performed.
"""
struct InsertStats
    rows::Int
    bytes::Int
    transactions::Int
end

Base.:+(a::InsertStats, b::InsertStats) = InsertStats(a.rows + b.rows, a.bytes + b.bytes, a.transactions + b.transactions)

function Base.show(io::IO, s::InsertStats)
    print(io, "InsertStats(rows=$(s.rows), bytes=$(s.bytes), transactions=$(s.transactions))")
end

"""
    Inserter{T}

Buffered inserter for streaming inserts with auto-commit thresholds.
Rows are accumulated in an internal buffer and flushed to ClickHouse when
any of the configured thresholds (max_rows, max_bytes, period) is reached.

Use `write` to add rows, [`commit!`](@ref) to conditionally flush,
[`flush!`](@ref) to force flush, and `close` to finalize.

## Examples

```julia-repl
julia> struct Event
           ts::Int64
           value::Float64
       end

julia> client = connect("http://127.0.0.1:8123")

julia> inserter(client, "events", Event; max_rows=1000) do ins
           for i in 1:5000
               write(ins, Event(Int64(i), Float64(i) * 0.1))
               commit!(ins)
           end
       end
InsertStats(rows=5000, bytes=..., transactions=5)
```
"""
mutable struct Inserter{T}
    client::CHClient
    table::String
    buffer::Vector{T}
    serializer::Serializer
    avg_row_bytes::Float64
    max_rows::Int
    max_bytes::Int
    period_seconds::Float64
    last_commit_time::Float64
    stats::InsertStats
    closed::Bool
    kw::Any
end

_to_seconds(::Nothing) = 0.0
_to_seconds(period::Real) = Float64(period)
_to_seconds(period::Dates.TimePeriod) = Dates.value(Dates.Millisecond(period)) / 1000.0

"""
    Inserter{T}(client::CHClient, table::AbstractString; max_rows, max_bytes, period, kw...)

Create an [`Inserter`](@ref) that buffers rows of type `T` for insertion into `table`.

## Keyword arguments
- `max_rows::Integer`: Flush when buffer reaches this many rows (default: `0` = no limit).
- `max_bytes::Integer`: Flush when estimated buffer size reaches this many bytes (default: `0` = no limit).
- `period::Union{Real, Dates.TimePeriod, Nothing}`: Flush after this time interval since the last commit (default: `nothing` = no limit).
- `kw...`: Additional keyword arguments passed through to [`insert`](@ref).
"""
function Inserter{T}(
    client::CHClient,
    table::AbstractString;
    max_rows::Integer = 0,
    max_bytes::Integer = 0,
    period::Union{Real, Dates.TimePeriod, Nothing} = nothing,
    kw...,
) where {T}
    return Inserter{T}(
        client,
        String(table),
        T[],
        Serializer(),
        0.0,
        Int(max_rows),
        Int(max_bytes),
        _to_seconds(period),
        time(),
        InsertStats(0, 0, 0),
        false,
        kw,
    )
end

function _estimate_bytes(ins::Inserter{T}) where {T}
    n = length(ins.buffer)
    n == 0 && return 0
    if ins.avg_row_bytes <= 0.0
        seekstart(ins.serializer)
        serialize(ins.serializer, first(ins.buffer))
        ins.avg_row_bytes = Float64(position(ins.serializer))
    end
    return round(Int, n * ins.avg_row_bytes)
end

"""
    write(inserter::Inserter{T}, row::T)

Add a `row` to the inserter's internal buffer.
"""
function Base.write(ins::Inserter{T}, row::T) where {T}
    ins.closed && throw(ArgumentError("Inserter is closed"))
    push!(ins.buffer, row)
    return nothing
end

"""
    flush!(inserter::Inserter) -> InsertStats

Force-flush all buffered rows to ClickHouse, regardless of thresholds.
Returns statistics for this flush operation.
"""
function flush!(ins::Inserter)
    ins.closed && throw(ArgumentError("Inserter is closed"))
    n = length(ins.buffer)
    n == 0 && return InsertStats(0, 0, 0)
    bytes = _estimate_bytes(ins)
    insert(ins.client, ins.table, ins.buffer; ins.kw...)
    empty!(ins.buffer)
    ins.avg_row_bytes = 0.0
    ins.last_commit_time = time()
    flush_stats = InsertStats(n, bytes, 1)
    ins.stats = ins.stats + flush_stats
    return flush_stats
end

"""
    commit!(inserter::Inserter) -> InsertStats

Conditionally flush: only performs an actual flush if any of the configured
thresholds (max_rows, max_bytes, period) have been reached.
Returns statistics for the flush if it happened, or zero stats otherwise.
"""
function commit!(ins::Inserter)
    ins.closed && throw(ArgumentError("Inserter is closed"))
    should_flush = false
    should_flush |= ins.max_rows > 0 && length(ins.buffer) >= ins.max_rows
    should_flush |= ins.max_bytes > 0 && _estimate_bytes(ins) >= ins.max_bytes
    should_flush |= ins.period_seconds > 0 && (time() - ins.last_commit_time) >= ins.period_seconds
    return should_flush ? flush!(ins) : InsertStats(0, 0, 0)
end

"""
    close(inserter::Inserter) -> InsertStats

Flush any remaining buffered rows and close the inserter.
Returns cumulative statistics for all flushes performed by this inserter.
"""
function Base.close(ins::Inserter)
    ins.closed && return ins.stats
    isempty(ins.buffer) || flush!(ins)
    close(ins.serializer)
    ins.closed = true
    return ins.stats
end

"""
    inserter(f::Function, client::CHClient, table::AbstractString, ::Type{T}; kw...) where {T}

Do-block pattern for [`Inserter`](@ref). Creates an inserter, passes it to `f`, and
ensures it is closed (with a final flush) when `f` returns or throws.

Returns cumulative [`InsertStats`](@ref).

## Examples

```julia-repl
julia> struct Event
           id::Int64
           value::Float64
       end

julia> client = connect("http://127.0.0.1:8123")

julia> inserter(client, "events", Event; max_rows=500) do ins
           for i in 1:1000
               write(ins, Event(Int64(i), Float64(i)))
               commit!(ins)
           end
       end
InsertStats(rows=1000, bytes=..., transactions=2)
```
"""
function inserter(f::Function, client::CHClient, table::AbstractString, ::Type{T}; kw...) where {T}
    ins = Inserter{T}(client, table; kw...)
    try
        f(ins)
    finally
        close(ins)
    end
    return ins.stats
end
