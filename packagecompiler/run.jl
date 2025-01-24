#!/usr/bin/env -S julia --threads=auto

using PackageCompiler

in_dir = ARGS[1]
out_dir = ARGS[2]

PackageCompiler.create_app(in_dir, "$out_dir/app";
    precompile_statements_file="$out_dir/precompile_statements.jl",
    # see https://github.com/JuliaLang/PackageCompiler.jl/issues/994
    include_lazy_artifacts=true,
    # or try the following, which may work because IntelOpenMP and MKL may actually not be needed
    # include_transitive_dependencies=false,
)
# lets have an easy check whether this actually worked
touch("$out_dir/app/done")