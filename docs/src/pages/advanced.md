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

## [Binary formats](@id supported_formats)

```@docs
OhMyCH.RowBinaryResult
OhMyCH.RowBinary
OhMyCH.RowBinaryWithNamesAndTypes
```

## Column types

```@docs
OhMyCH.parse_column_type
```

## Binary iterators

```@docs
OhMyCH.RowToBinaryIter
OhMyCH.BinaryToRowIter
```

## [Content encoding](@id content_encoding)

```@docs
OhMyCH.Lz4
OhMyCH.encode
OhMyCH.decode
```
