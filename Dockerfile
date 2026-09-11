FROM ubuntu:24.04

ARG USERNAME=dev

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    zsh \
    ca-certificates \
    curl \
    git \
    openssh-client \
    jq \
    vim \
    gnupg \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    build-essential \
    ffmpeg \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
USER $USERNAME

# Put all tools installed using curl or bash scripts inside ./scripts/post-create/
