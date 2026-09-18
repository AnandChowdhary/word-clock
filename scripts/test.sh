#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"

swiftc \
    "$project_root/Sources/WordClock/WordTimeFormatter.swift" \
    "$project_root/Tests/Runner/main.swift" \
    -o "$project_root/work/word-clock-tests"

"$project_root/work/word-clock-tests"
