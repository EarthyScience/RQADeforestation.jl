precompilestatements:
    julia --project -e 'import Pkg; Pkg.test(julia_args=`--trace-compile=packagecompiler/precompile_statements.jl`)'

packagecompile:
    #!/usr/bin/env -S julia --project=packagecompiler
    using PackageCompiler
    rm("packagecompiler/app.backup", recursive=true, force=true)
    mv("packagecompiler/app", "packagecompiler/app.backup")
    PackageCompiler.create_app(".", "packagecompiler/app"; 
        precompile_statements_file="packagecompiler/precompile_statements.jl",
        # see https://github.com/JuliaLang/PackageCompiler.jl/issues/994
        include_lazy_artifacts=true,
        # or try the following, which may work because IntelOpenMP and MKL may actually not be needed
        # include_transitive_dependencies=false,
    )

testapp:
    #!/usr/bin/env bash
    outdir="tmp/app-out.zarr"
    rm -rf $outdir
    packagecompiler/app/bin/RQADeforestation --tile E051N018T3 --continent EU --in-dir "tmp/testdata/subdata/" --out-dir $outdir