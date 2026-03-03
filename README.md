# apptk

Unified mobile app inspection CLI. Extracts metadata from iOS IPAs (pure Swift) and Android APKs (Kotlin via JNI).

```
apptk ipa info <path>      # IPA metadata
apptk apk info <path>      # APK metadata (stub — prints "WIP FROM KOTLIN")
apptk info <path>           # Auto-detect by extension
```

## Requirements

- macOS 15+
- Swift 6.2+ (ships with Xcode 26+)
- JDK 17+ (`brew install openjdk@17`)
- [just](https://github.com/casey/just) (`brew install just`)

## Setup

Set `JAVA_HOME` if it isn't already (the build falls back to `/opt/homebrew/opt/openjdk@17` on macOS):

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

## Build & Run

```sh
# Build the Kotlin JAR, then the Swift CLI
just build

# Run directly (builds JAR first)
just run ipa info path/to/app.ipa
just run apk info path/to/app.apk
just run info path/to/app.ipa   # auto-detect

# Run tests
just test

# Install to ~/.local/bin
just install
```

### Without just

```sh
# 1. Build the Kotlin fat JAR
cd kotlin && ./gradlew jar && cd ..

# 2. Build Swift CLI
swift build

# 3. Run
swift run apptk ipa info path/to/app.ipa
```

## Project Structure

```
apptk/
├── Package.swift                  # SPM manifest (ArgumentParser + swift-java)
├── Justfile
├── Sources/apptk/
│   ├── AppTK.swift                # Root command
│   ├── swift-java.config          # Java-to-Swift class mappings
│   ├── Commands/
│   │   ├── InfoCommand.swift      # Auto-detect wrapper
│   │   ├── APK/                   # apk subcommand group
│   │   └── IPA/                   # ipa subcommand group
│   ├── Parsers/
│   │   └── IPAInfoParser.swift    # Unzip + plist + codesign + lipo
│   ├── Models/
│   │   └── IPAInfo.swift
│   └── Utils/
│       ├── Shell.swift            # Process wrapper
│       └── Formatter.swift        # ANSI-colored output
├── kotlin/                        # Gradle subproject → fat JAR
│   └── src/main/kotlin/com/apptk/
│       └── APKInspector.kt        # Stub (returns "WIP FROM KOTLIN")
└── Tests/AppTKTests/
    └── IPAInfoParserTests.swift
```
