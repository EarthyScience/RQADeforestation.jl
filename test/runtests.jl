using RQADeforestation
using Test
import AllocCheck
import Random
import Pkg: Artifacts.@artifact_str, ensure_artifact_installed
Random.seed!(1234)

ensure_artifact_installed("rqatestdata", "Artifacts.toml")
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


    y2 = similar(y, Union{Float64, Missing})
    copy!(y2, y)
    y2[[1,4,10,20,33,65]] .= missing


    @test isapprox(RQADeforestation.rqatrend_impl(y2; thresh=0.5), -0.11069045524336744)
    @test isempty(AllocCheck.check_allocs(RQADeforestation.rqatrend_impl, Tuple{Vector{Union{Float64,Missing}}}))

end
