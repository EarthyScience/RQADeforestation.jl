using RecurrenceAnalysis
#using MultipleTesting
using Distances
const RA = RecurrenceAnalysis
"""
countvalid(xout, xin)

    Inner function to count the valid time steps in a datacube.
    This function is aimed to be used inside of a mapCube call.
"""
function countvalid(xout, xin)
    xout .= count(!ismissing, xin)
end

"""
countvalidag(xout, xin)

    Inner function to count the valid time steps in a datacube.
    This function is aimed to be used inside of a mapCube call.
"""
function countvalidint(xout, xin)
    xout .= count(x -> x != -9999, xin)
end
"""
countvalid(cube)

    Outer function to count the number of valid time steps in a cube.
"""
countvalid(cube; path=tempname() * ".zarr") = mapCube(countvalid, cube; indims=InDims("Time"), outdims=OutDims(; path))


"""
rqatrend(xout, xin, thresh)

Compute the RQA trend metric for the non-missing time steps of xin, and save it to xout. 
`thresh` specifies the epsilon threshold of the Recurrence Plot computation
"""
function rqatrend_recurrenceanalysis(pix_trend, pix, thresh=2)
    #replace!(pix, -9999 => missing)
    ts = collect(skipmissing(pix))
    #@show length(ts)
    tau_pix = tau_recurrence(ts, thresh)
    pix_trend .= RA._trend(tau_pix)
end

function rqatrend_matrix(pix_trend, pix, thresh=2)
    #replace!(pix, -9999 => missing)
    ts = collect(skipmissing(pix))
    rm = RecurrenceMatrix(ts, thresh)
    pix_trend .= RA.trend(rm)
end

"""
    rqatrend_shuffle(cube; thresh=2, path=tempname() * ".zarr", numshuffle=300)
Compute the RQA trend metric for shuffled time series of the data cube `cube` with the epsilon threshold `thresh` for `numshuffle` tries and save it into `path`.
"""
function rqatrend_shuffle(cube; thresh=2, path=tempname() * ".zarr", numshuffle=300)
    # This should be made a random shuffle
    # TODO this looks completely broken
    sg = surrogenerator(collect(eachindex(water[overlap])), BlockShuffle(7, shift=true))
end


import RecurrenceAnalysis: tau_recurrence

function tau_recurrence(ts::AbstractVector, thresh, metric=Euclidean())
    n = length(ts)
    rr_τ = zeros(n)
    for col in 1:n
        for row in 1:(col-1)
            d = evaluate(metric, ts[col], ts[row])
            #@show row, col, d
            rr_τ[col-row+1] += d <= thresh
        end
    end
    rr_τ[1] = n
    rr_τ ./ (n:-1:1)
    #rr_τ
end

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
    #@time labeldata = MultipleTesting.label_components(rqathresh,trues(3,3))
    #@time clusterdata = MultipleTesting.maskcluster(rqathresh, labeldata, clustersize)
end