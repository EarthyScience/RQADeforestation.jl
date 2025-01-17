using RQADeforestation
using Test
import AllocCheck
import Random
Random.seed!(1234)

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
