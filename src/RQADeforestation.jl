module RQADeforestation
#__precompile__(false)
using Dates
using ArchGDAL: ArchGDAL as AG
using Glob
using YAXArrays
using Zarr
using Distributed: myid
using NetCDF
using TestItems

export gdalcube, rqatrend

include("metrics.jl")
include("auxil.jl")
include("rqatrend.jl")
include("analysis.jl")  # TODO what is still needed from analysis now that rqatrend is in its own file?
include("cluster.jl")
include("timestats.jl")
include("main.jl")

end