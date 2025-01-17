using RQADeforestation
using Test
import AllocCheck
import Random
import Pkg: Artifacts.@artifact_str
Random.seed!(1234)

testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-1.0")

@testset "Test data" begin
    @test isfile(joinpath(testdatapath, "V01R01", "EQUI7_EU020M", "E051N018T3", "SIG0_20210818T051717__VH_D095_E051N018T3_EU020M_V01R01_S1BIWGRDH.tif"))
end

@testset "RQADeforestation.jl" begin
    # Write your tests here.

    x = 1:0.01:30
    y = sin.(x) + 0.1x + rand(length(x))

    @test isapprox(RQADeforestation.rqatrend_impl(y; thresh=0.5), -0.11125611687816017)
    @test isempty(AllocCheck.check_allocs(RQADeforestation.rqatrend_impl, Tuple{Vector{Float64}}))
end
