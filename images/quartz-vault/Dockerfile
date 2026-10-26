# Quartz v5 builder for the private memory-vault viewer (cjfinnell/homelab#124).
#
# The image holds Quartz itself, the vault's quartz.config.yaml and the npm
# plugins — never vault content. At runtime the pod clones cfin/nanoclaw-memory
# over in-cluster Gitea SSH and runs `npx quartz build`; see build.sh.
#
# Quartz v5 is a branch with no release tag (last tag: v4.0.8), so the source is
# pinned by commit.
# renovate: datasource=github-commits depName=jackyzha0/quartz branchName=v5
ARG QUARTZ_REF=97a2d05f80c4c50534959b1d0d41cc4b3895625e

FROM node:22-slim AS builder
ARG QUARTZ_REF
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/src/app
ADD https://github.com/jackyzha0/quartz/archive/${QUARTZ_REF}.tar.gz /tmp/quartz.tar.gz
RUN tar -xzf /tmp/quartz.tar.gz --strip-components=1 -C /usr/src/app \
  && rm /tmp/quartz.tar.gz quartz.config.default.yaml
COPY quartz.config.yaml ./
# npm ci pins Quartz's own deps; the @quartz-community plugins ship as npm deps
# of Quartz, so the lockfile (package-lock.json at the pinned commit) pins them.
# plugin install stays a no-op here for all-npm configs and exists only to match
# the upstream Dockerfile if a git-sourced plugin is ever added.
RUN npm ci --no-audit --no-fund \
  && npx quartz plugin install --from-config

FROM node:22-slim
# git + ssh for cloning the vault; ca-certificates for the Gitea SSH host.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates git openssh-client \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/ /usr/src/app/
COPY build.sh /usr/local/bin/vault-build
# Writable HOME for git/npx caches. /usr/src/app/quartz/.quartz-cache must stay
# writable too (esbuild output): the chart mounts an emptyDir there and at /tmp.
ENV HOME=/tmp
USER node
ENTRYPOINT ["vault-build"]
