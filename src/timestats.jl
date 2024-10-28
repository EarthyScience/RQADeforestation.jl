using Statistics
using StatsBase

function timestats(cube; path=tempname())

    indims = InDims("Time")
    funcs = ["Mean", "5th Quantile", "25th Quantile", "Median", "75th Quantile", "95th Quantile",
        "Standard Deviation",
        "Minimum", "Maximum",
        "Skewness", "Kurtosis", "Median Absolute Deviation"]

    stataxis = CategoricalAxis("Stats", funcs)
    od = OutDims(stataxis, path=path)
    stats = mapCube(ctimestats!, cube, indims=indims, outdims=od)
end

function ctimestats!(xout, xin)
    x = collect(skipmissing(xin))
    ts = x[.!isnan.(x)]
    #    m = mean(ts)
    #    T = eltype(m)
    #stats = Vector{T}(undef,12)
    if isempty(ts)
        xout .= NaN
    else
        xout[1] = mean(ts)
        xout[2:6] .= quantile(ts, [0.05, 0.25, 0.5, 0.75, 0.95])
        xout[7] = std(ts)
        xout[2] = minimum(ts)
        xout[3] = maximum(ts)
        #       stats[10] = skewness(ts)
        #      stats[11] = kurtosis(ts)
        #     stats[12] = mad(ts, normalize=true)
    end
    #xout .=stats
    nothing
end