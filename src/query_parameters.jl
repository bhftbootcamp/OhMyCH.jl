#__ query_parameters

@inline stringify_value(::Union{Nothing,Missing})::String = "NULL"

@inline function stringify_value(v::AbstractString)::String
    return string("'", escape_string(v), "'")
end

@inline function stringify_value(v::Date)::String
    return format(v, "yyyy-mm-dd")
end

@inline function stringify_value(v::DateTime)::String
    return format(v, "yyyy-mm-dd HH:MM:SS")
end

@inline function stringify_value(v::NanoDate)::String
    return format(v, "yyyy-mm-ddTHH:MM:SS.sssssssss")
end

@inline function stringify_value(v::Real)::String
    return isnan(v) ? "nan" : isinf(v) ? (v == Inf ? "+inf" : "-inf") : string(v)
end

@inline stringify_value(v::UUID)::String = string(v)
@inline stringify_value(v::IPv4)::String = string(v)
@inline stringify_value(v::IPv6)::String = string(v)

@inline function stringify_value(v::AbstractDict)::String
    parts = Vector{String}(undef, length(v))
    for (i, (key, val)) in enumerate(v)
        parts[i] = "$(stringify_value(key)):$(stringify_value(val))"
    end
    return "{" * join(parts, ",") * "}"
end

@inline function stringify_value(v::AbstractArray)::String
    parts = map(stringify_value, v)
    return "[" * join(parts, ",") * "]"
end

@inline function stringify_value(v::Tuple)::String
    parts = map(stringify_value, v)
    return "(" * join(parts, ",") * ")"
end

parameter_to_string(v::AbstractString) = v
parameter_to_string(::Union{Nothing,Missing})::String = "\\N"
parameter_to_string(@nospecialize(x))::String = stringify_value(x)

"""
    parameters_to_strings(values::NamedTuple) -> Vector{Pair{String,String}}
    parameters_to_strings(values::T) -> Vector{Pair{String,String}}

Method that formats parameter `values` into the form required for the request.

See more in [`ClickHouse Docs`](https://clickhouse.com/docs/en/interfaces/http#cli-queries-with-parameters).

## Examples

```julia-repl
julia> parameters_to_strings((
           null = nothing,
           string = "123",
           vector = [1.0, 2.0, 3.0],
       ))
3-element Vector{Pair{String, String}}:
 "param_null" => "\\N"
 "param_string" => "123"
 "param_vector" => "[1.0,2.0,3.0]"

julia> parameters_to_strings((
           tuple = (1, -2, 3.0, true, NaN, Inf),
       ))
1-element Vector{Pair{String, String}}:
 "param_tuple" => "(1,-2,3.0,true,nan,+inf)"

julia> parameters_to_strings((
           dict = Dict(
               "int_key" => 1,
               "null_key" => nothing,
           ),
       ))
1-element Vector{Pair{String, String}}:
 "param_dict" => "{'int_key':1,'null_key':NULL}"
```
"""
function parameters_to_strings end

function parameters_to_strings(params::NamedTuple)::Vector{Pair{String,String}}
    return ["param_$k" => parameter_to_string(v) for (k, v) in pairs(params)]
end

function parameters_to_strings(params::T) where {T}
    return ["param_$k" => parameter_to_string(getfield(params, k)) for k in fieldnames(T)]
end
