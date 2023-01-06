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
WORKDIR /home/vscode/noir/crates/nargo
RUN cargo install --locked --path=.