doctor:
    ./scripts/doctor.sh

build clean="false":
    #!/usr/bin/env bash
    if [[ "{{ clean }}" == "true" ]]; then
        swift package clean
    fi
    swift build -c release

test:
    swift test

run *ARGS:
    swift run apptk {{ARGS}}

set-version v:
    echo 'let apptkVersion = "{{ v }}"' > Sources/AppTKKit/Version.swift

universal-build:
    swift build -c release --arch arm64
    swift build -c release --arch x86_64
    lipo -create .build/arm64-apple-macosx/release/apptk .build/x86_64-apple-macosx/release/apptk -output .build/release/apptk
    chmod +x .build/release/apptk

release v: (set-version v) universal-build
    just set-version dev

install clean="false": (build clean)
    mkdir -p ~/.local/bin
    cp .build/release/apptk ~/.local/bin/
