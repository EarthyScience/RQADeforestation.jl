default:
  just --list

# create precompile statements used for `just packagecompile`
precompilestatements:
    julia --project -e 'import Pkg; Pkg.test(julia_args=`--trace-compile=packagecompiler/precompile_statements.jl`)'

# build an app at `packagecompiler/app/RQADeforestation` with PackageCompiler.jl
packagecompile:
    #!/usr/bin/env -S julia --project=packagecompiler
    using PackageCompiler
    if isdir("packagecompiler/app") 
        rm("packagecompiler/app.backup", recursive=true, force=true)
        mv("packagecompiler/app", "packagecompiler/app.backup")
    end
    PackageCompiler.create_app(".", "packagecompiler/app"; 
        precompile_statements_file="packagecompiler/precompile_statements.jl",
        # see https://github.com/JuliaLang/PackageCompiler.jl/issues/994
        include_lazy_artifacts=true,
        # or try the following, which may work because IntelOpenMP and MKL may actually not be needed
        # include_transitive_dependencies=false,
    )
    # lets have an easy check whether this actually worked
    touch("packagecompiler/app/done")

# test the app `packagecompiler/app/RQADeforestation` with testdata, writing data to `test/tmp/apptestdata`
testapp:
    #!/usr/bin/env bash
    cd test
    indir="tmp/apptestdata/in"
    outdir="tmp/apptestdata/out.zarr"
    julia --project -e '
        import Pkg: Artifacts.@artifact_str, ensure_artifact_installed
        ensure_artifact_installed("rqatestdata", "Artifacts.toml")
        testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-1.0")
        testdir = dirname(ARGS[1])
        rm(testdir, recursive=true, force=true)
        mkpath(testdir)
        cp(testdatapath, ARGS[1])
    ' -- "$indir"
    ../packagecompiler/app/bin/RQADeforestation --tile E051N018T3 --continent EU --in-dir "$indir" --out-dir "$outdir"