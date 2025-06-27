FROM julia:1.11-bookworm AS packagecompiled

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \ 
    apt -y update && apt -y install build-essential curl ca-certificates

# from Debian version 13 onwards, "just" can simply be installed via apt install
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

WORKDIR /repo
COPY . .
RUN --mount=type=cache,target=/root/.julia \
    julia --project=. -e "import Pkg; Pkg.instantiate()"
RUN --mount=type=cache,target=/root/.julia \
    julia --project="packagecompiler" -e "import Pkg; Pkg.instantiate()"
RUN --mount=type=cache,target=/root/.julia \
    just packagecompile

# having precompiled everything we can simply copy the binaries to its slim docker image
FROM debian:bookworm-slim
WORKDIR /work
COPY --from=packagecompiled /repo/packagecompiler/app/bin /usr/bin
COPY --from=packagecompiled /repo/packagecompiler/app/lib /usr/lib
COPY --from=packagecompiled /repo/packagecompiler/app/share /usr/share
ENTRYPOINT ["RQADeforestation"]

