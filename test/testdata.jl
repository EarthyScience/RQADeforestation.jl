
@testitem "testdata julia_main" begin
    import Pkg: Artifacts.@artifact_str, ensure_artifact_installed
    using YAXArrays, Zarr

    ensure_artifact_installed("rqatestdata", "Artifacts.toml")
    testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-2.0")

    testdir = "tmp/testdata" 
    rm(testdir, recursive=true, force=true)
    mkpath(testdir)
    outdir = "$testdir/out"
    indir = "$testdir/in"
    cp(testdatapath, indir)

    OLD_ARGS = ARGS[:]
    copy!(ARGS, [
        "--tile", "E051N018T3",
        "--continent", "EU",
        "--in-dir", indir,
        "--out-dir", outdir,
        "--years", "2021"
    ])
    # test normal execution
    RQADeforestation.julia_main()
    # test short cut implementation using cache files
    RQADeforestation.julia_main()

    outpath = joinpath(outdir, "E051N018T3_rqatrend_VH_022_thresh_3.0_year_2021.zarr")
    c = Cube(outpath)
    @test count(c .< -1.28) > 200
    copy!(ARGS, OLD_ARGS)
end