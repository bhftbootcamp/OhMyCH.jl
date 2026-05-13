Tables.istable(::Type{RowBinaryWithNamesAndTypes}) = true
Tables.rowaccess(::Type{RowBinaryWithNamesAndTypes}) = true
Tables.rows(x::RowBinaryWithNamesAndTypes) = eachrow(x)

function Tables.schema(x::RowBinaryWithNamesAndTypes)
    names = Tuple(Symbol.(x.column_names))
    types = Tuple(parse_column_type.(x.column_types))
    return Tables.Schema(names, types)
end

Tables.istable(::Type{<:BinaryToRowIter}) = true
Tables.rowaccess(::Type{<:BinaryToRowIter}) = true
Tables.rows(x::BinaryToRowIter) = x

function Tables.schema(x::BinaryToRowIter)
    return Tables.Schema(x.column_names, x.column_types)
end
