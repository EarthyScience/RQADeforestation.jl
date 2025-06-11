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
    @test mock_count[1, 1] == 20
    @test mock_count[1, 2] == 30
    @test mock_count[2, 2] == 27
    @test mock_count[2, 1] == 0
end