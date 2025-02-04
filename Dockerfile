FROM julia:1.11.2-bookworm
WORKDIR /work

ENV JULIA_NUM_THREADS=auto
ENV JULIA_DEPOT_PATH=/.julia

COPY src RQADeforestation/src
COPY Project.toml RQADeforestation/Project.toml
RUN julia -e 'using Pkg; Pkg.add(["Glob", "ArgParse", "YAXArrays", "DimensionalData", "Distributed"])'
RUN julia -e 'using Pkg; Pkg.develop(path = "RQADeforestation"); Pkg.precompile()'
COPY run.jl ./
RUN chmod +x run.jl
ENTRYPOINT ["/work/run.jl"]