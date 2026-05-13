"""
    FixedString{N} <: AbstractString

A string type with a fixed maximum size `N`.

## Examples
```julia-repl
julia> FixedString{10}("Hello")
FixedString{10}("Hello")

julia> FixedString{3}("Hello")
ERROR: ArgumentError: Input string is longer than 3 bytes (5)
```
"""
struct FixedString{N} <: AbstractString
    string::String

    function FixedString{N}(x::AbstractString) where {N}
        N isa Integer || throw(ArgumentError("FixedString size N must be an integer, got $(typeof(N))."))
        N >= 1 || throw(ArgumentError("FixedString size N must be positive, got $N."))
        n = ncodeunits(x)
        n > N && throw(ArgumentError("Input string is longer than $N bytes ($n)."))
        return new(x)
    end
end

Base.String(s::FixedString) = String(s.string)
Base.hash(s::FixedString, h::UInt) = hash(s.string, h)
Base.print(io::IO, s::FixedString) = print(io, s.string)
Base.repr(s::FixedString) = repr(s.string)
Base.show(io::IO, s::FixedString{N}) where {N} = print(io, "FixedString{$N}(\"", s.string, "\")")

Base.length(s::FixedString) = length(s.string)
Base.ncodeunits(s::FixedString) = ncodeunits(s.string)
Base.isvalid(s::FixedString) = isvalid(s.string)
Base.isvalid(s::FixedString, i::Integer) = isvalid(s.string, i)
Base.codeunit(s::FixedString) = codeunit(s.string)
Base.codeunit(s::FixedString, i::Integer) = codeunit(s.string, i)
Base.iterate(s::FixedString, state::Int = 1) = iterate(s.string, state)
Base.reverse(s::FixedString) = reverse(s.string)

function Base.write(io::IO, s::FixedString{N}) where {N}
    return write(io, s.string * '\0'^(N - ncodeunits(s)))
end

function Base.read(io::IO, ::Type{FixedString{N}}) where {N}
    b = read(io, N)
    p = findlast(!iszero, b)
    return FixedString{N}(p === nothing ? "" : String(b[1:p]))
end
