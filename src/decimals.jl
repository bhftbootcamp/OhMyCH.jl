#__ decimals

using DecFP
using DecFP: DecimalFloatingPoint

const DecimalFP = DecimalFloatingPoint

const JL_DEC32_MAX_PRECISION  = 7
const JL_DEC64_MAX_PRECISION  = 16
const JL_DEC128_MAX_PRECISION = 34

const CH_DEC32_MAX_PRECISION  = 9
const CH_DEC64_MAX_PRECISION  = 18
const CH_DEC128_MAX_PRECISION = 38

abstract type AbstractDecimal{P,S} <: AbstractFloat end

@inline function validate_precision_and_scale(P::Integer, S::Integer)
    if !(1 <= P <= JL_DEC128_MAX_PRECISION)
        throw(ArgumentError("Decimal precision P must be in range [1, $JL_DEC128_MAX_PRECISION], got $P"))
    end
    if !(0 <= S <= P)
        throw(ArgumentError("Decimal scale S must be in range [0, P=$P], got $S"))
    end
end

function decimal_by_precision_and_scale(P::Integer, S::Integer, args...)
    validate_precision_and_scale(P, S)
    decimal = if P <= JL_DEC32_MAX_PRECISION
        Dec32(args...)
    elseif P <= JL_DEC64_MAX_PRECISION
        Dec64(args...)
    elseif P <= JL_DEC128_MAX_PRECISION
        Dec128(args...)
    else
        throw(ArgumentError("Decimal precision P=$P is out of range for valid Decimal types"))
    end
    if isinf(decimal)
        throw(ArgumentError("Infinity Decimals are unsupported."))
    end
    _, significand, exponent = sigexp(decimal)
    n = ndigits(significand)
    if !(n + exponent <= max(1, P - S))
        throw(ArgumentError(
            "Decimal value $decimal exceeds limits for Decimal{P=$P,S=$S}. " *
            "Max allowed: ±$(string(repeat('9', P - S), '.', repeat('9', S)))."
        ))
    end
    return decimal
end

"""
    Decimal{P,S} <: AbstractFloat

A type that represents a fixed-precision decimal number with precision `P` and scale `S`.
Precision `P` is a total number of digits in the number (including digits before and after the decimal point).
Scale `S` is a number of digits after the decimal point.
"""
struct Decimal{P,S,D<:DecimalFP} <: AbstractDecimal{P,S}
    value::D

    function Decimal{P,S}(value::Union{Real,AbstractString}) where {P,S}
        decimal = decimal_by_precision_and_scale(P, S, value)
        return new{P,S,typeof(decimal)}(decimal)
    end

    function Decimal{P,S}(sign::Integer, significand::Integer, exponent::Integer) where {P,S}
        decimal = decimal_by_precision_and_scale(P, S, sign, significand, exponent)
        return new{P,S,typeof(decimal)}(decimal)
    end

    function Decimal{P,S}(significand::Integer, exponent::Integer) where {P,S}
        return Decimal{P,S}(sign(significand), significand, exponent)
    end
end

"""
    Decimal{P,S}(value::Union{Real,AbstractString})

Constructs a [`Decimal`](@ref) with precision `P` and scale `S` from a `value`.

## Examples

```julia-repl
julia> Decimal{5,2}(123.45)
Decimal{5,2}(123.45)

julia> Decimal{5,2}("123.45")
Decimal{5,2}(123.45)

julia> Decimal{5,2}(123456.0)
ERROR: ArgumentError: Decimal value 123456.0 exceeds limits for Decimal{P=5,S=2}. Max allowed: ±999.99.
```
"""
Decimal(::Union{Real,AbstractString,DecimalFP})

"""
    Decimal{P,S}([sign::Integer, ] significand::Integer, exponent::Integer)

Constructs a [`Decimal`](@ref) with precision `P` and scale `S` from its components:
- `sign`: The sign of the decimal (`+1` or `-1`).
- `significand`: The integer part of the number (absolute value).
- `exponent`: The base-10 exponent.

## Examples

```julia-repl
julia> Decimal{5,2}(12345, -2)
Decimal{5,2}(123.45)

julia> Decimal{5,2}(-1, 12345, -3)
Decimal{5,2}(-12.345)

julia> Decimal{5,2}(123456, -2)
ERROR: ArgumentError: Decimal value 1234.56 exceeds limits for Decimal{P=5,S=2}. Max allowed: ±999.99.
```
"""
Decimal(::Integer, ::Integer, ::Integer)

Base.print(io::IO, x::Decimal) = print(io, x.value)
Base.show(io::IO, x::Decimal{P,S}) where {P,S} = print(io, "Decimal{$P,$S}(", x, ")")

Base.isless(x::AbstractDecimal, y::AbstractDecimal) = Base.isless(x.value, y.value)
Base.isequal(x::AbstractDecimal, y::AbstractDecimal) = Base.isequal(x.value, y.value)
Base.:(<)(x::AbstractDecimal, y::AbstractDecimal) = x.value < y.value
Base.:(==)(x::AbstractDecimal, y::AbstractDecimal) = x.value == y.value

Base.isless(x::AbstractDecimal, y::AbstractFloat) = Base.isless(x.value, y)
Base.isequal(x::AbstractDecimal, y::AbstractFloat) = Base.isequal(x.value, y)
Base.:(<)(x::AbstractDecimal, y::AbstractFloat) = x.value < y
Base.:(==)(x::AbstractDecimal, y::AbstractFloat) = x.value == y

Base.isless(x::AbstractFloat, y::AbstractDecimal) = Base.isless(x, y.value)
Base.isequal(x::AbstractFloat, y::AbstractDecimal) = Base.isequal(x, y.value)
Base.:(<)(x::AbstractFloat, y::AbstractDecimal) = x < y.value
Base.:(==)(x::AbstractFloat, y::AbstractDecimal) = x == y.value

Base.isless(x::AbstractDecimal, y::Integer) = Base.isless(x.value, y)
Base.isequal(x::AbstractDecimal, y::Integer) = Base.isequal(x.value, y)
Base.:(<)(x::AbstractDecimal, y::Integer) = x.value < y
Base.:(==)(x::AbstractDecimal, y::Integer) = x.value == y

Base.isless(x::Integer, y::AbstractDecimal) = Base.isless(x, y.value)
Base.isequal(x::Integer, y::AbstractDecimal) = Base.isequal(x, y.value)
Base.:(<)(x::Integer, y::AbstractDecimal) = x < y.value
Base.:(==)(x::Integer, y::AbstractDecimal) = x == y.value

function Base.promote_rule(::Type{<:Decimal{P1,S1}}, ::Type{<:Decimal{P2,S2}}) where {P1,S1,P2,S2}
    return Decimal{max(P1, P2),max(S1, S2)}
end
function Base.promote_rule(::Type{<:Decimal{P,S}}, ::Type{<:Number}) where {P,S}
    return Decimal{P,S}
end

function Base.convert(::Type{<:Decimal{P1,S1}}, v::Decimal{P2,S2}) where {P1,S1,P2,S2}
    return Decimal{max(P1, P2),max(S1, S2)}(v.value)
end
Base.convert(::Type{T}, v::AbstractDecimal) where {T<:Number} = T(v.value)

Base.:(+)(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} = promote_rule(D1, D2)(+(x.value, y.value))
Base.:(-)(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} = promote_rule(D1, D2)(-(x.value, y.value))
Base.:(*)(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} = promote_rule(D1, D2)(*(x.value, y.value))
Base.:(/)(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} = promote_rule(D1, D2)(/(x.value, y.value))
Base.:(^)(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} = promote_rule(D1, D2)(^(x.value, y.value))

Base.inv(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.inv(x.value))
Base.sqrt(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.sqrt(x.value))
Base.log(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.log(x.value))
Base.log10(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.log10(x.value))
Base.log2(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.log2(x.value))
Base.log1p(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.log1p(x.value))
Base.exp(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.exp(x.value))
Base.exp2(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.exp2(x.value))
Base.exp10(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.exp10(x.value))
Base.expm1(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.expm1(x.value))

Base.sin(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.sin(x.value))
Base.cos(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.cos(x.value))
Base.tan(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.tan(x.value))
Base.asin(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.asin(x.value))
Base.acos(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.acos(x.value))
Base.atan(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.atan(x.value))

Base.sinh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.sinh(x.value))
Base.cosh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.cosh(x.value))
Base.tanh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.tanh(x.value))
Base.asinh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.asinh(x.value))
Base.acosh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.acosh(x.value))
Base.atanh(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.atanh(x.value))

function Base.round(x::Decimal{P,S}, r::RoundingMode = RoundNearest; kw...) where {P,S}
    return Decimal{P,S}(Base.round(x.value, r; kw...))
end
function Base.round(::Type{T}, x::AbstractDecimal, r::RoundingMode = RoundNearest) where {T<:Integer}
    return Base.round(T, x.value, r)
end

function Base.trunc(x::Decimal{P,S}; kw...) where {P,S}
    return Decimal{P,S}(Base.trunc(x.value; kw...))
end
function Base.trunc(::Type{T}, x::AbstractDecimal) where {T}
    return Base.trunc(T, x.value)
end

Base.one(::Union{Decimal,Type{<:Decimal}}) = Decimal{1,1}(1)
Base.zero(::Union{Decimal,Type{<:Decimal}}) = Decimal{1,1}(0)
Base.iszero(x::Decimal) = x == zero(x)

Base.signbit(x::AbstractDecimal) = Base.signbit(x.value)
Base.sign(v::AbstractDecimal) = sigexp(v.value)[1]
Base.significand(v::AbstractDecimal) = sigexp(v.value)[2]
Base.exponent(v::AbstractDecimal) = sigexp(v.value)[3] # ?

Base.Int8(v::AbstractDecimal) = Int8(v.value)
Base.Int16(v::AbstractDecimal) = Int16(v.value)
Base.Int32(v::AbstractDecimal) = Int32(v.value)
Base.Int64(v::AbstractDecimal) = Int64(v.value)
Base.Int128(v::AbstractDecimal) = Int128(v.value)

Base.UInt8(v::AbstractDecimal) = UInt8(v.value)
Base.UInt16(v::AbstractDecimal) = UInt16(v.value)
Base.UInt32(v::AbstractDecimal) = UInt32(v.value)
Base.UInt64(v::AbstractDecimal) = UInt64(v.value)
Base.UInt128(v::AbstractDecimal) = UInt128(v.value)

Base.Float16(v::AbstractDecimal) = Float16(v.value)
Base.Float32(v::AbstractDecimal) = Float32(v.value)
Base.Float64(v::AbstractDecimal) = Float64(v.value)

function interpret_type(::Type{<:Decimal{P,S}}) where {P,S}
    return if P <= CH_DEC32_MAX_PRECISION
        Int32
    elseif P <= CH_DEC64_MAX_PRECISION
        Int64
    elseif P <= CH_DEC128_MAX_PRECISION
        Int128
    else
        throw(ArgumentError("Decimal precision P=$P is out of range for valid Decimal types."))
    end
end

function Base.read(io::IO, ::Type{D}) where {D<:Decimal{P,S}} where {P,S}
    T = interpret_type(D)
    return Decimal{P,S}(read(io, T), -S)
end

function Base.write(io::IO, x::D) where {D<:Decimal{P,S}} where {P,S}
    T = interpret_type(D)
    sign, significand, exponent = sigexp(trunc(x.value; digits = S))
    return write(io, T(sign * significand * 10^max(0, S + exponent)))
end
