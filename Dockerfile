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

# Non-root user, created here because the common-utils feature would add sudo.
# UID/GID 9999 is only the *default* identity baked into the image: VS Code /
# the devcontainer CLI rewrite it to match the host user via
# updateRemoteUserUID (containerUser in devcontainer.json), and entrypoint.sh
# below reconciles it for any launcher that doesn't implement that spec
# mechanism (raw `docker run`/`podman run`, or non-spec IDEs like Zed).
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
 # Vulkan/GL access to the virtio-gpu render node
 && { getent group render >/dev/null && usermod -aG render ${USERNAME} || true; }

# gosu drops privileges after entrypoint.sh's root-only setup steps.
# renovate: datasource=github-releases depName=tianon/gosu
ARG GOSU_VERSION="1.17"
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64) gosu_arch=amd64 ;; \
         aarch64) gosu_arch=arm64 ;; \
         *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${gosu_arch}" -o /usr/local/bin/gosu \
    && chmod +x /usr/local/bin/gosu \
    && gosu --version

# Writable so entrypoint.sh can inject a passwd/group entry for whatever UID
# actually launched the container (arbitrary-UID / cross-runtime support).
RUN chmod 0666 /etc/passwd /etc/group

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

# No static USER: the image defaults to root so entrypoint.sh can decide the
# runtime user. It drops to non-root immediately except on the one fallback
# path (root, no UID reconciled by anything else) documented in the script.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

# Put all tools installed using curl or bash scripts inside ./scripts/post-create/
