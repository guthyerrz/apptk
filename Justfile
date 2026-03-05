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

install clean="false": (build clean)
    cp .build/release/apptk bin/
