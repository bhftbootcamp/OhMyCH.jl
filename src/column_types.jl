#__ column_types

function primitive_type(base::AbstractString)
    if base == "Bool"
        Bool
    elseif base == "UInt8"
        UInt8
    elseif base == "UInt16"
        UInt16
    elseif base == "UInt32"
        UInt32
    elseif base == "UInt64"
        UInt64
    elseif base == "UInt128"
        UInt128
    elseif base == "Int8"
        Int8
    elseif base == "Int16"
        Int16
    elseif base == "Int32"
        Int32
    elseif base == "Int64"
        Int64
    elseif base == "Int128"
        Int128
    elseif base == "Float32"
        Float32
    elseif base == "Float64"
        Float64
    elseif base == "String"
        String
    elseif base == "Date"
        Date
    elseif base == "DateTime"
        DateTime
    elseif base == "DateTime64"
        NanoDate
    elseif base == "UUID"
        UUID
    elseif base == "IPv4"
        IPv4
    elseif base == "IPv6"
        IPv6
    else
        error("Unknown base type: $base")
    end
end

function complex_type(base::AbstractString, args::Vector{String})
    if base == "DateTime64"
        NanoDate
    elseif base == "Enum8"
        UInt8
    elseif base == "Enum16"
        UInt16
    elseif base == "Nullable"
        T = parse_column_type(args[1])
        Union{Nothing,T}
    elseif base == "LowCardinality"
        parse_column_type(args[1])
    elseif base == "FixedString"
        N = Base.parse(Int, args[1])
        FixedString{N}
    elseif base == "Decimal"
        P, S = Base.parse.(Int, args)
        Decimal{P,S}
    elseif base == "Array"
        T = parse_column_type(args[1])
        Vector{T}
    elseif base == "Tuple"
        types = parse_column_type.(args)
        Tuple{types...}
    elseif base == "Map"
        K = parse_column_type(args[1])
        V = parse_column_type(args[2])
        Dict{K,V}
    else
        error("Unknown complex type: $base with args: $args")
    end
end

function split_type_arguments(args::AbstractString)::Vector{String}
    parts = String[]
    start, depth = 1, 0
    for (i, ch) in enumerate(args)
        if ch == '('
            depth += 1
        elseif ch == ')'
            depth -= 1
        elseif ch == ',' && depth == 0
            push!(parts, strip(args[start:i-1]))
            start = i + 1
        end
    end
    push!(parts, strip(args[start:end]))
    return parts
end

"""
    parse_column_type(type_str::String)

Parses a ClickHouse-like type string and returns the corresponding Julia type.

See also [`Supported column types`](@ref column_types).

## Examples

```julia-repl
julia> parse_column_type("LowCardinality(String)")
String

julia> parse_column_type("Nullable(Decimal(9,2))")
Union{Nothing,Decimal{9,2}}

julia> parse_column_type("Array(Tuple(Int8, UInt16))")
Vector{Tuple{Int8,UInt16}}
```
"""
function parse_column_type(type_str::AbstractString)
    m = match(r"^([A-Za-z0-9]+)(?:\((.*)\))?$", type_str)
    if m === nothing
        error("Invalid type format: $type_str")
    end
    base, args_str = m
    if args_str === nothing
        return primitive_type(base)
    else
        args = split_type_arguments(args_str)
        return complex_type(base, args)
    end
end
