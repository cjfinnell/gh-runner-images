# gh-runner-images

Custom runner images for the self-hosted GitHub Actions scale sets (ARC) deployed from [cjfinnell/homelab](https://github.com/cjfinnell/homelab). Images publish to `ghcr.io/cjfinnell/<name>` from CI on merge to `main`, using the built-in `GITHUB_TOKEN`.

| Image | Used by | Contents |
| --- | --- | --- |
| [`gha-runner-rust`](./images/gha-runner-rust) | `cjfinnell/rust-worker` | build-essential, libssl-dev, `gh`, pinned Rust toolchain with rustfmt, clippy and wasm32 |
| [`quartz-vault`](./images/quartz-vault) | homelab `vault-viewer` ([#124](https://github.com/cjfinnell/homelab/issues/124)) | Quartz v5 (commit-pinned) + the vault's `quartz.config.yaml` and builder loop; no vault content |

## Changing an image

1. Edit the Dockerfile and bump `TAG` in the image directory.
2. Merge to `main`. The `publish` workflow builds and pushes the new tag (it skips tags that already exist).
3. Bump the tag in homelab (`services/arc/runners/<repo>.values.yaml`).

Manual rebuild of an existing tag: run the `publish` workflow with `workflow_dispatch`.
