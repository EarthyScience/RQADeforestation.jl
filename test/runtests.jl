using LazyArtifacts
using RQADeforestation

# doctests do not run as testitem as of now, hence it is included here
using Documenter
DocMeta.setdocmeta!(
    RQADeforestation, :DocTestSetup, :(using RQADeforestation); recursive=true
)
doctest(RQADeforestation)

using TestItemRunner
@run_package_tests


@testitem "rqa step function" begin
    using RQADeforestation
    using Distributions: Normal as DNormal
    x = range(0,100,length=1000)
    ts2 = zero(x)
    ts2[1:div(end,2)] .= rand.(DNormal(3,1))
    ts2[div(end,2):end] .= rand.(DNormal(0,1))
    pixtrend = UInt8[255]
    RQADeforestation.rqatrend(pixtrend, ts2)
    @test pixtrend[] < 20
end