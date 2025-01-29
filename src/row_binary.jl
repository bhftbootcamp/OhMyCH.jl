#__ row_binary

"""
    RowBinaryResult

Abstract supertype for all row binary data results.

This type is a base for binary data representations, such as `RowBinary`
and `RowBinaryWithNamesAndTypes`.

## See Also
- [`RowBinary`](@ref)
- [`RowBinaryWithNamesAndTypes`](@ref)
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
Data can be extracted using the [`eachrow`](@ref) or [`collect`](@ref) methods.

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
function Base.show(io::IO, x::OhMyCH.RowBinaryWithNamesAndTypes)
    println(io, "RowBinaryWithNamesAndTypes(", x.s.io.size, "-bytes):")
    println(io, "Schema:")
    for (name, type) in zip(x.column_names, x.column_types)
        println(io, "  ", name, "::", type)
    end
end

#__ row_to_binary_iter

"""
    RowToBinaryIter{T}

Iterator for converting rows into serialized binary data in chunks.

## Fields
- `items::AbstractVector{T}`: Collection of rows to be serialized.
- `chunk_size::Int`: Maximum size of serialized chunk in bytes.
- `serializer::Serializer`: Serializer used to encode rows.
- `current_start::Int`: Current position in the list of items.
- `items_per_chunk::Int`: Number of rows (items) included in a single chunk.
"""
mutable struct RowToBinaryIter{T}
    items::AbstractVector{T}
    chunk_size::Int
    serializer::Serializer
    current_start::Int
    items_per_chunk::Int

    function RowToBinaryIter(
        items::AbstractVector{T},
        chunk_size::Int,
    ) where {T}
        items_per_chunk = _compute_items_per_chunk(items, chunk_size)
        obj = new{T}(items, chunk_size, Serializer(), 1, items_per_chunk)
        finalizer(obj -> close(obj.serializer), obj)
        return obj
    end
end

Base.IteratorSize(::Type{<:RowToBinaryIter}) = Base.HasLength()
Base.eltype(::RowToBinaryIter{T}) where {T} = Vector{UInt8}
Base.length(iter::RowToBinaryIter{T}) where {T} = ceil(Int, length(iter.items) / iter.items_per_chunk)

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
        serialize(iter.serializer, item)
    end
    pos_after = position(iter.serializer)
    seek(iter.serializer, pos_before)
    chunk = read(iter.serializer, pos_after - pos_before)
    iter.current_start = stop + 1
    return chunk, iter
end

function Base.iterate(iter::RowToBinaryIter{T}, state) where {T}
    return Base.iterate(iter)
end

#__ binary_to_row_iter

"""
    BinaryToRowIter{F<:RowBinaryResult}

Iterator for row data in format `F` (See [supported formats](@ref supported_formats)).

## Fields
- `row_type::Type`: Data type whose fields define row cell types.
- `binary::F`: Binary format containing the serialized data.
- `column_names::NTuple{N,Symbol}`: Column names.
- `column_types::NTuple{N,Type}`: Column types.
"""
struct BinaryToRowIter{F<:RowBinaryResult}
    row_type::Type
    binary::RowBinaryResult
    column_names::NTuple{N,Symbol} where {N}
    column_types::NTuple{N,Type} where {N}
end

Base.IteratorSize(::Type{<:BinaryToRowIter}) = Base.SizeUnknown()
Base.eltype(iter::BinaryToRowIter) = iter.row_type
Base.eof(iter::BinaryToRowIter) = eof(iter.binary.s)

function deserialize_iter(iter::BinaryToRowIter)
    return (deserialize(iter.binary.s, t) for t in iter.column_types)
end

function BinaryToRowIter(b::F) where {F<:RowBinaryWithNamesAndTypes}
    column_names = Tuple(Symbol.(b.column_names))
    column_types = Tuple(parse_column_type.(b.column_types))
    row_type = NamedTuple{column_names,Tuple{column_types...}}
    return BinaryToRowIter{F}(row_type, b, column_names, column_types)
end

function Base.iterate(iter::BinaryToRowIter{RowBinaryWithNamesAndTypes}, eof_state::Bool = eof(iter))
    eof_state && return nothing
    values = deserialize_iter(iter)
    return (iter.row_type(values), eof(iter))
end

"""
    eachrow(binary::RowBinaryWithNamesAndTypes) -> BinaryToRowIter

Creates a new iterator [`BinaryToRowIter`](@ref) that determines column types and their names from `binary` object.
The elements of such an iterator are `NamedTuple` objects.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> employees = query(client, "SELECT * FROM employees");

julia> for user in eachrow(employees)
           println(user)
       end
(name = "Alice", age = 29, position = "Developer", salary = 75000.5)
(name = "Bob", age = 35, position = "Manager", salary = 92000.75)
(name = "Clara", age = 28, position = "Designer", salary = 68000.0)
(name = "David", age = 40, position = "Developer", salary = 81000.3)
```
"""
Base.eachrow(::RowBinaryWithNamesAndTypes)

function Base.eachrow(::RowBinary)
    error("To iterate over `RowBinary`, you must specify a type `T` that contains information about the column types.\nPlease use the `eachrow(::Type{T}, ::RowBinary)` method instead.")
end

function Base.eachrow(b::RowBinaryWithNamesAndTypes)
    return BinaryToRowIter(b)
end

"""
    collect(binary::RowBinaryWithNamesAndTypes) -> Vector{NamedTuple}
    collect(::Type{T}, binary::RowBinaryResult) -> Vector{T}

Works similarly to the [`eachrow`](@ref) method, but instead of creating an iterator, it returns all values from the `binary` representation of the data.

!!! warning
    If you don't need all the values at once, it's preferable to iterate over the rows using the [`eachrow`](@ref) method.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

julia> employees = query(client, "SELECT * FROM employees");

julia> collect(employees)
4-element Vector{NamedTuple{(:name, :age, :position, :salary), Tuple{String,Int32,String,Float64}}}:
 (name = "Alice", age = 29, position = "Developer", salary = 75000.5)
 (name = "Bob", age = 35, position = "Manager", salary = 92000.75)
 (name = "Clara", age = 28, position = "Designer", salary = 68000.0)
 (name = "David", age = 40, position = "Developer", salary = 81000.3)
```
"""
Base.collect(::RowBinaryResult)

function Base.collect(b::RowBinaryResult)
    return collect(BinaryToRowIter(b))
end

function BinaryToRowIter(t::Type, b::F) where {F<:RowBinary}
    return BinaryToRowIter{F}(t, b, fieldnames(t), fieldtypes(t))
end

function BinaryToRowIter(t::Type, b::F) where {F<:RowBinaryWithNamesAndTypes}
    ft = fieldtypes(t)
    st = Tuple(parse_column_type.(b.column_types))
    @assert ft == st "Type mismatch for $(string(t)). Expected: $st, Got: $ft. Ensure the structure matches the schema."
    return BinaryToRowIter{RowBinary}(t, b, fieldnames(t), ft)
end

function Base.iterate(iter::BinaryToRowIter{RowBinary}, eof_state::Bool = eof(iter))
    eof_state && return nothing
    values = deserialize_iter(iter)
    return (iter.row_type(values...), eof(iter))
end

"""
    eachrow(::Type{T}, binary::RowBinaryResult) -> BinaryToRowIter

Creates a new iterator [`BinaryToRowIter`](@ref) that uses fields of type `T` to determine column types.
The elements of such an iterator are objects of type `T`.

## Examples

```julia-repl
julia> client = ohmych_connect("http://127.0.0.1:8123", "database", "username", "password");

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
Employee("Clara", 28, "Designer", 68000.0)
Employee("David", 40, "Developer", 81000.3)
```
"""
Base.eachrow(::Type, ::RowBinaryResult)

function Base.eachrow(::Type{T}, b::RowBinary) where {T}
    return BinaryToRowIter(T, b)
end

function Base.eachrow(::Type{T}, b::RowBinaryWithNamesAndTypes) where {T}
    return BinaryToRowIter(T, b)
end

function Base.collect(::Type{T}, b::RowBinaryResult) where {T}
    return collect(BinaryToRowIter(T, b))
end
