# Welcome to RQADeforestation.jl

This README collects important information for local development of the package.

# Important installation extras

This package uses pre-commit to ensure formatting quality, which needs to be installed via python, e.g. via the uv package manager which has global tool support.
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install pre-commit
uvx pre-commit install
```

In addition, the `JuliaFormatter.jl` package needs to be installed into your global julia environment
```bash
julia -e "import Pkg; Pkg.add("JuliaFormatter")
```

The standard julia formatting ensured is the [blue style](https://github.com/JuliaDiff/BlueStyle)
