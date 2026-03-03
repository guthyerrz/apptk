build-jar:
    cd kotlin && ./gradlew jar

build: build-jar
    swift build -c release

test:
    swift test

run *ARGS: build-jar
    swift run apptk {{ARGS}}

install: build
    cp .build/release/apptk ~/.local/bin/
