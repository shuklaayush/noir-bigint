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
RUN mkdir -p $HOME/.nargo/bin
RUN curl -o $HOME/.nargo/bin/nargo-aarch64-unknown-linux-gnu.tar.gz -L https://github.com/noir-lang/noir/releases/download/nightly/nargo-aarch64-unknown-linux-gnu.tar.gz
RUN tar -xvf $HOME/.nargo/bin/nargo-aarch64-unknown-linux-gnu.tar.gz -C $HOME/.nargo/bin/
RUN mkdir -p $HOME/.config/noir-lang
RUN cp -r $HOME/.nargo/bin/noir-lang/* "$HOME/.config/noir-lang/"
RUN echo 'export PATH=$PATH:$HOME/.nargo/bin' >> ~/.bashrc