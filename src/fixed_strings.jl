#__ fixed_strings

"""
    FixedString{N} <: AbstractString

A string type with a fixed maximum size `N`.

## Fields
- `data::String`: The string data that is constrained by the fixed size `N`.
"""
struct FixedString{N} <: AbstractString
    string::String

    function FixedString{N}(x::AbstractString) where {N}
        n = ncodeunits(x)
        if N < 0
            throw(ArgumentError("FixedString size N must be positive."))
        elseif n > N
            throw(ArgumentError("Input string is longer than $N bytes ($n)."))
        end
        return new(x)
    end
end

"""
    FixedString{N}(x::String)

Constructs a [`FixedString`](@ref) object with a fixed maximum size `N` from the given string `x`.

## Examples
```julia-repl
julia> FixedString{10}("Hello")
FixedString{10}("Hello")

julia> FixedString{3}("Hello")
ERROR: ArgumentError: Input string is longer than 3 bytes (5)
```
"""
FixedString(::AbstractString)

Base.String(fstr::FixedString) = String(fstr.string)
Base.length(fstr::FixedString) = length(fstr.string)
Base.ncodeunits(fstr::FixedString) = ncodeunits(fstr.string)

Base.isvalid(fstr::FixedString) = isvalid(fstr.string)
Base.isvalid(fstr::FixedString, i::Integer) = isvalid(fstr.string, i)

Base.codeunit(fstr::FixedString) = codeunit(fstr.string)
Base.codeunit(fstr::FixedString, i::Integer) = codeunit(fstr.string, i)

function Base.iterate(fstr::FixedString, state::Int = 1)
    return iterate(fstr.string, state)
end

Base.hash(fstr::FixedString, h::UInt) = hash(fstr.string, h)

Base.reverse(fstr::T) where {T<:FixedString} = reverse(fstr.string)

Base.print(io::IO, fstr::FixedString{N}) where {N} = print(io, fstr.string)
Base.repr(fstr::FixedString{N}) where {N} = repr(fstr.string)
function Base.show(io::IO, fstr::FixedString{N}) where {N}
    return print(io, "FixedString{$N}(\"", fstr.string, "\")")
end

function Base.write(io::IO, fstr::FixedString{N}) where {N}
    padding_size = N - ncodeunits(fstr)
    return write(io, fstr.string * '\0' ^ max(0, padding_size))
end

function Base.read(io::IO, ::Type{FixedString{N}}) where {N}
    b = read(io, N)
    return FixedString{N}(String(b[b.!==0x0]))
end
