#__ serialization

"""
    Serializer{I<:IO}

Custom IO wrapper for (de)serializing binary data streams.
"""
struct Serializer{I<:IO}
    io::I

    Serializer(x::I) where {I<:IO} = new{I}(x)
    Serializer(x::IOBuffer) = new{IOBuffer}(x)
    Serializer(x::AbstractVector{UInt8}) = new{IOBuffer}(IOBuffer(x))
    Serializer() = Serializer(IOBuffer())
end

Base.close(s::Serializer) = close(s.io)
Base.eof(s::Serializer) = eof(s.io)
Base.read(s::Serializer, x) = read(s.io, x)
Base.write(s::Serializer, x) = write(s.io, x)
Base.seek(s::Serializer, p::Integer) = seek(s.io, p)
Base.seekstart(s::Serializer) = seekstart(s.io)
Base.seekend(s::Serializer) = seekend(s.io)
Base.position(s::Serializer) = position(s.io)
Base.readavailable(s::Serializer) = readavailable(s.io)

@inline function write_leb128(s::Serializer, value::Integer)
    total_bytes::Int = 0
    while true
        byte = value & 0x7f
        value >>= 7
        if value != 0
            total_bytes += write(s, UInt8(byte | 0x80))
        else
            total_bytes += write(s, UInt8(byte))
            break
        end
    end
    return total_bytes
end

@inline function read_leb128(s::Serializer)
    value = 0
    shift = 0
    while true
        if eof(s)
            error("Unexpected end of file while reading LEB128 number.")
        end
        byte = read(s, UInt8)
        value |= (UInt64(byte & 0x7f) << shift)
        if (byte & 0x80) == 0
            return value
        end
        shift += 7
        if shift > 63
            error("LEB128 number is too long.")
        end
    end
end

"""
    serialize(s::Serializer, value::T) -> Int

Writes the byte representation of `value` to buffer `s`.

## Examples

```julia-repl
julia> using ClickHouse: Serializer, serialize, deserialize

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

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:Integer}
    return write(s, value)
end

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:AbstractFloat}
    return write(s, value)
end

@inline function serialize(s::Serializer, ::Type{Bool}, value::Bool)
    return write(s, UInt8(value ? 1 : 0))
end

@inline function serialize(s::Serializer, ::Type{String}, value::String)
    total_bytes = write_leb128(s, ncodeunits(value))
    return total_bytes + write(s, value)
end

@inline function serialize(s::Serializer, ::Type{Time}, value::Time)
    seconds = hour(value) * 3600 + minute(value) * 60 + second(value)
    return write(s, Int32(seconds))
end

@inline function serialize(s::Serializer, ::Type{Date}, value::Date)
    days = Dates.value(value - Date(1970, 1, 1))
    return write(s, UInt16(days))
end

@inline function serialize(s::Serializer, ::Type{DateTime}, value::DateTime)
    seconds = Dates.value(value - DateTime(1970, 1, 1)) ÷ 1000
    return write(s, Int32(seconds))
end

@inline function serialize(s::Serializer, ::Type{NanoDate}, value::NanoDate)
    ns = nanodate2unixnanos(value)
    return write(s, Int64(ns))
end

@inline function serialize(s::Serializer, ::Type{IPv4}, value::IPv4)
    return write(s, UInt32(value))
end

@inline function serialize(s::Serializer, ::Type{IPv6}, value::IPv6)
    return write(s, hton(UInt128(value)))
end

@inline function serialize(s::Serializer, ::Type{UUID}, value::UUID)
    u128 = UInt128(value)
    bytes = [UInt8((u128 >> (8 * (i - 1))) & 0xFF) for i = 16:-1:1]
    perm = [8, 7, 6, 5, 4, 3, 2, 1, 16, 15, 14, 13, 12, 11, 10, 9]
    return write(s, bytes[perm])
end

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:FixedString}
    return write(s, value)
end

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:AbstractVector}
    total_bytes = write_leb128(s, length(value))
    et = eltype(T)
    @inbounds for i in eachindex(value)
        total_bytes += serialize(s, et, value[i])
    end
    return total_bytes
end

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:AbstractDict}
    total_bytes = write_leb128(s, length(value))
    kt = keytype(T)
    vt = valtype(T)
    for (k, v) in value
        total_bytes += serialize(s, kt, k)
        total_bytes += serialize(s, vt, v)
    end
    return total_bytes
end

@inline function serialize(s::Serializer, ::Type{Tuple{}}, value::Tuple{})
    return error("Serialization of empty tuples (Tuple{}) is not supported.")
end

@inline function serialize(s::Serializer, ::Type{T}, value::T) where {T<:Tuple}
    total_bytes::Int = 0
    for (x, t) in zip(value, fieldtypes(T))
        total_bytes += serialize(s, t, x)
    end
    return total_bytes
end

@inline function serialize(s::Serializer, ::Type{Union{Nothing,T}}, value) where {T}
    return if isnothing(value)
        write(s, UInt8(0x01))
    else
        write(s, UInt8(0x00))
        serialize(s, T, value) + 1 # bytes of `value` + UInt8
    end
end

@inline function serialize(s::Serializer, T::Type, value)
    return error("Unsupported type $(T) for serialization.")
end

serialize(s::Serializer, @nospecialize(x)) = serialize_any(s, x)

function serialize_any(s::Serializer, @nospecialize(x))
    t = typeof(x)::DataType
    return if isprimitivetype(t)
        serialize(s, t, x)
    else
        total_bytes::Int = 0
        for i = 1:nfields(x)
            total_bytes += serialize(s, fieldtype(t, i), getfield(x, i))
        end
        total_bytes
    end
end

"""
    deserialize(s::Serializer, T::Type) -> T

Reads a sequence of bytes corresponding to type `T` from buffer `s`, and then creates an object from them.

## Examples

```julia-repl
julia> using ClickHouse: Serializer, serialize, deserialize

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

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:Integer}
    return read(s, T)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:AbstractFloat}
    return read(s, T)
end

@inline function deserialize(s::Serializer, ::Type{Bool})
    return read(s, UInt8) != 0
end

@inline function deserialize(s::Serializer, ::Type{String})
    len = read_leb128(s)
    return String(read(s, len))
end

@inline function deserialize(s::Serializer, ::Type{Time})
    b = read(s, Int32)
    second = b % 86400
    return Time(second ÷ 3600, (second % 3600) ÷ 60, second % 60)
end

@inline function deserialize(s::Serializer, ::Type{Date})
    days = read(s, UInt16)
    return Date(1970, 1, 1) + Day(days)
end

@inline function deserialize(s::Serializer, ::Type{DateTime})
    seconds = read(s, Int32)
    return DateTime(1970, 1, 1) + Second(seconds)
end

@inline function deserialize(s::Serializer, ::Type{NanoDate})
    nanos = read(s, Int64)
    nanos == 0 && return 0
    o = floor(Int, log10(abs(nanos))) + 1
    z = 19 - o
    return unixnanos2nanodate(nanos * 10^z)
end

@inline function deserialize(s::Serializer, ::Type{IPv4})
    return IPv4(read(s, UInt32))
end

@inline function deserialize(s::Serializer, ::Type{IPv6})
    return IPv6(ntoh(read(s, UInt128)))
end

@inline function deserialize(s::Serializer, ::Type{UUID})
    bytes = read(s, sizeof(UInt128))
    perm = [8, 7, 6, 5, 4, 3, 2, 1, 16, 15, 14, 13, 12, 11, 10, 9]
    uuid = UInt128(0)
    for (i, byte) in enumerate(bytes[perm])
        uuid |= UInt128(byte) << ((16 - i) * 8)
    end
    return UUID(uuid)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:FixedString}
    return read(s, T)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:AbstractVector}
    len = read_leb128(s)
    et = eltype(T)
    arr = Vector{eltype(T)}(undef, len)
    for i = 1:len
        arr[i] = deserialize(s, et)
    end
    return T(arr)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:AbstractDict}
    len = read_leb128(s)
    kt = keytype(T)
    vt = valtype(T)
    dict = T()
    for _ = 1:len
        key = deserialize(s, kt)
        val = deserialize(s, vt)
        dict[key] = val
    end
    return T(dict)
end

@inline function deserialize(s::Serializer, ::Type{Union{Nothing,T}}) where {T}
    return read(s, UInt8) == 0x01 ? nothing : deserialize(s, T)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T<:Tuple}
    nt = ntuple(i -> deserialize(s, fieldtype(T, i)), fieldcount(T))
    return T(nt)
end

@inline function deserialize(s::Serializer, ::Type{T}) where {T}
    return error("Unsupported type $(T) for deserialization.")
end
