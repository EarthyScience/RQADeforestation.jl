using LinearAlgebra
using StaticArrays
using Distances


"""rqatrend(cube;thresh=2, path=tempname() * ".zarr")

Compute the RQA trend metric for the datacube `cube` with the epsilon threshold `thresh`.
`lowerbound` and `upperbound` are forwarded to the classification of the RQA Trend result.
"""
function rqatrend(cube; thresh=2, lowerbound=-5, upperbound=-0.5, outpath=tempname() * ".zarr", overwrite=false, kwargs...)
    mapCube(rqatrend, cube, thresh, lowerbound, upperbound; indims=InDims("Time"), outdims=OutDims(; outtype=UInt8, path=outpath, fill_value=255, overwrite, kwargs...))
end

@testitem "rqatrend cube" begin
    using YAXArrays
    using Dates
    using DimensionalData: Ti, X, Y
    using Statistics
    import Random
    Random.seed!(1234)

    mock_axes = (
        Ti(Date("2022-01-01"):Day(1):Date("2022-01-30")),
        X(range(1, 10, length=10)),
        Y(range(1, 5, length=15)),
    )
    mock_data = rand(30, 10, 15)
    mock_props = Dict()
    mock_cube = YAXArray(mock_axes, mock_data, mock_props)

    mock_trend = rqatrend(mock_cube; thresh=0.5)
    @test mock_trend.axes == (mock_cube.X, mock_cube.Y)
    diff = abs(mean(mock_trend))
    @test diff < 254
end

"""rqatrend(path::AbstractString; thresh=2, outpath=tempname()*".zarr")

Compute the RQA trend metric for the data that is available on `path`.
See the `rqatrend` for a YAXArray for the description of the parameters.
"""
rqatrend(path::AbstractString; thresh=2, lowerbound=-5., upperbound=-0.5, outpath=tempname() * ".zarr", overwrite=false, kwargs...) = 
    rqatrend(Cube(path); thresh, lowerbound, upperbound, outpath, overwrite, kwargs...)


"""
rqatrend(xout, xin, thresh)

Compute the RQA trend metric for the non-missing time steps of xin, and save it to xout. 
`thresh` specifies the epsilon threshold of the Recurrence Plot computation.
`lowerbound` and `upperbound` are the bounds of the classification into UInt8.
The result of rqatrend are UInt8 values between 0 (no change) to 254 (definitive change) with 255 as sentinel value for missing data.
"""
function rqatrend(pix_trend, pix, thresh=2, lowerbound=-5., upperbound=-0.5)
    pix_trend .= classify_rqatrend(rqatrend_impl(pix; thresh); lowerbound, upperbound)
end

"""
    classify_rqatrend(trend; lowerbound=Float32(-5.0), upperbound=Float32(-0.5)))
Classify the rqatrend and put it into 254 bins so that they can fit into a UInt8 encoding.
This is a compromise between data storage and accuracy of the change detection.
The value range is 0 (no change) to 254 (definitive change) with 255 kept free as a Sentinel value for missing data.
"""
function classify_rqatrend(trend; lowerbound=Float32(-5.0), upperbound=Float32(-0.5))
    isnan(trend) && return UInt8(255)
    ctrend = clamp(trend, lowerbound, upperbound)
    rlength = upperbound - lowerbound
    return round(UInt8, 254-((ctrend - lowerbound) / rlength) * 254)
end

@testitem "classify_rqatrend" begin
    import AllocCheck
    @test RQADeforestation.classify_rqatrend(-4.999) === UInt8(254)
    @test RQADeforestation.classify_rqatrend(1) === UInt8(0)
    @test RQADeforestation.classify_rqatrend(-0.52) === UInt8(1)
    @test RQADeforestation.classify_rqatrend(-6) === UInt8(254)
    @test isempty( AllocCheck.check_allocs(RQADeforestation.classify_rqatrend, (Float32,)))
end

function rqatrend_impl(data; thresh=2, border=10, theiler=1, metric=CheckedEuclidean())
    # simplified implementation of https://stats.stackexchange.com/a/370175 and https://github.com/joshday/OnlineStats.jl/blob/b89a99679b13e3047ff9c93a03c303c357931832/src/stats/linreg.jl
    # x is the diagonal offset, y the percentage of local recurrence
    # we compute the slope of a simple linear regression with bias from x to y
    xs = 1+theiler:length(data)-border
    x_mean = mean(xs)
    xx_mean = sqmean_step1_range(xs) # mean(x*x for x in xs)

    # while xs are Int, the means are all modelled as Float64
    # this seems to give very overall top performance while being most consice in code 
    n = 0.0
    y_mean = 0.0
    xy_mean = 0.0
    for x in xs
        n += 1.0
        y = tau_rr(data, x; thresh, metric)
        y_mean = smooth(y_mean, y, inv(n))
        xy_mean = smooth(xy_mean, x * y, inv(n))
    end
    A = SA_F64[
        xx_mean x_mean
        x_mean 1.0
    ]
    b = SA_F64[xy_mean, y_mean]
    # OnlineStats uses `Symmetric(A) \ b`, however this does not work for StaticArrays
    # `cholesky(A) \ b` is recommended instead at discourse https://discourse.julialang.org/t/staticarrays-solve-symmetric-linear-system-seems-typeinstable/124634
    # some timings show that there is no significant speedup when adding cholesky or doing plain static linear regression
    # hence leaving it out for now
    return 1000.0 * (A\b)[1]  # slope
end


@testitem "rqatrend_impl" begin
    import AllocCheck
    import Random
    Random.seed!(1234)

    x = 1:0.01:30
    y = sin.(x) + 0.1x + rand(length(x))

    @test isapprox(RQADeforestation.rqatrend_impl(y; thresh=0.5), -0.11125611687816017)
    @test isempty(AllocCheck.check_allocs(RQADeforestation.rqatrend_impl, Tuple{Vector{Float64}}))

    y2 = similar(y, Union{Float64,Missing})
    copy!(y2, y)
    y2[[1, 4, 10, 20, 33, 65]] .= missing

    @test isapprox(RQADeforestation.rqatrend_impl(y2; thresh=0.5), -0.11069045524336744)
    @test isempty(AllocCheck.check_allocs(RQADeforestation.rqatrend_impl, Tuple{Vector{Union{Float64,Missing}}}))
end


function tau_rr(y, d; thresh=2, metric=CheckedEuclidean())
    _thresh = convert(eltype(y), thresh)
    # d starts counting at 1, so this is the middle diagonal (similar to tau_recurrence implementation, where the first index is always 1.0, i.e. represents the middle diagonal)
    # for the computation starting at 0 is more intuitive
    d -= 1
    if d == 0
        return 1.0
    else
        # `sum/n` is almost twice as fast as using `mean`, but sum is probably numerically less accurate
        nominator = 0
        denominator = 0
        @inbounds for i in 1:length(y)-d
            if y[i] === missing || y[i+d] === missing
                continue
            end
            nominator += evaluate(metric, y[i], y[i+d]) <= _thresh
            denominator += 1
        end
        return nominator / denominator
    end
end

function sqmean_step1_range(xs)
    # assumes xs contains Int for optimal performance
    a = first(xs)
    b = last(xs)
    return (sumofsquares(b) - sumofsquares(a - 1)) / length(xs)
end

# assumes n is Int for optimal performance
sumofsquares(n) = n * (n + 1) * (2 * n + 1) / 6

"""
    smooth(a, b, γ)

Weighted average of `a` and `b` with weight `γ`.

``(1 - γ) * a + γ * b``
"""
smooth(a, b, γ) = a + γ * (b - a)

"""
prange(xout, xin)

Compute the percentile range for the non-missing time steps of xin, and save it to xout.
`lowerpercentile` and `upperpercentile` specify the boundary of the percentile range. 
These have to be between 0 and 1. 
"""
function prange(xout, xin, lowpercentile=0.02, upperpercentile=0.98)
    xinfiltered = filter(!ismissing, xin)
    filter!(!isnan, xinfiltered)
    lowerlim, upperlim = quantile(xinfiltered, [lowpercentile, upperpercentile])
    xout .= upperlim - lowerlim
end

function prange(cube; lowerpercentile=0.02, upperpercentile=0.98, outpath=tempname() * ".zarr", overwrite=false, kwargs...)
    mapCube(prange, cube, lowerpercentile, upperpercentile; indims=InDims("Time"), outdims=OutDims(; outtype=Float32, path=outpath, fill_value=NaN, overwrite, kwargs...))
end

@testitem "prange cube" begin
    using YAXArrays
    using Dates
    using DimensionalData: Ti, X, Y
    using Statistics
    import Random
    Random.seed!(1234)

    mock_axes = (
        Ti(Date("2022-01-01"):Day(1):Date("2022-01-01")+ Day(100)),
        X(range(1, 10, length=10)),
        Y(range(1, 5, length=15)),
    )
    s = size(mock_axes)
    mock_data = reshape(1:prod(s), s)
    mock_props = Dict()
    mock_cube = YAXArray(mock_axes, mock_data, mock_props)

    mock_trend = prange(mock_cube)
    @test mock_trend.axes == (mock_cube.X, mock_cube.Y)
    @test mock_trend[1,1] == 96
end