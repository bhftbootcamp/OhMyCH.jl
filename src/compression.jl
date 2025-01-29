#__ compression

using CodecLz4

abstract type Codec end

"""
    Lz4 <: Codec

Represents the LZ4 codec used for compressing and decompressing data.
"""
struct Lz4 <: Codec end

content_encoding(::Type{Lz4}) = "lz4"

"""
    decode(::Type{Lz4}, x::Vector{UInt8}) -> Vector{UInt8}

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

julia> compressed_data = encode(Lz4, original_data);

julia> decode(Lz4, compressed_data) # "Hello" in UInt8 array
5-element Vector{UInt8}:
 0x48
 0x65
 0x6c
 0x6c
 0x6f
```
"""
decode(::Type{Lz4}, x::Vector{UInt8}) = transcode(LZ4FrameDecompressor, x)

"""
    encode(::Type{Lz4}, x::Vector{UInt8}) -> Vector{UInt8}

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

julia> compressed_data = encode(Lz4, original_data);
20-element Vector{UInt8}:
 0x04
 0x22
    ⋮
 0x00
 0x00
```
"""
encode(::Type{Lz4}, x::Vector{UInt8}) = transcode(LZ4FrameCompressor, x)
