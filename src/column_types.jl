"""
    CHType

Abstract supertype for parsed ClickHouse column types.
Recursive tree preserving all type metadata (precision, scale, timezone, etc.).
"""
abstract type CHType end

struct CHPrimitive <: CHType
    name::Symbol
end

struct CHDateTime <: CHType
    tz::Union{String,Nothing}
end

struct CHDateTime64 <: CHType
    precision::Int
    tz::Union{String,Nothing}
end

struct CHFixedString <: CHType
    n::Int
end

struct CHDecimal <: CHType
    P::Int
    S::Int
end

struct CHEnum8 <: CHType end
struct CHEnum16 <: CHType end

struct CHNullable <: CHType
    inner::CHType
end

struct CHLowCardinality <: CHType
    inner::CHType
end

struct CHArray <: CHType
    inner::CHType
end

struct CHTuple <: CHType
    inner::Vector{CHType}
end

struct CHMap <: CHType
    key::CHType
    val::CHType
end

Base.show(io::IO, x::CHPrimitive)      = print(io, x.name)
Base.show(io::IO, x::CHFixedString)    = print(io, "FixedString(", x.n, ")")
Base.show(io::IO, x::CHDecimal)        = print(io, "Decimal(", x.P, ", ", x.S, ")")
Base.show(io::IO, ::CHEnum8)           = print(io, "Enum8")
Base.show(io::IO, ::CHEnum16)          = print(io, "Enum16")
Base.show(io::IO, x::CHNullable)       = print(io, "Nullable(", x.inner, ")")
Base.show(io::IO, x::CHLowCardinality) = print(io, "LowCardinality(", x.inner, ")")
Base.show(io::IO, x::CHArray)          = print(io, "Array(", x.inner, ")")
Base.show(io::IO, x::CHMap)            = print(io, "Map(", x.key, ", ", x.val, ")")

function Base.show(io::IO, x::CHDateTime)
    print(io, "DateTime")
    x.tz !== nothing && print(io, "('", x.tz, "')")
end

function Base.show(io::IO, x::CHDateTime64)
    print(io, "DateTime64(", x.precision)
    x.tz !== nothing && print(io, ", '", x.tz, "'")
    print(io, ")")
end

function Base.show(io::IO, x::CHTuple)
    print(io, "Tuple(")
    join(io, x.inner, ", ")
    print(io, ")")
end

const _CH_PRIMITIVES = Dict(s => CHPrimitive(Symbol(s)) for s in (
    "Bool", "UInt8", "UInt16", "UInt32", "UInt64", "UInt128",
    "Int8", "Int16", "Int32", "Int64", "Int128",
    "Float32", "Float64", "String", "Date", "UUID", "IPv4", "IPv6",
))

const _JL_PRIMITIVES = Dict{Symbol,Type}(
    :Bool => Bool, :UInt8 => UInt8, :UInt16 => UInt16, :UInt32 => UInt32,
    :UInt64 => UInt64, :UInt128 => UInt128,
    :Int8 => Int8, :Int16 => Int16, :Int32 => Int32,
    :Int64 => Int64, :Int128 => Int128,
    :Float32 => Float32, :Float64 => Float64,
    :String => String, :Date => Date,
    :UUID => UUID, :IPv4 => IPv4, :IPv6 => IPv6,
)

_strip_tz(s) = isempty(s) ? nothing : strip(s, '\'')

function _split_args(s::AbstractString)
    parts = String[]
    start, depth = 1, 0
    for (i, c) in enumerate(s)
        c == '(' && (depth += 1)
        c == ')' && (depth -= 1)
        if c == ',' && depth == 0
            push!(parts, strip(s[start:i-1]))
            start = i + 1
        end
    end
    push!(parts, strip(s[start:end]))
    return parts
end

function _parse_parametric(name::AbstractString, args::Vector{String})
    name == "DateTime"       && return CHDateTime(_strip_tz(args[1]))
    name == "DateTime64"     && return CHDateTime64(parse(Int, args[1]), length(args) >= 2 ? _strip_tz(args[2]) : nothing)
    name == "Enum8"          && return CHEnum8()
    name == "Enum16"         && return CHEnum16()
    name == "FixedString"    && return CHFixedString(parse(Int, args[1]))
    name == "Decimal"        && return CHDecimal(parse(Int, args[1]), parse(Int, args[2]))
    name == "Nullable"       && return CHNullable(parse_ch_type(args[1]))
    name == "LowCardinality" && return CHLowCardinality(parse_ch_type(args[1]))
    name == "Array"          && return CHArray(parse_ch_type(args[1]))
    name == "Tuple"          && return CHTuple(parse_ch_type.(args))
    name == "Map"            && return CHMap(parse_ch_type(args[1]), parse_ch_type(args[2]))
    throw(ArgumentError("Unknown ClickHouse type: $name($(join(args, ", ")))"))
end

"""
    parse_ch_type(s::AbstractString) -> CHType

Parse a ClickHouse type string into a [`CHType`](@ref) tree.

## Examples

```julia-repl
julia> parse_ch_type("Nullable(String)")
Nullable(String)

julia> parse_ch_type("Map(String, Array(UInt8))")
Map(String, Array(UInt8))
```
"""
function parse_ch_type(s::AbstractString)
    p = findfirst('(', s)
    if p === nothing
        t = get(_CH_PRIMITIVES, s, nothing)
        t !== nothing && return t
        s == "DateTime"  && return CHDateTime(nothing)
        s == "DateTime64" && return CHDateTime64(3, nothing)
        throw(ArgumentError("Unknown ClickHouse type: $s"))
    else
        return _parse_parametric(s[1:p-1], _split_args(s[p+1:end-1]))
    end
end

"""
    julia_type(x::CHType) -> Type

Map a [`CHType`](@ref) to the corresponding Julia type for (de)serialization.

## Examples

```julia-repl
julia> julia_type(parse_ch_type("Nullable(Int32)"))
Union{Nothing, Int32}

julia> julia_type(parse_ch_type("Array(String)"))
Vector{String}
```
"""
function julia_type end

julia_type(x::CHPrimitive)      = _JL_PRIMITIVES[x.name]
julia_type(::CHDateTime)        = DateTime
julia_type(::CHDateTime64)      = NanoDate
julia_type(x::CHFixedString)    = FixedString{x.n}
julia_type(x::CHDecimal)        = Decimal{x.P, x.S}
julia_type(::CHEnum8)           = UInt8
julia_type(::CHEnum16)          = UInt16
julia_type(x::CHNullable)       = Union{Nothing, julia_type(x.inner)}
julia_type(x::CHLowCardinality) = julia_type(x.inner)
julia_type(x::CHArray)          = Vector{julia_type(x.inner)}
julia_type(x::CHTuple)          = Tuple{julia_type.(x.inner)...}
julia_type(x::CHMap)            = Dict{julia_type(x.key), julia_type(x.val)}

"""
    parse_column_type(s::AbstractString) -> Type

Parse a ClickHouse type string and return the corresponding Julia type.
Shorthand for `julia_type(parse_ch_type(s))`.
"""
parse_column_type(s::AbstractString) = julia_type(parse_ch_type(s))
