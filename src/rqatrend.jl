using LinearAlgebra
using StaticArrays
using Distances


"""rqatrend(cube;thresh=2, path=tempname() * ".zarr")

Compute the RQA trend metric for the datacube `cube` with the epsilon threshold `thresh`.
"""
function rqatrend(cube; thresh=2, outpath=tempname() * ".zarr", overwrite=false, kwargs...)
    @show outpath
    mapCube(rqatrend, cube, thresh; indims=InDims("Time"), outdims=OutDims(; outtype=Float32, path=outpath, overwrite, kwargs...))
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
    @test diff < 0.5
end

"""rqatrend(path::AbstractString; thresh=2, outpath=tempname()*".zarr")

Compute the RQA trend metric for the data that is available on `path`.
"""
rqatrend(path::AbstractString; thresh=2, outpath=tempname() * ".zarr", overwrite=false, kwargs...) = rqatrend(Cube(path); thresh, outpath, overwrite, kwargs...)


"""
rqatrend(xout, xin, thresh)

Compute the RQA trend metric for the non-missing time steps of xin, and save it to xout. 
`thresh` specifies the epsilon threshold of the Recurrence Plot computation
"""
function rqatrend(pix_trend, pix, thresh=2)
    pix_trend .= rqatrend_impl(pix; thresh)
end


function rqatrend_impl(data; thresh=2, border=10, theiler=1, metric=CheckedEuclidean())
    # simplified implementation of https://stats.stackexchange.com/a/370175 and https://github.com/joshday/OnlineStats.jl/blob/b89a99679b13e3047ff9c93a03c303c357931832/src/stats/linreg.jl
    # x is the diagonal offset, y the percentage of local recurrence
    # we compute the slope of a simple linear regression with bias from x to y
    xs = 1+theiler : length(data)-border
    x_mean = mean(xs)
    xx_mean = sqmean_step1_range(xs) # mean(x*x for x in xs)

    n = 0.0
    y_mean = 0.0
    xy_mean = 0.0
    for x in xs
        n += 1.0
        y = tau_rr(data, x; thresh, metric)
        y_mean = smooth(y_mean, y, inv(n))
        xy_mean = smooth(xy_mean, x*y, inv(n))
    end
    A = SA[ 
        xx_mean x_mean
        x_mean  1.0
    ]
    b = SA[xy_mean, y_mean]
    # OnlineStats uses `Symmetric(A) \ b`, however this does not work for StaticArrays
    # `cholesky(A) \ b` is recommended instead at discourse https://discourse.julialang.org/t/staticarrays-solve-symmetric-linear-system-seems-typeinstable/124634
    # some timings show that there is no significant speedup when adding cholesky or doing plain static linear regression
    # hence leaving it out for now
    return 1000.0*(A \ b)[1]  # slope
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
            nominator += evaluate(metric, y[i], y[i+d]) <= thresh
            denominator += 1
        end
        return nominator/denominator
    end
end

function sqmean_step1_range(xs) 
    a = first(xs)
    b = last(xs)
    return (sumofsquares(b) - sumofsquares(a - 1.0)) / length(xs)
end

sumofsquares(n) = n*(n+1.0)*(2.0*n+1.0)/6.0
sumofsquares(4)

"""
    smooth(a, b, γ)

Weighted average of `a` and `b` with weight `γ`.

``(1 - γ) * a + γ * b``
"""
smooth(a, b, γ) = a + γ * (b - a)
