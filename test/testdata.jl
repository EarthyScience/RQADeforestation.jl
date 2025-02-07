
@testitem "testdata julia_main" begin
    import Pkg: Artifacts.@artifact_str, ensure_artifact_installed

    ensure_artifact_installed("rqatestdata", "Artifacts.toml")
    testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-2.0")

    testdir = "tmp/testdata" 
    rm(testdir, recursive=true, force=true)
    mkpath(testdir)
    outdir = "$testdir/out.zarr"
    indir = "$testdir/in"
    cp(testdatapath, indir)

    OLD_ARGS = ARGS[:]
    copy!(ARGS, [
        "--tile", "E051N018T3",
        "--continent", "EU",
        "--in-dir", indir,
        "--out-dir", outdir,
    ])
    # test normal execution
    RQADeforestation.julia_main()
    # test short cut implementation using cache files
    RQADeforestation.julia_main()
    copy!(ARGS, OLD_ARGS)
end