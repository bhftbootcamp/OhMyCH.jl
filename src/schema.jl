# Schema-driven (de)serialization: the server's column types drive the wire
# format, the user's Julia types are coerced on the way in and out.
#
# The `deserialize(s, ::Type)` / `serialize(s, ::Type, v)` family in
# serialization.jl works from Julia types alone and stays as it is — it is
# the only option when no schema is available (`RowBinary`). This file adds
# the same operations driven by a parsed `CHType`, which knows what a Julia
# type cannot: the precision of a `DateTime64`, the width of a `Decimal`,
# the size of a `FixedString`. Every schema-aware path of the client
# (`query`, `fetch_*`, `insert`, `Inserter`) goes through here.

"""
    coerce(::Type{T}, value) -> T

Converts a value read from (or about to be written to) ClickHouse into the
Julia type a user asked for. `convert` plus the conversions ClickHouse data
needs that Base does not define: `NanoDate` ↔ `DateTime`/`Date`, `Decimal`
→ any `Real`, `FixedString` → `String`, `Nullable` → `nothing` or `missing`
as the field type says.

A `NULL` arriving at a field that is not `Union{Nothing,T}` or
`Union{Missing,T}` throws `ArgumentError`.
"""
function coerce end

coerce(::Type{T}, v) where {T} = v isa T ? v : convert(T, v)

coerce(::Type{NanoDate}, v::Union{DateTime,Date}) = NanoDate(v)
coerce(::Type{DateTime}, v::NanoDate) = DateTime(v)
coerce(::Type{DateTime}, v::Date) = DateTime(v)
coerce(::Type{Date}, v::Union{DateTime,NanoDate}) = Date(v)
coerce(::Type{String}, v::AbstractString) = String(v)
coerce(::Type{T}, v::AbstractDecimal) where {T<:Real} = T(v)
coerce(::Type{T}, v::Real) where {T<:Decimal} = T(v)
coerce(::Type{T}, v::AbstractDecimal) where {T<:Decimal} = v isa T ? v : convert(T, v)

coerce(::Type{Union{Nothing,T}}, v) where {T} = v === nothing || v === missing ? nothing : coerce(T, v)
coerce(::Type{Union{Missing,T}}, v) where {T} = v === nothing || v === missing ? missing : coerce(T, v)
coerce(::Type{Union{Nothing,T}}, ::Nothing) where {T} = nothing
coerce(::Type{Union{Missing,T}}, ::Nothing) where {T} = missing
coerce(::Type{Union{Nothing,T}}, ::Missing) where {T} = nothing
coerce(::Type{Union{Missing,T}}, ::Missing) where {T} = missing
coerce(::Type{T}, ::Nothing) where {T} =
    throw(ArgumentError("NULL cannot be stored in a field of type $T; declare it as Union{Nothing,$T} or Union{Missing,$T}"))
coerce(::Type{T}, ::Missing) where {T} = coerce(T, nothing)

coerce(::Type{Vector{T}}, v::AbstractVector) where {T} = T[coerce(T, x) for x in v]
coerce(::Type{Dict{K,V}}, d::AbstractDict) where {K,V} = Dict{K,V}(coerce(K, k) => coerce(V, x) for (k, x) in d)
coerce(::Type{T}, v::Tuple) where {T<:Tuple} = T(ntuple(i -> coerce(fieldtype(T, i), v[i]), fieldcount(T)))

#__ reading by column type

"""
    deserialize(s::Serializer, t::CHType)

Reads one value whose ClickHouse type is `t`. Unlike `deserialize(s, ::Type)`,
a `DateTime64(P)` is scaled by its declared precision, so every instant is
exact — not only the ones a digit-count heuristic happens to get right.
"""
deserialize(s::Serializer, t::CHPrimitive) = deserialize(s, julia_type(t))
deserialize(s::Serializer, ::CHDateTime) = deserialize(s, DateTime)
deserialize(s::Serializer, t::CHFixedString) = read(s, FixedString{t.n})
deserialize(s::Serializer, t::CHDecimal) = read(s, Decimal{t.P,t.S})
deserialize(s::Serializer, ::CHEnum8) = read(s, UInt8)
deserialize(s::Serializer, ::CHEnum16) = read(s, UInt16)
deserialize(s::Serializer, t::CHLowCardinality) = deserialize(s, t.inner)
deserialize(s::Serializer, t::CHNullable) = read(s, UInt8) == 0x01 ? nothing : deserialize(s, t.inner)

function deserialize(s::Serializer, t::CHDateTime64)
    ticks = Int128(read(s, Int64))
    nanos = t.precision <= 9 ? ticks * Int128(10)^(9 - t.precision) : div(ticks, Int128(10)^(t.precision - 9))
    return unixnanos2nanodate(nanos)
end

function deserialize(s::Serializer, t::CHArray)
    n = read_leb128(s)
    out = Vector{julia_type(t.inner)}(undef, n)
    for i = 1:n
        out[i] = deserialize(s, t.inner)
    end
    return out
end

function deserialize(s::Serializer, t::CHMap)
    n = read_leb128(s)
    out = Dict{julia_type(t.key),julia_type(t.val)}()
    for _ = 1:n
        k = deserialize(s, t.key)
        out[k] = deserialize(s, t.val)
    end
    return out
end

deserialize(s::Serializer, t::CHTuple) = Tuple(deserialize(s, x) for x in t.inner)

#__ writing by column type

"""
    serialize(s::Serializer, t::CHType, value) -> Int

Writes `value` as the ClickHouse type `t`, coercing it first: an `Int` into
an `Int32` column, a `DateTime` into a `DateTime64(3)` column (scaled to its
precision), a `Float64` into a `Decimal(18, 8)`, `nothing` or `missing` into
a `Nullable`. Returns the number of bytes written.
"""
serialize(s::Serializer, t::CHPrimitive, v) = (T = julia_type(t); serialize(s, T, coerce(T, v)))
serialize(s::Serializer, ::CHDateTime, v) = serialize(s, DateTime, coerce(DateTime, v))
serialize(s::Serializer, t::CHFixedString, v) = write(s, v isa FixedString{t.n} ? v : FixedString{t.n}(String(v)))
serialize(s::Serializer, t::CHDecimal, v) = write(s, coerce(Decimal{t.P,t.S}, v))
serialize(s::Serializer, ::CHEnum8, v) = write(s, coerce(UInt8, v))
serialize(s::Serializer, ::CHEnum16, v) = write(s, coerce(UInt16, v))
serialize(s::Serializer, t::CHLowCardinality, v) = serialize(s, t.inner, v)

function serialize(s::Serializer, t::CHDateTime64, v)
    nanos = nanodate2unixnanos(coerce(NanoDate, v))
    ticks = t.precision <= 9 ? div(nanos, Int128(10)^(9 - t.precision)) : nanos * Int128(10)^(t.precision - 9)
    return write(s, Int64(ticks))
end

function serialize(s::Serializer, t::CHNullable, v)
    (v === nothing || v === missing) && return write(s, UInt8(0x01))
    return write(s, UInt8(0x00)) + serialize(s, t.inner, v)
end

function serialize(s::Serializer, t::CHArray, v::AbstractVector)
    n = write_leb128(s, length(v))
    for x in v
        n += serialize(s, t.inner, x)
    end
    return n
end

function serialize(s::Serializer, t::CHMap, d::AbstractDict)
    n = write_leb128(s, length(d))
    for (k, v) in d
        n += serialize(s, t.key, k)
        n += serialize(s, t.val, v)
    end
    return n
end

function serialize(s::Serializer, t::CHTuple, v::Tuple)
    length(v) == length(t.inner) ||
        throw(ArgumentError("tuple of $(length(v)) elements written as $(t): element count differs"))
    n = 0
    for (x, inner) in zip(v, t.inner)
        n += serialize(s, inner, x)
    end
    return n
end

#__ matching a row type to a set of columns

"""
    Column

One column of a table or a result: its name, its parsed type, and for a
table column its default kind (`""`, `"DEFAULT"`, `"MATERIALIZED"`,
`"ALIAS"`), as `DESCRIBE TABLE` reports it.
"""
struct Column
    name::String
    type::CHType
    default_kind::String
end

Column(name::AbstractString, type::CHType) = Column(String(name), type, "")

_quote_identifier(name::AbstractString) = "`" * replace(name, "`" => "\\`") * "`"

"""
    column_positions(::Type{T}, columns::Vector{Column}; what) -> Vector{Int}

For each field of the row type `T`, the index of the column that feeds it.
A struct or `NamedTuple` is matched by field name; a `Tuple` positionally.
Throws `ArgumentError` naming every field without a column, and the columns
that were available, so a typo in a field name is caught before any byte is
sent or decoded.
"""
function column_positions(::Type{T}, columns::Vector{Column}; what::AbstractString = "the result") where {T}
    names = fieldnames(T)
    if T <: Tuple || isempty(names)
        fieldcount(T) == length(columns) || throw(ArgumentError(
            "$T has $(fieldcount(T)) elements but $what has $(length(columns)) columns: $(join((c.name for c in columns), ", "))"))
        return collect(1:fieldcount(T))
    end
    index = Dict(c.name => i for (i, c) in enumerate(columns))
    positions = Int[]
    absent = String[]
    for name in names
        i = get(index, String(name), 0)
        i == 0 ? push!(absent, String(name)) : push!(positions, i)
    end
    isempty(absent) || throw(ArgumentError(
        "field$(length(absent) > 1 ? "s" : "") $(join(absent, ", ")) of $T not found in $what; columns: $(join((c.name for c in columns), ", "))"))
    return positions
end
