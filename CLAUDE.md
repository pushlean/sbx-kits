# Tasks

## `mise`
Common commands are defined as `mise` tasks in [`mise.toml`](./mise.toml). Run `mise tasks` to list them, and `mise run <name>` to execute one. Update `mise.toml` when adding new canonical workflows rather than documenting raw commands here.

Note: the tasks described as "host-only" are not meant to be run inside a Docker sandbox — they shell out to `sbx`/`docker` against the host Docker daemon and must not be run from inside the sandbox container.

## `prek`
All pre-commit hooks (linters) are defined in .pre-commit-config.yaml -- do not duplicate these hooks as mise tasks. Claude hooks into these as well in project settings: `.claude/settings.json`.

# File Structure
Each top-level directory is a kit.
