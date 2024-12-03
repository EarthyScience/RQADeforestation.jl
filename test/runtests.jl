using RQADeforestation
using Test
using ArchGDAL
using YAXArrays

@testset "RQADeforestation.jl" begin
    ds = open_dataset("/eodc/products/eodc.eu/S1_CSAR_IWGRDH/SIG0/V01R01/EQUI7_AF020M/E006N069T3/SIG0_20210914T072955__VH_D140_E006N069T3_AF020M_V01R01_S1BIWGRDH.tif")
    @test minimum(ds.X) == 600000
    @test maximum(ds.X) == 899980
end
