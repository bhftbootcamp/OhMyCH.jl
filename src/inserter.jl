"""
    InsertStats

Statistics returned by [`commit!`](@ref), [`flush!`](@ref), and [`close`](@ref) on an [`Inserter`](@ref).

## Fields
- `rows::Int`: Number of rows flushed.
- `bytes::Int`: Total body bytes sent across all `RowBinary` chunks of the flushed batch.
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
any of the configured thresholds (`max_rows`, `max_bytes`, `period`) is reached.

When `period` is set, a background `Timer` performs time-based flushes even if
the producer is idle, so latency is bounded. All buffer mutations are serialized
through an internal `ReentrantLock`, so `Inserter` is safe to use from multiple
tasks (e.g. one task feeding rows while a Timer task flushes them).

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
mutable struct Inserter{T, K<:NamedTuple}
    client::CHClient
    table::String
    sql::String
    buffer::Vector{T}
    serializer::Serializer
    avg_row_bytes::Float64
    max_rows::Int
    max_bytes::Int
    period_seconds::Float64
    last_commit_time::Float64
    stats::InsertStats
    closed::Bool
    errored::Bool
    kw::K
    lock::ReentrantLock
    timer::Union{Timer, Nothing}
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
- `period::Union{Real, Dates.TimePeriod, Nothing}`: Flush after this time interval since the last commit (default: `nothing` = no limit). When set, a background `Timer` polls at this interval so idle streams still flush on time.
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
    period_s = _to_seconds(period)
    nt = NamedTuple(kw)
    ins = Inserter{T, typeof(nt)}(
        client,
        String(table),
        _build_insert_sql(table),
        T[],
        Serializer(),
        0.0,
        Int(max_rows),
        Int(max_bytes),
        period_s,
        time(),
        InsertStats(0, 0, 0),
        false,
        false,
        nt,
        ReentrantLock(),
        nothing,
    )
    if period_s > 0
        wref = WeakRef(ins)
        ins.timer = Timer(period_s; interval = period_s) do t
            strong = wref.value
            if strong === nothing
                try
                    Base.close(t)
                catch
                end
                return
            end
            _timer_tick(strong::Inserter)
        end
    end
    finalizer(_finalize, ins)
    return ins
end

function _finalize(ins::Inserter)
    # Closing a `Timer` and emitting `@warn` both task-switch (libuv handle
    # teardown and the global logger lock respectively), which is forbidden
    # from inside a GC finalizer. Capture the values we need and defer
    # everything to a fresh task so the finalizer itself stays GC-safe.
    t = ins.timer
    has_unflushed = !ins.closed && !ins.errored && !isempty(ins.buffer)
    n = has_unflushed ? length(ins.buffer) : 0
    table = ins.table
    ins.timer = nothing
    if t !== nothing || has_unflushed
        Base.errormonitor(@async begin
            if t !== nothing
                try
                    Base.close(t)
                catch
                end
            end
            if has_unflushed
                @warn "Inserter for table `$table` was garbage-collected with $n unflushed row(s); data was lost. Call `close(ins)` or use the `inserter(...) do ... end` form."
            end
        end)
    end
    return nothing
end

function _timer_tick(ins::Inserter)
    try
        lock(ins.lock) do
            (ins.closed || isempty(ins.buffer)) && return
            (time() - ins.last_commit_time) < ins.period_seconds && return
            _flush_locked(ins)
        end
    catch e
        e isa InterruptException && rethrow()
        @warn "Inserter period-flush failed" exception=(e, catch_backtrace())
    end
    return nothing
end

function _estimate_bytes(ins::Inserter)
    n = length(ins.buffer)
    n == 0 && return 0
    if ins.avg_row_bytes <= 0.0
        sample_n = min(n, 10)
        seekstart(ins.serializer)
        for i in 1:sample_n
            serialize(ins.serializer, ins.buffer[i])
        end
        ins.avg_row_bytes = Float64(position(ins.serializer)) / sample_n
    end
    return round(Int, n * ins.avg_row_bytes)
end

"""
    write(inserter::Inserter{T}, row)

Add a `row` to the inserter's internal buffer. The row is `convert`ed to `T`, so any value with a defined conversion to `T` may be passed.
"""
function Base.write(ins::Inserter{T}, row) where {T}
    lock(ins.lock) do
        ins.closed && throw(ArgumentError("Inserter is closed"))
        push!(ins.buffer, convert(T, row))
    end
    return nothing
end

function _flush_locked(ins::Inserter)
    n = length(ins.buffer)
    if n == 0
        ins.last_commit_time = time()
        return InsertStats(0, 0, 0)
    end
    try
        bytes = _chunked_insert!(ins.client, ins.sql, ins.buffer; ins.kw...)
        flush_stats = InsertStats(n, bytes, 1)
        ins.stats = ins.stats + flush_stats
        ins.avg_row_bytes = Float64(bytes) / n
        return flush_stats
    finally
        empty!(ins.buffer)
        ins.last_commit_time = time()
    end
end

"""
    flush!(inserter::Inserter) -> InsertStats

Force-flush all buffered rows to ClickHouse, regardless of thresholds.
Returns statistics for this flush operation.
"""
function flush!(ins::Inserter)
    return lock(ins.lock) do
        ins.closed && throw(ArgumentError("Inserter is closed"))
        _flush_locked(ins)
    end
end

"""
    commit!(inserter::Inserter) -> InsertStats

Conditionally flush: only performs an actual flush if any of the configured
thresholds (max_rows, max_bytes, period) have been reached.
Returns statistics for the flush if it happened, or zero stats otherwise.
"""
function commit!(ins::Inserter)
    return lock(ins.lock) do
        ins.closed && throw(ArgumentError("Inserter is closed"))
        should_flush =
            (ins.max_rows > 0 && length(ins.buffer) >= ins.max_rows) ||
            (ins.max_bytes > 0 && _estimate_bytes(ins) >= ins.max_bytes) ||
            (ins.period_seconds > 0 && (time() - ins.last_commit_time) >= ins.period_seconds)
        return should_flush ? _flush_locked(ins) : InsertStats(0, 0, 0)
    end
end

"""
    close(inserter::Inserter) -> InsertStats

Stop the background timer (if any), flush any remaining buffered rows, and close
the inserter. If `errored` has been set (see [`inserter`](@ref) do-block semantics),
the remaining buffer is discarded instead of flushed.

Returns cumulative statistics for all flushes performed by this inserter.
"""
function Base.close(ins::Inserter)
    return lock(ins.lock) do
        ins.closed && return ins.stats
        if ins.timer !== nothing
            Base.close(ins.timer)
            ins.timer = nothing
        end
        if ins.errored
            empty!(ins.buffer)
        elseif !isempty(ins.buffer)
            _flush_locked(ins)
        end
        Base.close(ins.serializer)
        ins.closed = true
        return ins.stats
    end
end

"""
    inserter(f::Function, client::CHClient, table::AbstractString, ::Type{T}; kw...) where {T}

Do-block pattern for [`Inserter`](@ref). Creates an inserter, passes it to `f`, and ensures it is closed when `f` returns or throws.

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
    catch
        lock(ins.lock) do
            ins.errored = true
        end
        close(ins)
        rethrow()
    end
    close(ins)
    return ins.stats
end
