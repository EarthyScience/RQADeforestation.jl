using RecurrenceAnalysis: RecurrenceAnalysis as RA
using Distances
import RecurrenceAnalysis: tau_recurrence

"""
countvalid(xout, xin)

    Inner function to count the valid time steps in a datacube.
    This function is aimed to be used inside of a mapCube call.
"""
function countvalid(xout, xin)
    xout .= count(!ismissing, xin)
end

"""
countvalid(cube)

    Outer function to count the number of valid time steps in a cube.
"""
countvalid(cube; path=tempname() * ".zarr") = mapCube(countvalid, cube; indims=InDims("Time", filter=YAXArrays.DAT.NoFilter()), outdims=OutDims(; path))

@testitem "countvalid cube" begin
    using RQADeforestation
    using YAXArrays
    using Dates
    using DimensionalData: Ti, X, Y
    using Statistics
    import Random
    using Missings
    Random.seed!(1234)

    mock_axes = (
        Ti(Date("2022-01-01"):Day(1):Date("2022-01-30")),
        X(range(1, 10, length=10)),
        Y(range(1, 5, length=15)),
    )
    mock_data = allowmissing(rand(30, 10, 15))
    mock_data[1:10,1,1] .= missing
    mock_data[:, 2,1] .= missing
    mock_data[[1,5,9], 2,2] .= missing
    mock_props = Dict()
    mock_cube = YAXArray(mock_axes, mock_data, mock_props)

    mock_count = RQADeforestation.countvalid(mock_cube)
    @test mock_count.axes == (mock_cube.X, mock_cube.Y)
    @test mock_count[1,1] == 20
    @test mock_count[1,2] == 30
    @test mock_count[2,2] == 27
    @test mock_count[2,1] == 0
end

"""
rqatrend(xout, xin, thresh)

Compute the RQA trend metric for the non-missing time steps of xin, and save it to xout. 
`thresh` specifies the epsilon threshold of the Recurrence Plot computation
"""
function rqatrend_recurrenceanalysis(pix_trend, pix, thresh=2)
    ts = collect(skipmissing(pix))
    tau_pix = tau_recurrence(ts, thresh)
    pix_trend .= RA._trend(tau_pix)
end

function rqatrend_matrix(pix_trend, pix, thresh=2)
    #replace!(pix, -9999 => missing)
    ts = collect(skipmissing(pix))
    rm = RecurrenceMatrix(ts, thresh)
    pix_trend .= RA.trend(rm)
end

#=
"""
    rqatrend_shuffle(cube; thresh=2, path=tempname() * ".zarr", numshuffle=300)
Compute the RQA trend metric for shuffled time series of the data cube `cube` with the epsilon threshold `thresh` for `numshuffle` tries and save it into `path`.
"""
function rqatrend_shuffle(cube; thresh=2, path=tempname() * ".zarr", numshuffle=300)
    # This should be made a random shuffle
    # TODO this looks completely broken
    sg = surrogenerator(collect(eachindex(water[overlap])), BlockShuffle(7, shift=true))
end
=#


"""
    anti_diagonal_density(ts, thresh, metric)
Compute the average density of the diagonals perpendicular to the main diagonal for data series `ts`.
Uses the threshold `thresh` and `metric` for the computation of the similarities.
"""
function anti_diagonal_density(ts::AbstractVector, thresh, metric=Euclidean())
    n = length(ts)
    ad_densities = zeros(2 * n - 3)
    for col in 1:n
        for row in 1:(col-1)
            d = evaluate(metric, ts[col], ts[row])
            #@show row, col, d
            ad_densities[col+row-2] += d <= thresh
        end
    end
    half = div(n, 2)
    maxdensities = collect(Iterators.flatten([(n, n) for n in 1:half-1]))
    diagonallengths = [maxdensities..., half, reverse(maxdensities)...]
    ad_densities ./ diagonallengths
end

"""
Compute the forest masking thresholding and clustering of the rqadata in one step
"""
function inner_postprocessing(rqadata, forestmask; threshold=-1.28, clustersize=30)
    @time rqamasked = rqadata .* forestmask
    @time rqathresh = map(rqamasked) do x
        if !ismissing(x)
            x > threshold ? zero(Float32) : one(Float32)
        else
            x
        end
    end
end