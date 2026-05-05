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
- `cause::Union{Exception, Nothing}`: The original exception that caused this error, if any.
"""
struct CHClientException <: OhMyCHException
    message::String
    cause::Union{Exception, Nothing}

    CHClientException(message::String) = new(message, nothing)
    CHClientException(message::String, cause::Exception) = new(message, cause)
end

function Base.show(io::IO, e::CHClientException)
    print(io, "CHClientException: $(e.message)")
    if e.cause !== nothing
        print(io, "\n  Caused by: ")
        show(io, e.cause)
    end
end

function check_and_throw_exception(x::AbstractVector{UInt8})
    length(x) > 3 && x[end-2:end] == b"))\n" && parse_and_throw_exception(x)
    return nothing
end

function parse_and_throw_exception(chunk::AbstractVector{UInt8})
    p = findlast(b"Code:", chunk)
    p === nothing && return nothing
    msg = String(chunk[p[1]:end-1])
    !occursin("DB::Exception:", msg) && return nothing
    rest = chunk[p[end]+1:end]
    q = findfirst(b".", rest)
    q === nothing && return nothing
    throw(CHServerException(parse(Int, String(rest[1:q[1]-1])), msg))
end
