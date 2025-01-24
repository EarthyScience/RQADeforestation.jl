FROM julia:1.11.3-bookworm

WORKDIR /work
ENV JULIA_NUM_THREADS=auto
ENV JULIA_DEPOT_PATH=/.julia

RUN apt-get update && apt-get install -y build-essential
COPY Project.toml /.julia/environments/v1.11/
RUN julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.status()'
COPY run.jl ./
CMD [ "julia", "--project", "run.jl"]