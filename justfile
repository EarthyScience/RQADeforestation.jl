docker_image_name := "rqatest"

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

# downloads the Artifact test data to tmp/apptestdata
download-test-data $tmpdir="tmp/apptestdata":
    #!/usr/bin/env bash
    set -euxo pipefail
    indir="$PWD/$tmpdir/in"
    cd test
    julia --project -e '
        import Pkg: Artifacts.@artifact_str, ensure_artifact_installed
        ensure_artifact_installed("rqatestdata", "Artifacts.toml")
        testdatapath = joinpath(artifact"rqatestdata", "RQADeforestationTestData-2.0")
        testdir = dirname(ARGS[1])
        rm(testdir, recursive=true, force=true)
        mkpath(testdir)
        cp(testdatapath, ARGS[1])
    ' -- "$indir"
    
    
# test the app `packagecompiler/app/RQADeforestation` with testdata, writing data to `tmp/apptestdata`
test-app $tmpdir="tmp/apptestdata": (download-test-data tmpdir)
    #!/usr/bin/env bash
    set -euxo pipefail
    indir="$tmpdir/in"
    outdir="$tmpdir/out.zarr"
    ./packagecompiler/app/bin/RQADeforestation --tile E051N018T3 --continent EU --start-date "2021-01-01" --end-date "2022-01-01" --in-dir "$indir" --out-dir "$outdir"

# builds the standard docker
build-docker:
    docker build -t "{{docker_image_name}}" -f Dockerfile .

# tests the build docker image using the Artifact test data, writing data to `tmp/apptestdata`
test-docker $tmpdir="tmp/apptestdata": (download-test-data tmpdir)
    #!/usr/bin/env bash
    set -euxo pipefail
    indir="$tmpdir/in"
    outdir="$tmpdir/out.zarr"
    docker run --user $(id -u):$(id -g) --rm -v "$PWD/$tmpdir":"/$tmpdir" "{{docker_image_name}}" --tile E051N018T3 --continent EU --start-date "2021-01-01" --end-date "2022-01-01" --in-dir "/$indir" --out-dir "/$outdir"

# compiles rqatrend to its own c-library using StaticCompiler.jl 
staticcompile:
    #!/usr/bin/env bash
    set -euxo pipefail
    if [ -d staticcompiler/lib ]; then
        if [ -d staticcompiler/lib.backup ]; then
            rm -rf staticcompiler/lib.backup
        fi
        mv staticcompiler/lib staticcompiler/lib.backup
    fi
    # using progress plain is important as staticcompiler.jl 
    # outputs warnings instead of errors if things may not work
    docker build --progress=plain -t temp-image -f Dockerfile.staticcompiler .
    docker create --name temp-container temp-image
    docker cp temp-container:/app/staticcompiler/lib "$PWD/staticcompiler/lib"
    docker rm temp-container
    docker rmi temp-image