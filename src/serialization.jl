"""
    Serializer{I<:IO}

Custom IO wrapper for (de)serializing binary data streams.
"""
struct Serializer{I<:IO}
    io::I

    Serializer(io::I) where {I<:IO} = new{I}(io)
    Serializer(x::AbstractVector{UInt8}) = new{IOBuffer}(IOBuffer(x))
    Serializer() = new{IOBuffer}(IOBuffer())
end

for f in (:close, :eof, :read, :write, :seek, :seekstart, :seekend, :position, :readavailable)
    @eval Base.$f(s::Serializer, args...) = $f(s.io, args...)
end

function write_leb128(s::Serializer, v::Integer)
    n = 0
    while true
        b = v & 0x7f
        v >>= 7
        n += write(s, UInt8(v != 0 ? b | 0x80 : b))
        v == 0 && break
    end
    return n
end

function read_leb128(s::Serializer)
    v, shift = UInt64(0), 0
    while true
        eof(s) && error("Unexpected end of file while reading LEB128 number.")
        b = read(s, UInt8)
        v |= UInt64(b & 0x7f) << shift
        (b & 0x80) == 0 && return v
        shift += 7
        shift > 63 && error("LEB128 number is too long.")
    end
end

"""
    serialize(s::Serializer, ::Type{T}, value::T) -> Int
    serialize(s::Serializer, value) -> Int

Writes the byte representation of `value` to buffer `s`.

## Examples

```julia-repl
julia> import OhMyCH: Serializer, serialize, deserialize

julia> s = Serializer();

julia> serialize(s, UInt8, UInt8(10))
1

julia> serialize(s, Int32, Int32(100))
4

julia> serialize(s, Float64, Float64(1000.0))
8

julia> serialize(s, String, "Hello, World!!!")
16

julia> seekstart(s.io);

julia> deserialize(s, UInt8)
0x0a

julia> deserialize(s, Int32)
100

julia> deserialize(s, Float64)
1000.0

julia> deserialize(s, String)
"Hello, World!!!"
```
"""
function serialize end

serialize(s::Serializer, ::Type{T}, v::T) where {T<:Integer} = write(s, v)
serialize(s::Serializer, ::Type{T}, v::T) where {T<:AbstractFloat} = write(s, v)
serialize(s::Serializer, ::Type{Bool}, v::Bool) = write(s, UInt8(v))
serialize(s::Serializer, ::Type{T}, v::T) where {T<:FixedString} = write(s, v)
serialize(s::Serializer, ::Type{IPv4}, v::IPv4) = write(s, UInt32(v))
serialize(s::Serializer, ::Type{IPv6}, v::IPv6) = write(s, hton(UInt128(v)))
serialize(s::Serializer, ::Type{Date}, v::Date) = write(s, UInt16(Dates.value(v - Date(1970, 1, 1))))
serialize(s::Serializer, ::Type{DateTime}, v::DateTime) = write(s, Int32(Dates.value(v - DateTime(1970, 1, 1)) ÷ 1000))
serialize(s::Serializer, ::Type{NanoDate}, v::NanoDate) = write(s, Int64(nanodate2unixnanos(v)))
serialize(s::Serializer, ::Type{Time}, v::Time) = write(s, Int32(hour(v) * 3600 + minute(v) * 60 + second(v)))

function serialize(s::Serializer, ::Type{String}, v::String)
    n = write_leb128(s, ncodeunits(v))
    return n + write(s, v)
end

const _UUID_PERM = (8, 7, 6, 5, 4, 3, 2, 1, 16, 15, 14, 13, 12, 11, 10, 9)

function serialize(s::Serializer, ::Type{UUID}, v::UUID)
    u = UInt128(v)
    buf = ntuple(j -> UInt8((u >> (8 * (16 - _UUID_PERM[j]))) & 0xFF), Val(16))
    return write(s, collect(buf))
end

function serialize(s::Serializer, ::Type{T}, v::T) where {T<:AbstractVector}
    n = write_leb128(s, length(v))
    et = eltype(T)
    @inbounds for i in eachindex(v)
        n += serialize(s, et, v[i])
    end
    return n
end

function serialize(s::Serializer, ::Type{T}, d::T) where {T<:AbstractDict}
    n = write_leb128(s, length(d))
    kt, vt = keytype(T), valtype(T)
    for (k, v) in d
        n += serialize(s, kt, k)
        n += serialize(s, vt, v)
    end
    return n
end

serialize(s::Serializer, ::Type{Tuple{}}, ::Tuple{}) = error("Serialization of empty tuples (Tuple{}) is not supported.")

function serialize(s::Serializer, ::Type{T}, v::T) where {T<:Tuple}
    n = 0
    for (x, t) in zip(v, fieldtypes(T))
        n += serialize(s, t, x)
    end
    return n
end

function serialize(s::Serializer, ::Type{Union{Nothing,T}}, v) where {T}
    isnothing(v) && return write(s, UInt8(0x01))
    return write(s, UInt8(0x00)) + serialize(s, T, v)
end

serialize(s::Serializer, T::Type, v) = error("Unsupported type $T for serialization.")

serialize(s::Serializer, @nospecialize(x)) = serialize_any(s, x)

function serialize_any(s::Serializer, @nospecialize(x))
    t = typeof(x)::DataType
    isprimitivetype(t) && return serialize(s, t, x)
    n = 0
    for i = 1:nfields(x)
        n += serialize(s, fieldtype(t, i), getfield(x, i))
    end
    return n
end

"""
    deserialize(s::Serializer, T::Type) -> T

Reads a sequence of bytes corresponding to type `T` from buffer `s`, and then creates an object from them.

## Examples

```julia-repl
julia> import OhMyCH: Serializer, serialize, deserialize

julia> s = Serializer([0x0a, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x8f, 0x40]);

julia> deserialize(s, UInt8)
0x0a

julia> deserialize(s, Int32)
100

julia> deserialize(s, Float64)
1000.0
```
"""
function deserialize end

deserialize(s::Serializer, ::Type{T}) where {T<:Integer} = read(s, T)
deserialize(s::Serializer, ::Type{T}) where {T<:AbstractFloat} = read(s, T)
deserialize(s::Serializer, ::Type{Bool}) = read(s, UInt8) != 0
deserialize(s::Serializer, ::Type{String}) = String(read(s, read_leb128(s)))
deserialize(s::Serializer, ::Type{T}) where {T<:FixedString} = read(s, T)
deserialize(s::Serializer, ::Type{IPv4}) = IPv4(read(s, UInt32))
deserialize(s::Serializer, ::Type{IPv6}) = IPv6(ntoh(read(s, UInt128)))
deserialize(s::Serializer, ::Type{Date}) = Date(1970, 1, 1) + Day(read(s, UInt16))
deserialize(s::Serializer, ::Type{DateTime}) = DateTime(1970, 1, 1) + Second(read(s, Int32))

function deserialize(s::Serializer, ::Type{Time})
    t = read(s, Int32) % 86400
    return Time(t ÷ 3600, (t % 3600) ÷ 60, t % 60)
end

function deserialize(s::Serializer, ::Type{NanoDate})
    ns = read(s, Int64)
    ns == 0 && return NanoDate(1970)
    o = floor(Int, log10(abs(ns))) + 1
    return unixnanos2nanodate(ns * 10^(19 - o))
end

function deserialize(s::Serializer, ::Type{UUID})
    bytes = read(s, sizeof(UInt128))
    u = UInt128(0)
    for (i, p) in enumerate(_UUID_PERM)
        u |= UInt128(bytes[p]) << ((16 - i) * 8)
    end
    return UUID(u)
end

function deserialize(s::Serializer, ::Type{T}) where {T<:AbstractVector}
    n = read_leb128(s)
    et = eltype(T)
    arr = Vector{et}(undef, n)
    for i = 1:n
        arr[i] = deserialize(s, et)
    end
    return T(arr)
end

function deserialize(s::Serializer, ::Type{T}) where {T<:AbstractDict}
    n = read_leb128(s)
    kt, vt = keytype(T), valtype(T)
    d = T()
    for _ = 1:n
        k = deserialize(s, kt)
        d[k] = deserialize(s, vt)
    end
    return T(d)
end

deserialize(s::Serializer, ::Type{Union{Nothing,T}}) where {T} = read(s, UInt8) == 0x01 ? nothing : deserialize(s, T)
deserialize(s::Serializer, ::Type{T}) where {T<:Tuple} = T(ntuple(i -> deserialize(s, fieldtype(T, i)), fieldcount(T)))
deserialize(s::Serializer, ::Type{T}) where {T} = error("Unsupported type $T for deserialization.")
