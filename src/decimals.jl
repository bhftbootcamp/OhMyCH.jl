const DecimalFP = DecimalFloatingPoint

const JL_DEC32_MAX_PRECISION  = 7
const JL_DEC64_MAX_PRECISION  = 16
const JL_DEC128_MAX_PRECISION = 34

const CH_DEC32_MAX_PRECISION  = 9
const CH_DEC64_MAX_PRECISION  = 18
const CH_DEC128_MAX_PRECISION = 38

"""
    AbstractDecimal{P,S} <: AbstractFloat

Abstract supertype for fixed-point decimal numbers with precision `P` and scale `S`.

See also [`Decimal`](@ref).
"""
abstract type AbstractDecimal{P,S} <: AbstractFloat end

function _validate_ps(P::Integer, S::Integer)
    1 <= P <= JL_DEC128_MAX_PRECISION || throw(ArgumentError("Decimal precision P must be in range [1, $JL_DEC128_MAX_PRECISION], got $P"))
    0 <= S <= P || throw(ArgumentError("Decimal scale S must be in range [0, P=$P], got $S"))
end

function _make_decimal(P::Integer, S::Integer, args...)
    _validate_ps(P, S)
    d = if P <= JL_DEC32_MAX_PRECISION
        Dec32(args...)
    elseif P <= JL_DEC64_MAX_PRECISION
        Dec64(args...)
    else
        Dec128(args...)
    end
    isinf(d) && throw(ArgumentError("Infinity Decimals are unsupported."))
    _, sig, exp = sigexp(d)
    if !(ndigits(sig) + exp <= max(1, P - S))
        throw(ArgumentError(
            "Decimal value $d exceeds limits for Decimal{P=$P,S=$S}. " *
            "Max allowed: ±$(repeat('9', P - S)).$(repeat('9', S))."
        ))
    end
    return d
end

"""
    Decimal{P,S} <: AbstractFloat

Fixed-precision decimal number with precision `P` (total digits) and scale `S` (digits after point).

## Examples

```julia-repl
julia> Decimal{5,2}(123.45)
Decimal{5,2}(123.45)

julia> Decimal{5,2}("123.45")
Decimal{5,2}(123.45)

julia> Decimal{5,2}(12345, -2)
Decimal{5,2}(123.45)
```
"""
struct Decimal{P,S,D<:DecimalFP} <: AbstractDecimal{P,S}
    value::D

    function Decimal{P,S}(v::Union{Real,AbstractString}) where {P,S}
        d = _make_decimal(P, S, v)
        new{P,S,typeof(d)}(d)
    end

    function Decimal{P,S}(sign::Integer, sig::Integer, exp::Integer) where {P,S}
        d = _make_decimal(P, S, sign, sig, exp)
        new{P,S,typeof(d)}(d)
    end

    function Decimal{P,S}(sig::Integer, exp::Integer) where {P,S}
        Decimal{P,S}(sign(sig), sig, exp)
    end
end

Base.print(io::IO, x::Decimal) = print(io, x.value)
Base.show(io::IO, x::Decimal{P,S}) where {P,S} = print(io, "Decimal{$P,$S}(", x, ")")

# comparison

for op in (:isless, :isequal, :(<), :(==))
    @eval Base.$op(x::AbstractDecimal, y::AbstractDecimal) = Base.$op(x.value, y.value)
    @eval Base.$op(x::AbstractDecimal, y::AbstractFloat) = Base.$op(x.value, y)
    @eval Base.$op(x::AbstractFloat, y::AbstractDecimal) = Base.$op(x, y.value)
    @eval Base.$op(x::AbstractDecimal, y::Integer) = Base.$op(x.value, y)
    @eval Base.$op(x::Integer, y::AbstractDecimal) = Base.$op(x, y.value)
end

# promotion & conversion

function Base.promote_rule(::Type{<:Decimal{P1,S1}}, ::Type{<:Decimal{P2,S2}}) where {P1,S1,P2,S2}
    Decimal{max(P1, P2),max(S1, S2)}
end

Base.promote_rule(::Type{<:Decimal{P,S}}, ::Type{<:Number}) where {P,S} = Decimal{P,S}

function Base.convert(::Type{<:Decimal{P1,S1}}, v::Decimal{P2,S2}) where {P1,S1,P2,S2}
    Decimal{max(P1, P2),max(S1, S2)}(v.value)
end

Base.convert(::Type{T}, v::AbstractDecimal) where {T<:Number} = T(v.value)

# arithmetic

for op in (:+, :-, :*, :/, :^)
    @eval Base.$op(x::D1, y::D2) where {D1<:Decimal,D2<:Decimal} =
        promote_rule(D1, D2)(Base.$op(x.value, y.value))
end

# math

for f in (:inv, :sqrt, :log, :log10, :log2, :log1p, :exp, :exp2, :exp10, :expm1,
          :sin, :cos, :tan, :asin, :acos, :atan,
          :sinh, :cosh, :tanh, :asinh, :acosh, :atanh)
    @eval Base.$f(x::Decimal{P,S}) where {P,S} = Decimal{P,S}(Base.$f(x.value))
end

# rounding

function Base.round(x::Decimal{P,S}, r::RoundingMode = RoundNearest; kw...) where {P,S}
    Decimal{P,S}(Base.round(x.value, r; kw...))
end

Base.round(::Type{T}, x::AbstractDecimal, r::RoundingMode = RoundNearest) where {T<:Integer} =
    Base.round(T, x.value, r)

function Base.trunc(x::Decimal{P,S}; kw...) where {P,S}
    Decimal{P,S}(Base.trunc(x.value; kw...))
end

Base.trunc(::Type{T}, x::AbstractDecimal) where {T} = Base.trunc(T, x.value)

# constants

Base.one(::Type{Decimal{P,S}}) where {P,S}  = Decimal{P,S}(1)
Base.one(::Decimal{P,S}) where {P,S}        = Decimal{P,S}(1)
Base.zero(::Type{Decimal{P,S}}) where {P,S} = Decimal{P,S}(0)
Base.zero(::Decimal{P,S}) where {P,S}       = Decimal{P,S}(0)
Base.iszero(x::Decimal) = x == zero(x)

# decomposition

Base.signbit(x::AbstractDecimal)    = signbit(x.value)
Base.sign(x::AbstractDecimal)       = sigexp(x.value)[1]
Base.significand(x::AbstractDecimal) = sigexp(x.value)[2]
Base.exponent(x::AbstractDecimal)   = sigexp(x.value)[3]

# type conversions

for T in (:Int8, :Int16, :Int32, :Int64, :Int128,
          :UInt8, :UInt16, :UInt32, :UInt64, :UInt128,
          :Float16, :Float32, :Float64)
    @eval Base.$T(x::AbstractDecimal) = $T(x.value)
end

# ClickHouse wire type

function _wire_type(::Type{<:Decimal{P}}) where {P}
    P <= CH_DEC32_MAX_PRECISION  && return Int32
    P <= CH_DEC64_MAX_PRECISION  && return Int64
    P <= CH_DEC128_MAX_PRECISION && return Int128
    throw(ArgumentError("Decimal precision P=$P is out of range for valid Decimal types."))
end

function Base.read(io::IO, ::Type{D}) where {D<:Decimal{P,S}} where {P,S}
    Decimal{P,S}(read(io, _wire_type(D)), -S)
end

function Base.write(io::IO, x::D) where {D<:Decimal{P,S}} where {P,S}
    s, sig, exp = sigexp(trunc(x.value; digits = S))
    write(io, _wire_type(D)(s * sig * 10^max(0, S + exp)))
end
