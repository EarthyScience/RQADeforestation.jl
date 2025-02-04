FROM debian:bookworm-slim
WORKDIR /work
COPY packagecompiler/app/bin /usr/bin
COPY packagecompiler/app/lib /usr/lib
ENTRYPOINT ["RQADeforestation"]