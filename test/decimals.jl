#__ decimals

using OhMyCH.DecFP

@testset verbose = true "Decimal constructors" begin
    @testset "Case №1: Decimal from Dec32 / Dec64 / Dec128" begin
        @test Decimal{7,5}(Dec32("12.34567")) |> Float64 == 12.34567
        @test Decimal{7,3}(Dec32("1234.567")) |> Float64 == 1234.567
        @test Decimal{7,1}(Dec32("123456.7")) |> Float64 == 123456.7

        @test Decimal{16,5}(Dec64("12.34567")) |> Float64 == 12.34567
        @test Decimal{16,3}(Dec64("1234.567")) |> Float64 == 1234.567
        @test Decimal{16,1}(Dec64("123456.7")) |> Float64 == 123456.7

        @test Decimal{34,5}(Dec128("12.34567")) |> Float64 == 12.34567
        @test Decimal{34,3}(Dec128("1234.567")) |> Float64 == 1234.567
        @test Decimal{34,1}(Dec128("123456.7")) |> Float64 == 123456.7
    end

    @testset "Case №2: Decimal from Integer" begin
        @test Decimal{7,4}(123) |> Float64 == 123.0
        @test Decimal{16,11}(12345) |> Float64 == 12345.0
        @test Decimal{34,27}(1234567) |> Float64 == 1.234567e6
    end

    @testset "Case №3: Decimal from Float" begin
        @test Decimal{7,4}(123.4567) |> Float64 == 123.4567
        @test Decimal{16,11}(12345.67) |> Float64 == 12345.67
        @test Decimal{34,27}(1234567.89) |> Float64 == 1234567.89
    end

    @testset "Case №4: Decimal from String" begin
        @test Decimal{7,4}("123.4567") |> Float64 == 123.4567
        @test Decimal{16,11}("12345.67") |> Float64 == 12345.67
        @test Decimal{34,27}("1234567.89") |> Float64 == 1234567.89
    end

    @testset "Case №5: Decimal from sign, significand, exponent" begin
        @test Decimal{7,4}(123, -1) |> Float64 == 12.3
        @test Decimal{16,11}(12345, -3) |> Float64 == 12.345
        @test Decimal{34,27}(1234567, -5) |> Float64 == 12.34567

        @test Decimal{7,4}(-1, 123, -1) |> Float64 == -12.3
        @test Decimal{16,11}(-1, 12345, -3) |> Float64 == -12.345
        @test Decimal{34,27}(-1, 1234567, -5) |> Float64 == -12.34567
    end

    @testset "Case №6: Decimal from sign, significand, exponent" begin
        @test_throws ArgumentError Decimal{7,10}("0.0")
        @test_throws ArgumentError Decimal{16,20}("0.0")
        @test_throws ArgumentError Decimal{34,40}("0.0")
        @test_throws ArgumentError Decimal{50,5}("0.0")
        @test_throws ArgumentError Decimal{6,5}("12345.123")
        @test_throws ArgumentError Decimal{10,5}(Inf)
    end
end

@testset verbose = true "Decimal operations" begin
    @testset "Case №1: Zeros & ones" begin
        @test zero(Decimal{7,1}) |> Float64 == 0.0
        @test zero(Decimal{16,2}) |> Float64 == 0.0
        @test zero(Decimal{34,3}) |> Float64 == 0.0

        @test zero(Decimal{7,1}("12.34567")) |> Float64 == 0.0
        @test zero(Decimal{16,2}("12.34567")) |> Float64 == 0.0
        @test zero(Decimal{34,3}("12.34567")) |> Float64 == 0.0

        @test iszero(Decimal{7,1}("0.0"))
        @test iszero(Decimal{16,2}("0.0"))
        @test iszero(Decimal{34,3}("0.0"))

        @test !iszero(Decimal{7,1}("1.0"))
        @test !iszero(Decimal{16,2}("1.0"))
        @test !iszero(Decimal{34,3}("1.0"))

        @test one(Decimal{7,1}) |> Float64 == 1.0
        @test one(Decimal{16,2}) |> Float64 == 1.0
        @test one(Decimal{34,3}) |> Float64 == 1.0

        @test one(Decimal{7,1}("12.34567")) |> Float64 == 1.0
        @test one(Decimal{16,2}("12.34567")) |> Float64 == 1.0
        @test one(Decimal{34,3}("12.34567")) |> Float64 == 1.0

        @test isone(Decimal{7,1}("1.0"))
        @test isone(Decimal{16,2}("1.0"))
        @test isone(Decimal{34,3}("1.0"))

        @test !isone(Decimal{7,1}("0.0"))
        @test !isone(Decimal{16,2}("0.0"))
        @test !isone(Decimal{34,3}("0.0"))
    end

    @testset "Case №2: Arithmetics" begin
        @testset begin
            @test Decimal{7,1}("1.0") + 1 == Decimal{7,1}("2.0")
            @test 1 + Decimal{7,1}("1.0") == Decimal{7,1}("2.0")

            @test Decimal{7,1}("1.0") + 0.1 == Decimal{7,1}("1.1")
            @test 0.1 + Decimal{7,1}("1.0") == Decimal{7,1}("1.1")

            @test Decimal{7,1}("1.0") + Decimal{16,2}("0.1") == Decimal{16,2}("1.1")
            @test Decimal{16,2}("1.0") + Decimal{7,1}("0.1") == Decimal{16,2}("1.1")


            @test Decimal{16,2}("1.0") + 1 == Decimal{16,2}("2.0")
            @test 1 + Decimal{16,2}("1.0") == Decimal{16,2}("2.0")

            @test Decimal{16,2}("1.0") + 0.1 == Decimal{16,2}("1.1")
            @test 0.1 + Decimal{16,2}("1.0") == Decimal{16,2}("1.1")

            @test Decimal{7,1}("1.0") + Decimal{34,3}("0.1") == Decimal{34,3}("1.1")
            @test Decimal{34,3}("1.0") + Decimal{7,1}("0.1") == Decimal{34,3}("1.1")


            @test Decimal{34,3}("1.0") + 1 |> Float64 == 2.0
            @test 1 + Decimal{34,3}("1.0") |> Float64 == 2.0

            @test Decimal{34,3}("1.0") + 0.1 |> Float64 == 1.1
            @test 0.1 + Decimal{34,3}("1.0") |> Float64 == 1.1

            @test Decimal{16,2}("1.0") + Decimal{34,3}("0.1") == Decimal{34,3}("1.1")
            @test Decimal{34,3}("1.0") + Decimal{16,2}("0.1") == Decimal{34,3}("1.1")
        end

        @testset begin
            @test Decimal{7,1}("1.0") - 1 == Decimal{7,1}("0.0")
            @test 1 - Decimal{7,1}("1.0") == Decimal{7,1}("0.0")

            @test Decimal{7,1}("1.0") - 0.1 == Decimal{7,1}("0.9")
            @test 0.1 - Decimal{7,1}("1.0") == Decimal{7,1}("-0.9")

            @test Decimal{7,1}("1.0") - Decimal{16,2}("0.1") == Decimal{16,2}("0.9")
            @test Decimal{16,2}("1.0") - Decimal{7,1}("0.1") == Decimal{16,2}("0.9")


            @test Decimal{16,2}("1.0") - 1 == Decimal{16,2}("0.0")
            @test 1 - Decimal{16,2}("1.0") == Decimal{16,2}("0.0")

            @test Decimal{16,2}("1.0") - 0.1 == Decimal{16,2}("0.9")
            @test 0.1 - Decimal{16,2}("1.0") == Decimal{16,2}("-0.9")

            @test Decimal{7,1}("1.0") - Decimal{34,3}("0.1") == Decimal{34,3}("0.9")
            @test Decimal{34,3}("1.0") - Decimal{7,1}("0.1") == Decimal{34,3}("0.9")


            @test Decimal{34,3}("1.0") - 1 |> Float64 == 0.0
            @test 1 - Decimal{34,3}("1.0") |> Float64 == 0.0

            @test Decimal{34,3}("1.0") - 0.1 |> Float64 == 0.9
            @test 0.1 - Decimal{34,3}("1.0") |> Float64 == -0.9

            @test Decimal{16,2}("1.0") - Decimal{34,3}("0.1") == Decimal{34,3}("0.9")
            @test Decimal{34,3}("1.0") - Decimal{16,2}("0.1") == Decimal{34,3}("0.9")
        end

        @testset begin
            @test Decimal{7,1}("2.0") * 3 == Decimal{7,1}("6.0")
            @test 3 * Decimal{7,1}("2.0") == Decimal{7,1}("6.0")

            @test Decimal{7,1}("2.0") * 3.0 == Decimal{7,1}("6.0")
            @test 3.0 * Decimal{7,1}("2.0") == Decimal{7,1}("6.0")

            @test Decimal{7,1}("2.0") * Decimal{16,2}("3.0") == Decimal{16,2}("6.0")
            @test Decimal{16,2}("2.0") * Decimal{7,1}("3.0") == Decimal{16,2}("6.0")


            @test Decimal{16,2}("2.0") * 3 == Decimal{16,2}("6.0")
            @test 3 * Decimal{16,2}("2.0") == Decimal{16,2}("6.0")

            @test Decimal{16,2}("2.0") * 3.0 == Decimal{16,2}("6.0")
            @test 3.0 * Decimal{16,2}("2.0") == Decimal{16,2}("6.0")

            @test Decimal{7,1}("2.0") * Decimal{34,3}("3.0") == Decimal{34,3}("6.0")
            @test Decimal{34,3}("2.0") * Decimal{7,1}("3.0") == Decimal{34,3}("6.0")


            @test Decimal{34,3}("2.0") * 3 |> Float64 == 6.0
            @test 3 * Decimal{34,3}("2.0") |> Float64 == 6.0

            @test Decimal{34,3}("2.0") * 3.0 |> Float64 == 6.0
            @test 3.0 * Decimal{34,3}("2.0") |> Float64 == 6.0

            @test Decimal{16,2}("2.0") * Decimal{34,3}("3.0") == Decimal{34,3}("6.0")
            @test Decimal{34,3}("2.0") * Decimal{16,2}("3.0") == Decimal{34,3}("6.0")
        end

        @testset begin
            @test Decimal{7,1}("2.0") / 1 == Decimal{7,1}("2.0")
            @test 1 / Decimal{7,1}("2.0") == Decimal{7,1}("0.5")

            @test Decimal{7,1}("2.0") / 1.0 == Decimal{7,1}("2.0")
            @test 1.0 / Decimal{7,1}("2.0") == Decimal{7,1}("0.5")

            @test Decimal{7,1}("2.0") / Decimal{16,2}("1.0") == Decimal{16,2}("2.0")
            @test Decimal{16,2}("2.0") / Decimal{7,1}("1.0") == Decimal{16,2}("2.0")


            @test Decimal{16,2}("2.0") / 1 == Decimal{16,2}("2.0")
            @test 1 / Decimal{16,2}("2.0") == Decimal{16,2}("0.5")

            @test Decimal{16,2}("2.0") / 1.0 == Decimal{16,2}("2.0")
            @test 1.0 / Decimal{16,2}("2.0") == Decimal{16,2}("0.5")

            @test Decimal{7,1}("2.0") / Decimal{34,3}("1.0") == Decimal{34,3}("2.0")
            @test Decimal{34,3}("2.0") / Decimal{7,1}("1.0") == Decimal{34,3}("2.0")


            @test Decimal{34,3}("2.0") / 1 |> Float64 == 2.0
            @test 1 / Decimal{34,3}("2.0") |> Float64 == 0.5

            @test Decimal{34,3}("2.0") / 1.0 |> Float64 == 2.0
            @test 1.0 / Decimal{34,3}("2.0") |> Float64 == 0.5

            @test Decimal{16,2}("2.0") / Decimal{34,3}("1.0") == Decimal{34,3}("2.0")
            @test Decimal{34,3}("2.0") / Decimal{16,2}("1.0") == Decimal{34,3}("2.0")
        end

        @testset begin
            @test Decimal{7,1}("2.0") ^ 3 == Decimal{7,1}("8.0")
            @test 3 ^ Decimal{7,1}("2.0") == Decimal{7,1}("9.0")

            @test Decimal{7,1}("2.0") ^ 3.0 == Decimal{7,1}("8.0")
            @test 3 ^ Decimal{7,1}("2.0") == Decimal{7,1}("9.0")

            @test Decimal{7,1}("2.0") ^ Decimal{16,2}("3.0") == Decimal{16,2}("8.0")
            @test Decimal{16,2}("2.0") ^ Decimal{7,1}("3.0") == Decimal{16,2}("8.0")


            @test Decimal{16,2}("2.0") ^ 3 == Decimal{16,2}("8.0")
            @test 3 ^ Decimal{16,2}("2.0") == Decimal{16,2}("9.0")

            @test Decimal{16,2}("2.0") ^ 3.0 == Decimal{16,2}("8.0")
            @test 3.0 ^ Decimal{16,2}("2.0") == Decimal{16,2}("9.0")

            @test Decimal{7,1}("2.0") ^ Decimal{34,3}("3.0") == Decimal{34,3}("8.0")
            @test Decimal{34,3}("2.0") ^ Decimal{7,1}("3.0") == Decimal{34,3}("8.0")


            @test Decimal{34,3}("2.0") ^ 3 |> Float64 == 8.0
            @test 3 ^ Decimal{34,3}("2.0") |> Float64 == 9.0

            @test Decimal{34,3}("2.0") ^ 3.0 |> Float64 == 8.0
            @test 3.0 ^ Decimal{34,3}("2.0") |> Float64 == 9.0

            @test Decimal{16,2}("2.0") ^ Decimal{34,3}("3.0") == Decimal{34,3}("8.0")
            @test Decimal{34,3}("2.0") ^ Decimal{16,2}("3.0") == Decimal{34,3}("8.0")
        end
    end

    @testset "Case №3: Comparison" begin
        @test Decimal{5,1}("1.0") < 1.1
        @test !(Decimal{6,1}("1.0") > 1.1)
        @test Decimal{7,1}("1.0") <= 1.1
        @test !(Decimal{8,1}("1.0") >= 1.1)
        @test Decimal{9,1}("1.0") == 1.0
        @test !(Decimal{10,1}("1.0") == 1.1)
        @test Decimal{11,1}("1.0") != 1.1
        @test !(Decimal{12,1}("1.0") != 1.0)

        @test Decimal{5,1}("1.0") < Decimal{5,1}("1.1")
        @test !(Decimal{6,1}("1.0") > Decimal{6,1}("1.1"))
        @test Decimal{7,1}("1.0") <= Decimal{7,1}("1.1")
        @test !(Decimal{8,1}("1.0") >= Decimal{8,1}("1.1"))
        @test Decimal{9,1}("1.0") == Decimal{9,1}("1.0")
        @test !(Decimal{10,1}("1.0") == Decimal{10,1}("1.1"))
        @test Decimal{11,1}("1.0") != Decimal{11,1}("1.1")
        @test !(Decimal{12,1}("1.0") != Decimal{12,1}("1.0"))

        @test isless(Decimal{7,1}("1.0"), 1.1)
        @test !isless(1.1, Decimal{7,1}("1.0"))

        @test isless(Decimal{7,1}("1.0"), 2)
        @test !isless(2, Decimal{7,1}("1.0"))

        @test !isless(Decimal{7,1}("1.1"), Decimal{7,1}("1.0"))
        @test isless(Decimal{7,1}("1.0"), Decimal{7,1}("1.1"))

        @test !isless(Decimal{7,1}("1.1"), Decimal{16,2}("1.0"))
        @test isless(Decimal{7,1}("1.0"), Decimal{34,3}("1.1"))

        @test isequal(Decimal{7,1}("1.0"), 1.0)
        @test !isequal(1.1, Decimal{7,1}("1.0"))

        @test isequal(Decimal{7,1}("1.0"), 1)
        @test !isequal(1, Decimal{7,1}("1.1"))

        @test isequal(Decimal{7,1}("1.0"), Decimal{7,1}("1.0"))
        @test !isequal(Decimal{7,1}("1.0"), Decimal{7,1}("1.1"))

        @test isequal(Decimal{7,1}("1.0"), Decimal{16,2}("1.0"))
        @test !isequal(Decimal{34,3}("1.1"), Decimal{7,1}("1.0"))
    end

    @testset "Case №4: Math" begin
        x = Decimal{7,1}("1.0")

        @test inv(x)   == Decimal{7,1}("1.0")
        @test sqrt(x)  == Decimal{7,1}("1.0")
        @test log(x)   == Decimal{7,1}("0.0")
        @test log10(x) == Decimal{7,1}("0.0")
        @test log2(x)  == Decimal{7,1}("0.0")
        @test log1p(x) == Decimal{7,1}("0.6931472")
        @test exp(x)   == Decimal{7,1}("2.718282")
        @test exp2(x)  == Decimal{7,1}("2.0")
        @test exp10(x) == Decimal{7,1}("10.0")
        @test expm1(x) == Decimal{7,1}("1.718282")

        x = Decimal{7,1}("0.5")

        @test sin(x)  == Decimal{7,1}("0.4794255")
        @test cos(x)  == Decimal{7,1}("0.8775826")
        @test tan(x)  == Decimal{7,1}("0.5463025")
        @test asin(x) == Decimal{7,1}("0.5235988")
        @test acos(x) == Decimal{7,1}("1.047198")
        @test atan(x) == Decimal{7,1}("0.4636476")
        @test sinh(x) == Decimal{7,1}("0.5210953")
        @test cosh(x) == Decimal{7,1}("1.127626")
        @test tanh(x) == Decimal{7,1}("0.4621172")

        x = Decimal{7,1}("1.0")

        @test asinh(x) == Decimal{7,1}("0.8813736")
        @test acosh(x) == Decimal{7,1}("0.0")

        x = Decimal{7,1}("0.5")

        @test atanh(x) == Decimal{7,1}("0.5493061")
    end

    @testset "Case №5: Rounding" begin
        @test round(Decimal{7,1}("1234.567")) == Decimal{7,1}(1235.0)
        @test round(Decimal{7,1}("1234.567"), RoundDown) == Decimal{7,1}(1234.0)
        @test round(Decimal{7,1}("1234.567"), RoundUp) == Decimal{7,1}(1235.0)

        @test round(Int, Decimal{7,1}("1234.567")) == 1235
        @test round(Int, Decimal{7,1}("1234.567"), RoundDown) == 1234
        @test round(Int, Decimal{7,1}("1234.567"), RoundUp) == 1235

        @test trunc(Decimal{7,1}("1234.567")) == Decimal{7,1}(1234.0)
        @test trunc(Int, Decimal{7,1}("1234.567")) == 1234
    end

    @testset "Case №6: Other utils" begin
        x = Decimal{7,1}("1234.567")

        @test signbit(x) == false
        @test sign(x) == 1
        @test significand(x) == 1234567
        @test exponent(x) == -3
    end

    @testset "Case №7: Conversion" begin
        x = Decimal{7,1}("123")

        @test Int8(x) == Int8(123)
        @test Int16(x) == Int16(123)
        @test Int32(x) == Int32(123)
        @test Int64(x) == Int64(123)
        @test Int128(x) == Int128(123)

        @test UInt8(x) == UInt8(123)
        @test UInt16(x) == UInt16(123)
        @test UInt32(x) == UInt32(123)
        @test UInt64(x) == UInt64(123)
        @test UInt128(x) == UInt128(123)

        x = Decimal{7,1}("1234.567")

        @test Float16(x) == Float16(1234.567)
        @test Float32(x) == Float32(1234.567)
        @test Float64(x) == Float64(1234.567)
    end

    @testset "Case №8: IO" begin
        io = IOBuffer()

        @test write(io, Decimal{7,1}("12.3")) == 4
        @test write(io, Decimal{16,2}("123.45")) == 8
        @test write(io, Decimal{34,3}("1234.567")) == 16

        @test write(io, Decimal{7,1}("-12.3456")) == 4
        @test write(io, Decimal{5,3}("-1.4578")) == 4
        @test write(io, Decimal{6,4}("-1.5")) == 4

        seekstart(io)

        @test read(io, Decimal{7,1}) == Decimal{7,1}("12.3")
        @test read(io, Decimal{16,2}) == Decimal{16,2}("123.45")
        @test read(io, Decimal{34,3}) == Decimal{34,3}("1234.567")

        @test read(io, Decimal{7,1}) == Decimal{7,1}("-12.3")
        @test read(io, Decimal{5,3}) == Decimal{5,3}("-1.457")
        @test read(io, Decimal{6,4}) == Decimal{6,4}("-1.5")
    end
end
