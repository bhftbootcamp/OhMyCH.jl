# runtests

using Test
using OhMyCH
using Dates, NanoDates, UUIDs, Sockets

include("decimals.jl")
include("fixed_strings.jl")
include("column_types.jl")
include("query_parameters.jl")
include("serialization.jl")
