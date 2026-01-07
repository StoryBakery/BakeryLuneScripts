# 개요

This package watches `src` and builds `out` with Darklua, copies assets, and optionally rewrites Rojo project files.

## Usage

```sh
lune run pkgs/watch_darklua/src/init.luau
```

## Requirements

- `lune` must be available in PATH.
- `darklua` must be available in PATH.
- `rojo` must be available in PATH when using `--serve` or `--sourcemap`.

## Options

- `--src <path>`: Source directory to watch.
- `--out <path>`: Output directory to write build artifacts.
- `--config <path>`: Darklua config file path.
- `--poll <seconds>`: Poll interval in seconds.
- `--no-prune`: Disable removing outputs for deleted sources.
- `--verbose`: Enable verbose logging.
- `--serve`: Start `rojo serve` using the rewritten project file.
- `--project <path>`: Input Rojo project file path.
- `--project-out <path>`: Output Rojo project file path.
- `--sourcemap`: Enable `rojo sourcemap --watch`.
- `--sourcemap-out <path>`: Sourcemap output path.
