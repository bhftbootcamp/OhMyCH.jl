#__ query_parameters

using OhMyCH: stringify_value, parameters_to_strings

@testset verbose = true "Query parameters" begin
    @testset "Case №1: Nullable" begin
        @test stringify_value(nothing) == "NULL"
        @test stringify_value(missing) == "NULL"

        @test parameters_to_strings((
            null_1 = nothing,
            null_2 = missing,
        )) == [
            "param_null_1" => "\\N",
            "param_null_2" => "\\N",
        ]
    end

    @testset "Case №2: Strings" begin
        @test stringify_value("123") == "'123'"
        @test stringify_value("abc\nabc") == "'abc\\nabc'"

        @test parameters_to_strings((
            string_1 = "123",
            string_2 = "abc\nabc",
        )) == [
            "param_string_1" => "123",
            "param_string_2" => "abc\nabc",
        ]
    end

    @testset "Case №3: Dates" begin
        @test stringify_value(Date(1970, 1, 1)) == "1970-01-01"
        @test stringify_value(DateTime(1970, 1, 1, 1, 2, 3)) == "1970-01-01 01:02:03"
        @test stringify_value(NanoDate(1970, 1, 1, 1, 2, 3, 123, 456, 789)) == "1970-01-01T01:02:03.123456789"

        @test parameters_to_strings((
            date_1 = Date(1970, 1, 1),
            date_2 = DateTime(1970, 1, 1, 1, 2, 3),
            date_3 = NanoDate(1970, 1, 1, 1, 2, 3, 123, 456, 789),
        )) == [
            "param_date_1" => "1970-01-01",
            "param_date_2" => "1970-01-01 01:02:03",
            "param_date_3" => "1970-01-01T01:02:03.123456789",
        ]
    end

    @testset "Case №4: Bools" begin
        @test stringify_value(true) == "true"
        @test stringify_value(false) == "false"

        @test parameters_to_strings((
            bool_1 = true,
            bool_2 = false,
        )) == [
            "param_bool_1" => "true",
            "param_bool_2" => "false",
        ]
    end

    @testset "Case №5: Unsigned" begin
        @test stringify_value(UInt8(1)) == "1"
        @test stringify_value(UInt16(2)) == "2"
        @test stringify_value(UInt32(3)) == "3"
        @test stringify_value(UInt64(4)) == "4"
        @test stringify_value(UInt128(5)) == "5"

        @test parameters_to_strings((
            uint_1 = UInt8(1),
            uint_2 = UInt16(2),
            uint_3 = UInt32(3),
            uint_4 = UInt64(4),
            uint_5 = UInt128(5),
        )) == [
            "param_uint_1" => "1",
            "param_uint_2" => "2",
            "param_uint_3" => "3",
            "param_uint_4" => "4",
            "param_uint_5" => "5",
        ]
    end

    @testset "Case №6: Integers" begin
        @test stringify_value(Int8(-1)) == "-1"
        @test stringify_value(Int16(-2)) == "-2"
        @test stringify_value(Int32(-3)) == "-3"
        @test stringify_value(Int64(-4)) == "-4"
        @test stringify_value(Int128(-5)) == "-5"

        @test parameters_to_strings((
            int_1 = Int8(-1),
            int_2 = Int16(-2),
            int_3 = Int32(-3),
            int_4 = Int64(-4),
            int_5 = Int128(-5),
        )) == [
            "param_int_1" => "-1",
            "param_int_2" => "-2",
            "param_int_3" => "-3",
            "param_int_4" => "-4",
            "param_int_5" => "-5",
        ]
    end

    @testset "Case №7: Floats" begin
        @test stringify_value(Float16(1)) == "1.0"
        @test stringify_value(Float32(2)) == "2.0"
        @test stringify_value(Float64(3)) == "3.0"

        @test parameters_to_strings((
            float_1 = Float16(1),
            float_2 = Float32(2),
            float_3 = Float64(3),
        )) == [
            "param_float_1" => "1.0",
            "param_float_2" => "2.0",
            "param_float_3" => "3.0",
        ]
    end

    @testset "Case №8: NaN & Infs" begin
        @test stringify_value(NaN) == "nan"
        @test stringify_value(Inf) == "+inf"
        @test stringify_value(-Inf) == "-inf"

        @test parameters_to_strings((
            nan_1 = NaN,
            inf_1 = Inf,
            inf_2 = -Inf,
        )) == [
            "param_nan_1" => "nan",
            "param_inf_1" => "+inf",
            "param_inf_2" => "-inf",
        ]
    end

    @testset "Case №9: UUID & IPs" begin
        @test stringify_value(UUID("e5176dcc-7dd9-e168-5d24-edc4afc3960a")) == "e5176dcc-7dd9-e168-5d24-edc4afc3960a"
        @test stringify_value(IPv4("200.161.56.148")) == "200.161.56.148"
        @test stringify_value(IPv6("::5bb6:124a:db5c:7f3")) == "::5bb6:124a:db5c:7f3"

        @test parameters_to_strings((
            uuid = UUID("e5176dcc-7dd9-e168-5d24-edc4afc3960a"),
            ipv_4 = IPv4("200.161.56.148"),
            ipv_6 = IPv6("::5bb6:124a:db5c:7f3"),
        )) == [
            "param_uuid" => "e5176dcc-7dd9-e168-5d24-edc4afc3960a",
            "param_ipv_4" => "200.161.56.148",
            "param_ipv_6" => "::5bb6:124a:db5c:7f3",
        ]
    end

    @testset "Case №10: Dictionaries" begin
        @test stringify_value(Dict{String,Int}(
            "key_1" => 1,
            "key_2" => 2,
            "key_3" => 3,
        )) == "{'key_1':1,'key_3':3,'key_2':2}"
        @test stringify_value(Dict{Int,String}(
            1 => "key_1",
            2 => "key_2",
            3 => "key_3",
        )) == "{2:'key_2',3:'key_3',1:'key_1'}"
        @test stringify_value(Dict(
            "null" => 1,
            "map" => nothing,
            "string" => 3,
            "int" => nothing,
        )) == "{'int':NULL,'string':3,'map':NULL,'null':1}"
        @test stringify_value(Dict(
            "null" => "map",
            "string" => nothing,
        )) == "{'string':NULL,'null':'map'}"

        @test parameters_to_strings((
            dict_1 = Dict{String,Int}(
                "key_1" => 1,
                "key_2" => 2,
                "key_3" => 3,
            ),
            dict_2 = Dict{Int,String}(
                1 => "key_1",
                2 => "key_2",
                3 => "key_3",
            ),
            dict_3 = Dict(
                "null" => 1,
                "map" => nothing,
                "string" => 3,
                "int" => nothing,
            ),
            dict_4 = Dict(
                "null" => "map",
                "string" => nothing,
            ),
        )) == [
            "param_dict_1" => "{'key_1':1,'key_3':3,'key_2':2}",
            "param_dict_2" => "{2:'key_2',3:'key_3',1:'key_1'}",
            "param_dict_3" => "{'int':NULL,'string':3,'map':NULL,'null':1}",
            "param_dict_4" => "{'string':NULL,'null':'map'}",
        ]
    end

    @testset "Case №11: Vectors" begin
        @test stringify_value([true, false]) == "[true,false]"
        @test stringify_value([1, 2, 3]) == "[1,2,3]"
        @test stringify_value([1.0, 2.0, 3.0]) == "[1.0,2.0,3.0]"
        @test stringify_value([nothing, nothing, nothing]) == "[NULL,NULL,NULL]"
        @test stringify_value(["123", "456", "789"]) == "['123','456','789']"
        @test stringify_value([NaN, Inf, -Inf]) == "[nan,+inf,-inf]"
        @test stringify_value(["null", nothing, "NULL", "ᴺᵁᴸᴸ"]) == "['null',NULL,'NULL','ᴺᵁᴸᴸ']"

        @test parameters_to_strings((
            vector_1 = [true, false],
            vector_2 = [1, 2, 3],
            vector_3 = [1.0, 2.0, 3.0],
            vector_4 = [nothing, nothing, nothing],
            vector_5 = ["123", "456", "789"],
            vector_6 = [NaN, Inf, -Inf],
            vector_7 = ["null", nothing, "NULL", "ᴺᵁᴸᴸ"],
        )) == [
            "param_vector_1" => "[true,false]",
            "param_vector_2" => "[1,2,3]",
            "param_vector_3" => "[1.0,2.0,3.0]",
            "param_vector_4" => "[NULL,NULL,NULL]",
            "param_vector_5" => "['123','456','789']",
            "param_vector_6" => "[nan,+inf,-inf]",
            "param_vector_7" => "['null',NULL,'NULL','ᴺᵁᴸᴸ']"
        ]
    end

    @testset "Case №12: Tuples" begin
        @test stringify_value((1, -2, 3.0, true, NaN, Inf)) == "(1,-2,3.0,true,nan,+inf)"
        @test stringify_value((nothing, "abc", missing)) == "(NULL,'abc',NULL)"
        @test stringify_value((Dict("key" => "value"), 1, false)) == "({'key':'value'},1,false)"

        @test parameters_to_strings((
            tuple_1 = (1, -2, 3.0, true, NaN, Inf),
            tuple_2 = (nothing, "abc", missing),
            tuple_3 = (Dict("key" => "value"), 1, false),
        )) == [
            "param_tuple_1" => "(1,-2,3.0,true,nan,+inf)",
            "param_tuple_2" => "(NULL,'abc',NULL)",
            "param_tuple_3" => "({'key':'value'},1,false)",
        ]
    end
end
