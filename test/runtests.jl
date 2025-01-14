using RQADeforestation
using Test
import AllocCheck
import Random
Random.seed!(1234)

@testset "RQADeforestation.jl" begin
    # Write your tests here.

    x = 1:0.01:30
    y = sin.(x) + 0.1x + rand(length(x))

    @test isapprox(rqatrend(y; thresh=0.5), 0.1)
    @test isempty(AllocCheck.check_allocs(rqatrend, Tuple{Vector{Float64}}))
end
