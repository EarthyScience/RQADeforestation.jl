module RQADeforestation
__precompile__(false)
using Dates
using ArchGDAL: ArchGDAL as AG
using Glob
using YAXArrays
using Zarr
using Distributed: myid
using NetCDF

export gdalcube

include("auxil.jl")
include("analysis.jl")
include("timestats.jl")
end