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