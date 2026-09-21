#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_name="WordClock"
bundle_root="$project_root/outputs/$app_name.app"
contents="$bundle_root/Contents"
sparkle_version="2.10.0"
sparkle_archive="$project_root/work/Sparkle-$sparkle_version.tar.xz"
sparkle_root="$project_root/work/sparkle-$sparkle_version"
sparkle_checksum="c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c"

cd "$project_root"
mkdir -p "$project_root/work"

if [[ ! -f "$sparkle_root/Sparkle.framework/Sparkle" ]]; then
    if [[ ! -f "$sparkle_archive" ]]; then
        curl -L --fail --silent --show-error \
            "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" \
            -o "$sparkle_archive"
    fi

    actual_checksum="$(shasum -a 256 "$sparkle_archive" | awk '{print $1}')"
    if [[ "$actual_checksum" != "$sparkle_checksum" ]]; then
        echo "Sparkle archive checksum mismatch" >&2
        exit 1
    fi

    rm -rf "$sparkle_root"
    mkdir -p "$sparkle_root"
    tar -xJf "$sparkle_archive" -C "$sparkle_root"
fi

for architecture in arm64 x86_64; do
    swiftc \
        -O \
        -parse-as-library \
        -F "$sparkle_root" \
        -framework AppKit \
        -framework EventKit \
        -framework ServiceManagement \
        -framework Sparkle \
        -Xlinker -rpath \
        -Xlinker @executable_path/../Frameworks \
        -target "$architecture-apple-macosx14.0" \
        Sources/WordClock/*.swift \
        -o "$project_root/work/$app_name-$architecture"
done

lipo -create \
    "$project_root/work/$app_name-arm64" \
    "$project_root/work/$app_name-x86_64" \
    -output "$project_root/work/$app_name"

rm -rf "$bundle_root"
mkdir -p "$contents/MacOS" "$contents/Resources" "$contents/Frameworks"
cp "$project_root/work/$app_name" "$contents/MacOS/$app_name"
cp "Support/Info.plist" "$contents/Info.plist"
cp "Support/Sparkle-LICENSE.txt" "$contents/Resources/Sparkle-LICENSE.txt"
ditto "$sparkle_root/Sparkle.framework" "$contents/Frameworks/Sparkle.framework"

xattr -cr "$bundle_root"
codesign --force --deep --sign - "$bundle_root"
echo "$bundle_root"
