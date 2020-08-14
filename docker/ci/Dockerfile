#while using circle we'll use circle's base image.
FROM cimg/base:2020.01 AS setup_ci

WORKDIR /libra
COPY rust-toolchain /libra/rust-toolchain
COPY cargo-toolchain /libra/cargo-toolchain
COPY scripts/dev_setup.sh /libra/scripts/dev_setup.sh


#Batch mode and all operations tooling
RUN scripts/dev_setup.sh -b -o && sudo apt-get clean

FROM setup_ci as tested_ci

#Compile a small rust tool?  But we already are in dev_setup...?
#RUN cargo -V
#RUN rustc -V
RUN hadolint --version
RUN vault --version
RUN terraform --version
RUN helm --help
RUN kubectl version --client

FROM setup_ci as build_environment
