precompilestatements:
    julia --project -e 'import Pkg; Pkg.test(julia_args=`--trace-compile=packagecompiler/precompile_statements.jl`)'

packagecompile:
    #!/usr/bin/env -S julia --project=packagecompiler
    using PackageCompiler
    rm("packagecompiler/app.backup", recursive=true, force=true)
    mv("packagecompiler/app", "packagecompiler/app.backup")
    PackageCompiler.create_app(".", "packagecompiler/app"; precompile_statements_file="packagecompiler/precompile_statements.jl")