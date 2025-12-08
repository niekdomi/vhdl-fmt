# ==================================================
# Stage 1: Builder image
# ==================================================
FROM fedora:43 AS builder

# Install system dependencies
RUN dnf install -y --setopt=install_weak_deps=false \
    python3 \
    clang \
    clang-tools-extra \
    llvm \
    compiler-rt \
    cmake \
    git \
    make \
    ninja-build \
    nodejs \
    && dnf clean all

# Get the latest version of uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Setup venv
RUN uv venv /opt/venv --seed \
    && /opt/venv/bin/pip install --no-cache-dir conan gersemi==0.19.3

ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

WORKDIR /app

# Copy only what's needed for dependency resolution
COPY conanfile.txt clang.profile ./

# Prefill Conan dependencies (equivalent to `make conan`)
RUN conan install . \
    --profile:host=clang.profile \
    --profile:build=clang.profile \
    --build=missing \
    -s build_type=Debug && \
    rm -rf /root/.conan2/p/tmp

# ==================================================
# Stage 2.1: Development image
# ==================================================
FROM builder AS dev

RUN dnf install -y --setopt=install_weak_deps=false \
    lldb \
    ccache \
    which \
    wget \
    procps \
    zsh \
    tree \
    && dnf clean all

# Install Oh My Zsh and set it as the default shell
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set Zsh as the default shell
RUN chsh -s /usr/bin/zsh root

# Use the custom theme
COPY .devcontainer/custom.zsh-theme /root/.oh-my-zsh/custom/themes/
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="custom"/g' /root/.zshrc

WORKDIR /app
CMD ["/usr/bin/zsh"]

# ==================================================
# Stage 2.2: CI image
# ==================================================
FROM builder AS ci

WORKDIR /app
