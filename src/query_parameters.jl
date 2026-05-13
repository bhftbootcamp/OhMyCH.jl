stringify_value(::Union{Nothing,Missing}) = "NULL"
stringify_value(v::Bool) = v ? "1" : "0"
stringify_value(v::AbstractString) = "'" * escape_string(v) * "'"
stringify_value(v::Date) = format(v, "yyyy-mm-dd")
stringify_value(v::DateTime) = format(v, "yyyy-mm-dd HH:MM:SS")
stringify_value(v::NanoDate) = format(v, "yyyy-mm-ddTHH:MM:SS.sssssssss")
stringify_value(v::Real) = isnan(v) ? "nan" : isinf(v) ? (v == Inf ? "+inf" : "-inf") : string(v)
stringify_value(v::Union{UUID,IPv4,IPv6}) = string(v)

function stringify_value(d::AbstractDict)
    return "{" * join(("$(stringify_value(k)):$(stringify_value(v))" for (k, v) in d), ",") * "}"
end

stringify_value(v::AbstractArray) = "[" * join(map(stringify_value, v), ",") * "]"
stringify_value(v::Tuple) = "(" * join(map(stringify_value, v), ",") * ")"

parameter_to_string(v::AbstractString) = v
parameter_to_string(::Union{Nothing,Missing}) = "\\N"
parameter_to_string(@nospecialize(x)) = stringify_value(x)

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
 "param_tuple" => "(1,-2,3.0,1,nan,+inf)"

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

function parameters_to_strings(params::NamedTuple)
    return ["param_$k" => parameter_to_string(v) for (k, v) in pairs(params)]
end

function parameters_to_strings(params::T) where {T}
    return ["param_$k" => parameter_to_string(getfield(params, k)) for k in fieldnames(T)]
end
