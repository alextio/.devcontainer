#!/bin/bash
set -euo pipefail

# Resolve target UID/GID — priority: explicit env vars > workspace owner > current UID.
target_uid="${DEVCONTAINER_UID:-$(id -u)}"
target_gid="${DEVCONTAINER_GID:-$(id -g)}"

# Root with no explicit UID means no spec-aware tooling (VS Code / devcontainer
# CLI) reconciled the user before launch — infer the target from the
# bind-mounted workspace's owner instead. Handles raw `docker run`/`podman run`
# and IDEs that don't implement updateRemoteUserUID (e.g. Zed).
#
# CAVEAT (verified against this image on podman machine / macOS): virtiofs
# volume mounts present host files as UID 0 inside the container regardless of
# real host ownership, so this inference silently yields 0 and the container
# stays root. On a native Linux Docker/Podman host (no VM layer) bind mounts
# preserve real host UIDs and this works as intended. On podman machine, pass
# DEVCONTAINER_UID/DEVCONTAINER_GID explicitly (or --user) for a raw launch
# instead of relying on this fallback.
if [[ "$(id -u)" = "0" ]] && [[ -z "${DEVCONTAINER_UID:-}" ]]; then
    workspace="${DEVCONTAINER_WORKSPACE:-$(pwd)}"
    if [[ -d "$workspace" ]]; then
        target_uid="$(stat -c '%u' "$workspace")"
        target_gid="$(stat -c '%g' "$workspace")"
    fi
fi

# Resolve (or inject) a passwd entry for the target UID. `dev` already exists
# at UID 9999 in the image; a foreign UID gets a distinct name so the
# name-based gosu drop below can't accidentally resolve back to 9999.
# `|| true`: getent exits 2 when the UID has no entry — exactly the case
# handled just below. Under `set -euo pipefail` an unguarded assignment would
# abort the script here, so every foreign UID would fail to start.
target_user="$(getent passwd "$target_uid" | cut -d: -f1 | head -1)" || true
if [[ -z "$target_user" ]]; then
    target_user="user"
    echo "${target_user}:x:${target_uid}:${target_gid}::${HOME:-/home/dev}:/bin/bash" >> /etc/passwd
fi

# Best-effort: keep GPU access working for whichever user actually runs, not
# just the build-time `dev` account. No-op (and harmless) on hosts without
# /dev/dri or when not running as root.
if [[ "$(id -u)" = "0" ]] && getent group render >/dev/null 2>&1; then
    usermod -aG render "${target_user}" 2>/dev/null || true
fi

# Only path that touches root: drop to the resolved user by NAME (not
# uid:gid) so initgroups() loads the supplementary groups just granted above
# (e.g. render).
if [[ "$(id -u)" = "0" ]] && [[ "${target_uid}" != "0" ]]; then
    exec gosu "${target_user}" "$@"
fi

exec "$@"
