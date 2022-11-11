FROM  mcr.microsoft.com/vscode/devcontainers/rust:latest


# Update all Ubuntu Packages
RUN apt-get update && apt-get upgrade -y

# Install all apt-get packages
RUN apt-get install -y --no-install-recommends \
        cmake \
        curl \
        clang \
        clang-format \
        pkg-config \
        libssl-dev \
        libomp-dev

# Manually install NodeJS from nvm
ENV NODE_VERSION=16.15.0

USER vscode

# Install NVM
RUN curl -f -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# Install noir
RUN git clone https://github.com/noir-lang/noir.git ~/noir

# https://docs.aztec.network/developers/noir#install-noir-from-source
# utilizes the C++ backend's wasm executable instead of compiling from source
# WORKDIR /home/vscode/noir/crates/nargo
# RUN sed -i -e 's@aztec_backend = .*@azkkktec_backend = { optional = true, git = "https://github.com/noir-lang/aztec_backend", rev = "d91c69f2137777cec37f692f98d075ae10e7a584", default-features = false, features = [ "wasm-base", ] }@' Cargo.toml


WORKDIR /home/vscode/noir/crates/nargo
RUN git checkout gd/short_circuit
RUN cargo fetch --locked

WORKDIR /usr/local/cargo/git/checkouts/barretenberg-6ce83dfea69613eb/804c7dc/barretenberg_wrapper
RUN sed -i -e 's@    if cfg!(all(target_os = "macos", target_arch = "aarch64")) {@    if cfg!(all(target_arch = "aarch64")) {@' build.rs

WORKDIR /home/vscode/noir/crates/nargo
RUN LIBRARY_PATH=$LIBRARY_PATH:/usr/lib/llvm-11/lib/ cargo install --locked --path=.