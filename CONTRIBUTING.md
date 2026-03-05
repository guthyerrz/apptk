# Contributing to apptk

## Requirements

- macOS 15+
- Swift 6.2+ (ships with Xcode 26+)
- [just](https://github.com/casey/just) (`brew install just`)

## Build & Run

```sh
# Build the Swift CLI
just build

# Run directly
just run ipa info path/to/app.ipa
just run info path/to/app.ipa   # auto-detect

# Run tests
just test

# Install to ~/.local/bin
just install
```

### Without just

```sh
# 1. Build Swift CLI
swift build

# 2. Run
swift run apptk ipa info path/to/app.ipa
```

## Project Structure

```
apptk/
├── Package.swift                  # SPM manifest (ArgumentParser)
├── Justfile
├── Sources/
│   ├── apptk/                     # CLI entry point
│   │   └── AppTK.swift            # Root command
│   ├── AppTKKit/                  # Top-level module re-exporting submodules
│   ├── AppTKCore/                 # Shared types and utilities
│   ├── AppTKMachO/                # Mach-O binary parsing and dylib injection
│   ├── AppTKInfo/                 # Info commands (IPA metadata inspection)
│   │   └── Commands/
│   │       ├── InfoCommand.swift      # Auto-detect wrapper
│   │       └── IPAInfoCommand.swift   # IPA metadata extraction
│   └── AppTKPatch/                # Patch commands (binary modification)
│       └── Commands/
│           ├── PatchCommand.swift     # Patch subcommand group
│           └── IPAPatchCommand.swift  # IPA patching with framework injection
└── Tests/AppTKTests/
    └── IPAInfoParserTests.swift
```

## Architecture

| Module | Responsibility |
|--------|---------------|
| **apptk** | CLI entry point — wires up ArgumentParser commands |
| **AppTKKit** | Umbrella module that re-exports all submodules |
| **AppTKCore** | Shared types, shell utilities, formatters, plist entry types |
| **AppTKMachO** | Mach-O header parsing and `LC_LOAD_DYLIB` injection |
| **AppTKInfo** | `info` and `ipa info` commands — IPA metadata extraction |
| **AppTKPatch** | `patch ipa` command — step-based IPA patching pipeline (unzip, inject, re-sign, repack) |
