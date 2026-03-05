# apptk

Command-line toolkit for mobile app developers — inspect, patch, and re-sign iOS apps


## Installation

Requires macOS 15+ and Swift 6.2+.

```sh
just install
```

This builds the project and copies the binary to `~/.local/bin/apptk`.

## Usage

### Inspect app metadata

```sh
# Auto-detect by file extension
apptk info path/to/app.ipa

# Explicitly target IPA
apptk ipa info path/to/app.ipa
```

### Patch an IPA

Inject a framework into an IPA, re-sign, and produce a patched output:

```sh
apptk patch ipa path/to/app.ipa --framework path/to/MyFramework.framework
```

#### Options

| Flag | Description |
|------|-------------|
| `--framework <path>` | **(required)** Path to the `.framework` to inject |
| `-o`, `--output <path>` | Output path for the patched IPA (default: `<name>-patched.ipa`) |
| `--signing-identity <id>` | Code signing identity (auto-detected from IPA if omitted) |
| `--provisioning-profile <path>` | Path to a `.mobileprovision` file (auto-detected if omitted) |
| `--bundle-id <id>` | New `CFBundleIdentifier` to set |
| `--plist-string <KEY=VALUE>` | Add a string plist entry (use `:` for nested keys) |
| `--plist-bool <KEY=true\|false>` | Add a boolean plist entry (use `:` for nested keys) |
| `--plist-int <KEY=VALUE>` | Add an integer plist entry (use `:` for nested keys) |

#### Example

```sh
apptk patch ipa app.ipa \
  --framework Inject.framework \
  --bundle-id com.example.patched \
  --signing-identity "Apple Development: you@example.com" \
  --provisioning-profile profile.mobileprovision \
  --plist-string "NSAppTransportSecurity:NSAllowsArbitraryLoads=true" \
  --plist-bool "UIFileSharingEnabled=true" \
  --plist-int "CFBundleVersion=42" \
  -o patched.ipa
```

## Roadmap

- Parse provisioning profile files in pure Swift (remove `security cms` CLI dependency)
- Show provisioning profile details in the `info` command (UUID, devices, capabilities, etc.)
- Automatic signing with Apple account / App Store Connect API key
- APK/Android support (inspect and patch Android packages)

## License

[Apache 2.0](LICENSE)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions, project structure, and development setup.
