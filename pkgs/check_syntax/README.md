# 개요

This package checks Luau syntax by compiling sources and running luau-lsp and Selene.

## Usage

Run the script from the repository root.

```sh
lune run pkgs/check_syntax/src/init.luau
```

## Arguments

- Provide file or directory paths to limit the check scope.
- When no arguments are provided, the default roots are `src` and `.lune`.

## Environment

- `LUAU_LSP_DEFINITIONS` can point to a custom `roblox.d.luau` definitions file.
- `CHECK_SYNTAX_SKIP_LSP` skips luau-lsp analysis when set to `1` or `true`.
