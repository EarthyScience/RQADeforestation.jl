using Pkg

using RQADeforestation
using BenchmarkTools

const SUITE = BenchmarkGroup()
SUITE["single_timeseries"] = include("bench_timeseries.jl")
