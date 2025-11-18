
@testitem "testdata main" begin
    import Pkg: Artifacts.@artifact_str
    using LazyArtifacts
    using FilePathsBase
    testdatapath = artifact"rqatestdata/RQADeforestationTestData-2.0"

    testdir = tempname()
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
        end_date=Date("2022-01-01"),
        outdir=Path(outdir)
    )
    a = open_dataset(outdir * "/E051N018T3_rqatrend_VH_D022_thresh_3.0.zarr").layer

    @test size(a) == (50, 74)
    @test minimum(a) == 0 
    @test maximum(a) > 200
end

@testitem "testdata julia_main" begin
    import Pkg: Artifacts.@artifact_str
    testdatapath = artifact"rqatestdata/RQADeforestationTestData-2.0"

    testdir = tempname()
    rm(testdir, recursive=true, force=true)
    mkpath(testdir)
    outdir = "$testdir/out.zarr"
    indir = "$testdir/in"
    cp(testdatapath, indir)

    OLD_ARGS = ARGS[:]
    copy!(ARGS, [
        "--tile", "E051N018T3",
        "--continent", "EU",
        "--start-date", "2021-01-01",
        "--end-date", "2022-01-01",
        "--in-dir", indir,
        "--out-dir", outdir,
    ])
    # test normal execution
    RQADeforestation.julia_main()
    # test short cut implementation using cache files
    RQADeforestation.julia_main()
    copy!(ARGS, OLD_ARGS)

    @test outdir |> readdir |> length > 1
end
