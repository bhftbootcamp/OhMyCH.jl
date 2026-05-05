"""
    Codec

Abstract supertype for compression codecs used in HTTP communication with ClickHouse.

See also [`LZ4`](@ref), [`NoCompression`](@ref).
"""
abstract type Codec end

"""
    NoCompression <: Codec

Disables compression for data transfer.
"""
struct NoCompression <: Codec end

encode(::NoCompression, x::Vector{UInt8}) = x
decode(::NoCompression, x::Vector{UInt8}) = x
content_encoding(::NoCompression) = nothing

"""
    LZ4 <: Codec

Represents the LZ4 codec used for compressing and decompressing data.
"""
struct LZ4 <: Codec end

content_encoding(::LZ4) = "lz4"

"""
    decode(::LZ4, x::Vector{UInt8}) -> Vector{UInt8}

Decompresses LZ4-compressed data in the byte vector `x` and returns a vector of the original data.

## Examples

```julia-repl
julia> original_data = collect(UInt8, "Hello")
5-element Vector{UInt8}:
 0x48
 0x65
 0x6c
 0x6c
 0x6f

julia> compressed_data = encode(LZ4(), original_data);

julia> decode(LZ4(), compressed_data) # "Hello" in UInt8 array
5-element Vector{UInt8}:
 0x48
 0x65
 0x6c
 0x6c
 0x6f
```
"""
decode(::LZ4, x::Vector{UInt8}) = transcode(LZ4FrameDecompressor, x)

"""
    encode(::LZ4, x::Vector{UInt8}) -> Vector{UInt8}

Compresses the data in the byte vector `x` using the LZ4 codec and returns a vector of the compressed data.

## Examples

```julia-repl
julia> original_data = collect(UInt8, "Hello") # "Hello" in UInt8 array
5-element Vector{UInt8}:
 0x48
 0x65
 0x6c
 0x6c
 0x6f

julia> compressed_data = encode(LZ4(), original_data);
20-element Vector{UInt8}:
 0x04
 0x22
    ⋮
 0x00
 0x00
```
"""
encode(::LZ4, x::Vector{UInt8}) = transcode(LZ4FrameCompressor, x)

"""
    resolve_codec(s::Symbol) -> Codec

Resolves a compression codec symbol to a [`Codec`](@ref) instance.
Supported values: `:lz4`, `:none`.
"""
function resolve_codec(s::Symbol)
    s === :lz4 && return LZ4()
    s === :none && return NoCompression()
    throw(ArgumentError("unknown compression codec: :$s, expected :lz4 or :none"))
end
