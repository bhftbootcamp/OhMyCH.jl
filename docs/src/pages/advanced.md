# For Developers

This section contains various information that may be useful for developing and understanding the package in more detail.

## Data Flow

The following diagram illustrates the process of data handling in **OhMyCH**, including iteration, deserialization, and returning data to the user:

```plaintext
                              +-------------------+
                              |   Input Data      |
                              |  (Vector{UInt8})  |
                              +-------------------+
                                       |
                +----------------------+-----------------------+
                |                                              |
 +---------------------------+               +------------------------------------+
 |         RowBinary         |               |     RowBinaryWithNamesAndTypes     |
 +---------------------------+               +------------------------------------+
                |                                              |
                v                                              v
 +---------------------------+               +------------------------------------+
 |        User type `T`      |               |    Parse Column Names and Types    |
 |   (e.g., `T` or `Tuple`)  |               |                                    |
 +---------------------------+               +------------------------------------+
                |                                              |
                +----------------------+-----------------------+
                                       |
                                       v
                              +-------------------+
                  +---------> |  Start Iteration  |
                  |           +-------------------+
                  |                    |
                  |                    v
                  |           +-------------------+
                  |           | Read Binary Chunk |
                  |           +-------------------+
                  |                    |
                  |                    v
                  |           +-------------------+
                  |           |  Deserialize Row  |
                  |           +-------------------+
                  |                    |
                  |                    v
                  |           +-------------------+
                  |           | Return Row to User|
                  |           +-------------------+
                  |                    |
                  |                    v
                  |           +-------------------+
                  |           |   Check for EOF   |
                  |           |   - More Data?    |
                  |           +-------------------+
                  |                    |
                  +--------------------+
                                       |
                                       v
                             +-------------------+
                             |   End Iteration   |
                             +-------------------+
```

## Serializer

```@docs
OhMyCH.Serializer
OhMyCH.serialize
OhMyCH.deserialize
```

## Binary iterators

```@docs
OhMyCH.RowToBinaryIter
OhMyCH.BinaryToRowIter
Base.iterate(::OhMyCH.RowBinaryWithNamesAndTypes)
```

## Column type parsing internals

```@docs
OhMyCH.CHType
OhMyCH.parse_ch_type
OhMyCH.julia_type
```

## Query parameter formatting

```@docs
OhMyCH.parameters_to_strings
```

## [Content encoding](@id content_encoding)

```@docs
OhMyCH.encode
OhMyCH.decode
OhMyCH.resolve_codec
```
