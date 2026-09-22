# Fedora base with libkrun/virgl-patched Mesa (Vulkan via virtio-gpu Venus/virgl)
# so Vulkan works inside a `podman machine` (libkrun) VM.
# renovate: datasource=docker depName=quay.io/slopezpa/fedora-vgpu versioning=docker
ARG BASE_IMAGE="quay.io/slopezpa/fedora-vgpu@sha256:d1fd35583d1c72bc7380bb977d5d51e70d70c77a2279a0412c2e6ac462f61f16"
FROM ${BASE_IMAGE}

ARG USERNAME=dev
ARG USER_UID=9999
ARG USER_GID=9999

# The base image already ships the patched mesa-vulkan-drivers,
# mesa-dri-drivers, mesa-filesystem, virglrenderer, vulkan-loader and
# vulkan-tools. They are deliberately NOT re-listed here: naming them
# would let dnf pull the stock Fedora Mesa over the patched build.

# Base system tooling and locales.
RUN dnf install -y \
        bash \
        zsh \
        ca-certificates \
        curl \
        git \
        openssh-clients \
        jq \
        vim-enhanced \
        gnupg2 \
        glibc-langpack-en \
    && dnf clean all

# Python toolchain.
RUN dnf install -y \
        python3 \
        python3-devel \
    && dnf clean all

# Node.js toolchain (pnpm is not in Fedora's repos, so pin it via npm).
RUN dnf install -y \
        nodejs \
    && dnf clean all \
    # renovate: datasource=npm depName=pnpm
    && npm install -g pnpm@12.5.1

# Rust toolchain.
RUN dnf install -y \
        rust \
        cargo \
    && dnf clean all

# Browser automation (Chromium for Chrome DevTools MCP).
RUN dnf install -y \
        chromium \
        liberation-fonts \
        xdg-utils \
    && dnf clean all

WORKDIR /workspace
USER $USERNAME

# Put all tools installed using curl or bash scripts inside ./scripts/post-create/
