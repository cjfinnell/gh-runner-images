# Runner image for cjfinnell/rust-worker on the ARC `homelab-x64` scale set (#87, phase 2).
# Adds what the stock runner lacks: a C toolchain for build scripts, gh, and a pinned Rust
# toolchain with rustfmt, clippy and the wasm32 target. Everything else (trunk, cargo-deny,
# sops, linespec, node/wrangler via mise, worker-build) is installed per job by rust-worker.
#
# Build and push: `make image.gha-runner-rust` (amd64; the tag comes from services/arc/runners/rust-worker.values.yaml).
FROM ghcr.io/actions/actions-runner:2.338.0@sha256:4ffadc0002b2581327e06101fc8c06cd189232baf79fe561fac9caeb76f5e807

# Links the GHCR package to this repo.
LABEL org.opencontainers.image.source=https://github.com/cjfinnell/homelab

ARG TARGETARCH
ARG RUST_VERSION=1.99.1
ARG RUSTUP_VERSION=1.29.1
ARG GH_VERSION=2.102.0

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# build-essential: cc/make for build scripts and proc-macros. zstd: faster actions/cache archives.
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential pkg-config zstd xz-utils \
    && rm -rf /var/lib/apt/lists/*

# gh CLI (preview.yml calls `gh api`), checksum-verified release tarball.
RUN case "${TARGETARCH}" in \
      amd64) sum=bb766f710eef8ede859c18578c72c327597cd4c8a85b06001b1f3843c6019386 ;; \
      arm64) sum=7862c86c72f43df3a2d93ddde6f473285b4e2af61b494849846827e513ef6484 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /tmp/gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
    && echo "${sum}  /tmp/gh.tgz" | sha256sum -c - \
    && tar -xzf /tmp/gh.tgz -C /tmp \
    && install -m 755 "/tmp/gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh" /usr/local/bin/gh \
    && rm -rf /tmp/gh.tgz "/tmp/gh_${GH_VERSION}_linux_${TARGETARCH}"

# Rust lives outside $HOME and is owned by the runner user, so jobs can still
# `rustup target add` and `cargo install worker-build` without root.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN case "${TARGETARCH}" in \
      amd64) triple=x86_64-unknown-linux-gnu; sum=dda7234360b7f578ca8b0ddcb80145646fa61a67c1720a5abc7051b35c9fcb71 ;; \
      arm64) triple=aarch64-unknown-linux-gnu; sum=15f6e4ce9f583b929c996c91562bad6d4454f3281de858b02cdfdef615fac433 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /tmp/rustup-init "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${triple}/rustup-init" \
    && echo "${sum}  /tmp/rustup-init" | sha256sum -c - \
    && chmod +x /tmp/rustup-init \
    && /tmp/rustup-init -y --no-modify-path --profile minimal \
         --default-toolchain "${RUST_VERSION}" \
         --component rustfmt,clippy \
         --target wasm32-unknown-unknown \
    && rm /tmp/rustup-init \
    && chown -R runner:runner "${RUSTUP_HOME}" "${CARGO_HOME}" \
    && rustc --version && cargo --version && gh --version

USER runner
