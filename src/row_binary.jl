"""
    RowBinaryResult

Abstract supertype for all row binary data results.

See also [`RowBinary`](@ref), [`RowBinaryWithNamesAndTypes`](@ref).
"""
abstract type RowBinaryResult end

"""
    RowBinary <: RowBinaryResult

This format represents binary rows of data, without specifying their types and names.
Data can be extracted using the [`eachrow`](@ref) or [`collect`](@ref) methods with the column types specified.

See more in [`ClickHouse Docs`](https://clickhouse.com/docs/en/sql-reference/formats#rowbinary).
"""
struct RowBinary <: RowBinaryResult
    s::Serializer

    function RowBinary(x::Vector{UInt8})
        return new(Serializer(x))
    end
end

Base.print(io::IO, x::RowBinary) = print(io, "RowBinary(", x.s.io.size, "-bytes)")
Base.show(io::IO, x::RowBinary) = print(io, x)

function ndeserialize(s::Serializer, T::Type, n::Integer)::Vector{T}
    items = Vector{T}(undef, n)
    for i = 1:n
        items[i] = deserialize(s, T)
    end
    return items
end

"""
    RowBinaryWithNamesAndTypes <: RowBinaryResult

This format represents binary rows of data containing information about column types and their names.
Supports direct iteration (`for row in result`), [`eachrow`](@ref), [`collect`](@ref), and the
[`Tables.jl`](https://github.com/JuliaTables/Tables.jl) interface (e.g. `DataFrame(result)`).

!!! note
    Results are streamed from an internal buffer and can only be iterated once.
    Use [`collect`](@ref) or [`fetch_all`](@ref) to materialize all rows if you need multiple passes.

See more in [`ClickHouse Docs`](https://clickhouse.com/docs/en/sql-reference/formats#rowbinarywithnamesandtypes).
"""
struct RowBinaryWithNamesAndTypes <: RowBinaryResult
    s::Serializer
    num_columns::UInt
    column_names::Vector{String}
    column_types::Vector{String}

    function RowBinaryWithNamesAndTypes(x::Vector{UInt8})
        s = Serializer(x)
        l = read_leb128(s)
        n = ndeserialize(s, String, l)
        t = ndeserialize(s, String, l)
        return new(s, l, n, t)
    end
end

Base.print(io::IO, x::RowBinaryWithNamesAndTypes) = print(io, "RowBinaryWithNamesAndTypes(", x.s.io.size, "-bytes)")

function Base.show(io::IO, x::RowBinaryWithNamesAndTypes)
    println(io, "RowBinaryWithNamesAndTypes(", x.s.io.size, "-bytes):")
    println(io, "Schema:")
    for (name, type) in zip(x.column_names, x.column_types)
        println(io, "  ", name, "::", type)
    end
end

"""
    RowToBinaryIter{T}

Iterator for converting rows into serialized binary data in chunks.

## Fields
- `items::AbstractVector{T}`: Collection of rows to be serialized.
- `chunk_size::Int`: Maximum size of serialized chunk in bytes.
- `serializer::Serializer`: Serializer used to encode rows.
- `current_start::Int`: Current position in the list of items.
- `items_per_chunk::Int`: Number of rows (items) included in a single chunk.
- `plan::Union{Nothing,Vector{Pair{Int,CHType}}}`: With a plan, field `i` of every
  row is written as the ClickHouse type the plan pairs it with (see
  [`insert_plan`](@ref)); without one, rows are written from their Julia types.
"""
mutable struct RowToBinaryIter{T}
    items::AbstractVector{T}
    chunk_size::Int
    serializer::Serializer
    current_start::Int
    items_per_chunk::Int
    plan::Union{Nothing,Vector{Pair{Int,CHType}}}

    function RowToBinaryIter(
        items::AbstractVector{T},
        chunk_size::Int;
        plan::Union{Nothing,Vector{Pair{Int,CHType}}} = nothing,
    ) where {T}
        items_per_chunk = _compute_items_per_chunk(items, chunk_size)
        obj = new{T}(items, chunk_size, Serializer(), 1, items_per_chunk, plan)
        finalizer(obj -> close(obj.serializer), obj)
        return obj
    end
end

Base.IteratorSize(::Type{<:RowToBinaryIter}) = Base.HasLength()
Base.eltype(::RowToBinaryIter{T}) where {T} = Vector{UInt8}

function Base.length(iter::RowToBinaryIter{T}) where {T}
    iter.items_per_chunk == 0 && return 0
    return ceil(Int, length(iter.items) / iter.items_per_chunk)
end

function _compute_items_per_chunk(items::AbstractVector, chunk_size::Int)
    len = length(items)
    len == 0 && return 0
    item_size = sizeof(items) / len
    return max(1, floor(Int, chunk_size / item_size))
end

function Base.iterate(iter::RowToBinaryIter{T}) where {T}
    if iter.current_start > length(iter.items)
        close(iter.serializer)
        return nothing
    end
    stop = min(iter.current_start + iter.items_per_chunk - 1, length(iter.items))
    pos_before = position(iter.serializer)
    for item in iter.items[iter.current_start:stop]
        serialize_row(iter.serializer, item, iter.plan)
    end
    pos_after = position(iter.serializer)
    seek(iter.serializer, pos_before)
    chunk = read(iter.serializer, pos_after - pos_before)
    iter.current_start = stop + 1
    return chunk, iter
end

function Base.iterate(iter::RowToBinaryIter, state)
    return Base.iterate(iter)
end

serialize_row(s::Serializer, item, ::Nothing) = serialize(s, item)

function serialize_row(s::Serializer, item, plan::AbstractVector{<:Pair{Int,<:CHType}})
    n = 0
    for (i, t) in plan
        n += serialize(s, t, getfield(item, i))
    end
    return n
end

"""
    BinaryToRowIter{F<:RowBinary, R}

Iterator over a [`RowBinary`](@ref) result — bytes without a schema — yielding
rows of type `R`, whose fields say what the bytes are. Carrying `R` as a type
parameter means `eltype` is concrete, so `collect(iter)` produces a
properly-typed `Vector{R}` rather than `Vector{Any}`.

Without a schema a `DateTime64` field (`NanoDate`) can only be decoded by
guessing its precision from the magnitude of the value, which is right for
instants after 2001-09-09 (nanoseconds) or between 2001 and 2286
(milliseconds). A [`RowBinaryWithNamesAndTypes`](@ref) result knows the
precision and decodes every instant exactly — prefer [`query`](@ref) over
[`query_binary`](@ref) for `DateTime64` columns.

## Fields
- `row_type::Type{R}`: Data type whose fields define row cell types.
- `binary::RowBinary`: Binary format containing the serialized data.
- `column_names::NTuple{N,Symbol}`: Column names.
- `column_types::NTuple{N,Type}`: Column types.
"""
struct BinaryToRowIter{F<:RowBinary, R}
    row_type::Type{R}
    binary::RowBinary
    column_names::NTuple{N,Symbol} where {N}
    column_types::NTuple{N,Type} where {N}
end

Base.IteratorSize(::Type{<:BinaryToRowIter}) = Base.SizeUnknown()
Base.eltype(::Type{<:BinaryToRowIter{F, R}}) where {F, R} = R
Base.eltype(iter::BinaryToRowIter) = iter.row_type
Base.eof(iter::BinaryToRowIter) = eof(iter.binary.s)

function deserialize_iter(iter::BinaryToRowIter)
    return (deserialize(iter.binary.s, t) for t in iter.column_types)
end

"""
    SchemaRowIter{R}

Iterator over a [`RowBinaryWithNamesAndTypes`](@ref) result yielding rows of
type `R`. The result's own schema drives decoding: every column is read as
the ClickHouse type the server declared (a `DateTime64(3)` is scaled by 3,
a `Decimal(18, 8)` is 18 digits wide), then handed to the field of `R` that
names it, coerced to the field's type ([`coerce`](@ref)). Columns no field
asks for are read and dropped.

With `R` a `NamedTuple` built from the schema (what [`eachrow`](@ref) and
[`collect`](@ref) do), names and types are the result's own. With a user's
`R`, fields are matched to columns by name — a struct or `NamedTuple` — or
by position — a `Tuple` — and a field without a column is an `ArgumentError`
before the first row is read.

## Fields
- `binary::RowBinaryWithNamesAndTypes`: the result being read.
- `columns::Vector{Column}`: the result's schema, in wire order.
- `positions::Vector{Int}`: for each field of `R`, the index of its column.
"""
struct SchemaRowIter{R}
    binary::RowBinaryWithNamesAndTypes
    columns::Vector{Column}
    positions::Vector{Int}
end

Base.IteratorSize(::Type{<:SchemaRowIter}) = Base.SizeUnknown()
Base.eltype(::Type{SchemaRowIter{R}}) where {R} = R
Base.eof(iter::SchemaRowIter) = eof(iter.binary.s)

result_columns(b::RowBinaryWithNamesAndTypes) =
    Column[Column(n, parse_ch_type(t)) for (n, t) in zip(b.column_names, b.column_types)]

function SchemaRowIter(b::RowBinaryWithNamesAndTypes)
    columns = result_columns(b)
    names = Tuple(Symbol(c.name) for c in columns)
    R = NamedTuple{names, Tuple{(julia_type(c.type) for c in columns)...}}
    return SchemaRowIter{R}(b, columns, collect(1:length(columns)))
end

function SchemaRowIter(::Type{T}, b::RowBinaryWithNamesAndTypes) where {T}
    columns = result_columns(b)
    return SchemaRowIter{T}(b, columns, column_positions(T, columns))
end

function Base.iterate(iter::SchemaRowIter{R}, eof_state::Bool = eof(iter)) where {R}
    eof_state && return nothing
    s = iter.binary.s
    values = Vector{Any}(undef, length(iter.columns))
    for (j, c) in enumerate(iter.columns)
        values[j] = deserialize(s, c.type)
    end
    fields = ntuple(i -> field_value(R, i, iter.columns[iter.positions[i]], values[iter.positions[i]]), fieldcount(R))
    row = R <: Union{NamedTuple,Tuple} ? R(fields) : R(fields...)
    return (row, eof(iter))
end

function field_value(::Type{R}, i::Int, column::Column, v) where {R}
    F = fieldtype(R, i)
    try
        return coerce(F, v)
    catch e
        e isa ArgumentError && rethrow()
        throw(ArgumentError("column $(column.name) ($(column.type)) cannot be read into field $(fieldname(R, i))::$F of $R: $(sprint(showerror, e))"))
    end
end

"""
    iterate(result::RowBinaryWithNamesAndTypes)

Enables direct iteration over query results without needing [`eachrow`](@ref).

## Examples

```julia-repl
julia> result = query(client, "SELECT * FROM employees")

julia> for row in result
           println(row.name, ": ", row.salary)
       end
Alice: 75000.5
Bob: 92000.75
```
"""
function Base.iterate(b::RowBinaryWithNamesAndTypes)
    iter = SchemaRowIter(b)
    result = iterate(iter)
    result === nothing && return nothing
    return (result[1], iter)
end

function Base.iterate(::RowBinaryWithNamesAndTypes, iter::SchemaRowIter)
    result = iterate(iter, eof(iter))
    result === nothing && return nothing
    return (result[1], iter)
end

Base.IteratorSize(::Type{RowBinaryWithNamesAndTypes}) = Base.SizeUnknown()
Base.eltype(::Type{RowBinaryWithNamesAndTypes}) = NamedTuple

"""
    eachrow(binary::RowBinaryWithNamesAndTypes) -> SchemaRowIter

Creates a new iterator [`SchemaRowIter`](@ref) that determines column types and their names from `binary` object.
The elements of such an iterator are `NamedTuple` objects.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> employees = query(client, "SELECT * FROM employees");

julia> for user in eachrow(employees)
           println(user)
       end
(name = "Alice", age = 29, position = "Developer", salary = 75000.5)
(name = "Bob", age = 35, position = "Manager", salary = 92000.75)
```
"""
Base.eachrow(::RowBinaryWithNamesAndTypes)

function Base.eachrow(::RowBinary)
    error("To iterate over `RowBinary`, you must specify a type `T` that contains information about the column types.\nPlease use the `eachrow(::Type{T}, ::RowBinary)` method instead.")
end

function Base.eachrow(b::RowBinaryWithNamesAndTypes)
    return SchemaRowIter(b)
end

"""
    collect(binary::RowBinaryWithNamesAndTypes) -> Vector{NamedTuple}
    collect(::Type{T}, binary::RowBinaryResult) -> Vector{T}

Works similarly to the [`eachrow`](@ref) method, but instead of creating an iterator, it returns all values from the `binary` representation of the data.

!!! warning
    If you don't need all the values at once, it's preferable to iterate over the rows using the [`eachrow`](@ref) method or direct iteration (`for row in result`).

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> employees = query(client, "SELECT * FROM employees");

julia> collect(employees)
4-element Vector{NamedTuple{(:name, :age, :position, :salary), Tuple{String,Int32,String,Float64}}}:
 (name = "Alice", age = 29, position = "Developer", salary = 75000.5)
 (name = "Bob", age = 35, position = "Manager", salary = 92000.75)
 (name = "Clara", age = 28, position = "Designer", salary = 68000.0)
 (name = "David", age = 40, position = "Developer", salary = 81000.3)
```
"""
Base.collect(::RowBinaryWithNamesAndTypes)

function Base.collect(b::RowBinaryWithNamesAndTypes)
    return collect(SchemaRowIter(b))
end

function BinaryToRowIter(::Type{T}, b::F) where {T, F<:RowBinary}
    return BinaryToRowIter{F, T}(T, b, fieldnames(T), fieldtypes(T))
end

function Base.iterate(iter::BinaryToRowIter{RowBinary}, eof_state::Bool = eof(iter))
    eof_state && return nothing
    values = deserialize_iter(iter)
    return (iter.row_type(values...), eof(iter))
end

"""
    eachrow(::Type{T}, binary::RowBinaryResult)

Creates an iterator whose elements are objects of type `T`. Over a
[`RowBinaryWithNamesAndTypes`](@ref) result that is a [`SchemaRowIter`](@ref):
columns are decoded by the result's schema and matched to the fields of `T`
by name (a struct or `NamedTuple`) or by position (a `Tuple`), each value
coerced to its field's type — `SELECT b, a` fills `struct Row; a; b; end`
correctly, an `Int32` column fills an `Int` field, a `Decimal` a `Float64`,
a `DateTime64` a `DateTime`, a `Nullable` a `Union{Missing,T}`. Over a
[`RowBinary`](@ref) result that is a [`BinaryToRowIter`](@ref): the fields of
`T` alone say what the bytes are.

## Examples

```julia-repl
julia> client = connect("http://127.0.0.1:8123")

julia> employees = query_binary(client, "SELECT * FROM employees");

julia> struct Employee
           name::String
           age::Int32
           position::String
           salary::Float64
       end

julia> for employee in eachrow(Employee, employees)
           println(employee)
       end
Employee("Alice", 29, "Developer", 75000.5)
Employee("Bob", 35, "Manager", 92000.75)
```
"""
Base.eachrow(::Type, ::RowBinaryResult)

function Base.eachrow(::Type{T}, b::RowBinary) where {T}
    return BinaryToRowIter(T, b)
end

function Base.eachrow(::Type{T}, b::RowBinaryWithNamesAndTypes) where {T}
    return SchemaRowIter(T, b)
end

function Base.collect(::Type{T}, b::RowBinaryResult) where {T}
    return collect(eachrow(T, b))
end
