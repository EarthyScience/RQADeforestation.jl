
@testitem "testdata julia_main" begin
    import Pkg: Artifacts.@artifact_str, ensure_artifact_installed

    ensure_artifact_installed("rqatestdata", "Artifacts.toml")
    testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-2.0")

    testdir = "/tmp/testdata"
    rm(testdir, recursive=true, force=true)
    mkpath(testdir)
    outdir = "$testdir/out.zarr"
    indir = "$testdir/in"
    cp(testdatapath, indir)

    using Zarr
    using YAXArrays
    using Dates
    RQADeforestation.main(;
        tiles=["E051N018T3"],
        continent="EU",
        indir=indir,
        start_date=Date("2021-01-01"),
        end_date=Date("2021-12-31"),
        outdir=outdir
    )
    a = open_dataset(outdir * "/E051N018T3_rqatrend_VH_D022_thresh_3.0.zarr").layer

    @test size(a) == (50, 74)
    @test minimum(a) < 0
    @test maximum(a) > 0
end