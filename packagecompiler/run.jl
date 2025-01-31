#!/usr/bin/env -S julia --project=/app

using PackageCompiler

dir = ARGS[1]

PackageCompiler.create_app(dir, "$dir/packagecompiler/app";
    precompile_statements_file="$dir/packagecompiler/precompile_statements.jl",
    # see https://github.com/JuliaLang/PackageCompiler.jl/issues/994
    include_lazy_artifacts=true,
    # or try the following, which may work because IntelOpenMP and MKL may actually not be needed
    # include_transitive_dependencies=false,
)
# lets have an easy check whether this actually worked
touch("$dir/packagecompiler/app/done")