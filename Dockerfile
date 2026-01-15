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
    && /opt/venv/bin/pip install --no-cache-dir conan gersemi

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
    curl \
    procps \
    tar \
    tree \
    && dnf clean all

# ==================================================
# Stage 2.2: CI image
# ==================================================
FROM builder AS ci

RUN dnf install -y --setopt=install_weak_deps=false \
    ccache \
    && dnf clean all

WORKDIR /app
