# 개요

This package scans `src` and `docs` for forbidden Moonwave tags.

## Usage

Run the script from the repository root.

```sh
lune run pkgs/check_moonwave_syntax/src/init.luau
```

## Scope

- The scan targets `.lua` and `.luau` files under `src` and `docs`.
- Common build and dependency directories such as `roblox_packages` and `.pesde` are skipped.

## Rules

- The forbidden tags include `@module` and `@constructor`.
