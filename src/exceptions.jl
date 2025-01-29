#__ exceptions

"""
    OhMyCHException <: Exception

An abstract base exception for database-related errors.
"""
abstract type OhMyCHException <: Exception end

"""
    CHServerException <: OhMyCHException

Raised when the ClickHouse server returns an error response while processing a query.

## Fields
- `code::ErrorCodes`: An error code indicating the type of database error.
- `message::String`: A descriptive message providing details about the error.

See also [`ErrorCodes`](@ref).
"""
struct CHServerException <: OhMyCHException
    code::ErrorCodes
    message::String

    function CHServerException(code::Int, message::String)
        return new(ErrorCodes(code), message)
    end

    function CHServerException(code::String, message::Vector{UInt8})
        return CHServerException(parse(Int, code), String(message))
    end
end

function Base.show(io::IO, e::CHServerException)
    return print(io, "CHServerException (Code: $(e.code)): $(e.message)")
end

"""
    CHClientException <: OhMyCHException

Represents an error that occurs during HTTP communication with the ClickHouse database.

## Fields
- `message::String`: A descriptive message providing details about the error.
"""
struct CHClientException <: OhMyCHException
    message::String

    function CHClientException(message::String)
        return new(message)
    end
end

function Base.show(io::IO, e::CHClientException)
    return print(io, "CHClientException: $(e.message)")
end

function check_and_throw_exception(x::AbstractVector{UInt8})
    if length(x) <= 3
        nothing
    elseif x[end-2:end] == b"))\n"
        parse_and_throw_exception(x)
    else
        nothing
    end
end

function parse_and_throw_exception(chunk::AbstractVector{UInt8})
    start_index = findlast(b"Code:", chunk)
    start_index === nothing && return nothing
    error_message = String(chunk[start_index[1]:end-1])
    !occursin("DB::Exception:", error_message) && return nothing
    code_chunk = chunk[start_index[end]+1:end]
    end_index = findfirst(b".", code_chunk)
    error_code = parse(Int, String(code_chunk[1:end_index[1]-1]))
    throw(CHServerException(error_code, error_message))
end
