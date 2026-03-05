doctor:
    ./scripts/doctor.sh

build:
    swift build -c release

test:
    swift test

run *ARGS:
    swift run apptk {{ARGS}}

install: build
    cp .build/release/apptk bin/
