using RQADeforestation
using Test
using DimensionalData
using YAXArrays
using Dates
using Random
using Statistics

Random.seed!(1337)

@testset "RQADeforestation.jl" begin
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
    @test abs(mean(mock_trend)) < 0.1
end
