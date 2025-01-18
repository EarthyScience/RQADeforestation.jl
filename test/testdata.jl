# @testitem "testdata" begin
#     # TODO load testdata from artifacts
#     RQADeforestation.main(;
#         indir="../tmp/testdata/subdata/",
#         outdir="../tmp/out.zarr",
#         tiles=["E051N018T3"],
#         continent="EU",
#     )
# end

@testitem "testdata julia_main" begin
    OLD_ARGS = ARGS[:]
    outdir = "../tmp/out.zarr"
    copy!(ARGS, [
        "--tile", "E051N018T3",
        "--continent", "EU",
        "--in-dir", "../tmp/testdata/subdata/",
        "--out-dir", outdir,
    ])
    rm(outdir, recursive=true)
    # test normal execution
    RQADeforestation.julia_main()
    # test short cut
    RQADeforestation.julia_main()
    copy!(ARGS, OLD_ARGS)
end