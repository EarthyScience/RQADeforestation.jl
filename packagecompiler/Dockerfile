FROM julia:1.11.3-bookworm

WORKDIR /app
# unset threads see https://github.com/JuliaLang/PackageCompiler.jl/issues/990
ENV JULIA_NUM_THREADS=
ENV JULIA_DEPOT_PATH=/.julia

RUN apt-get update && apt-get install -y build-essential
COPY Project.toml ./
RUN julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.status()'
RUN chmod -R +r /.julia
COPY run.jl ./
ENTRYPOINT [ "./run.jl" ]