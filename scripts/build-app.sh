#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
app_name="WordClock"
bundle_root="$project_root/outputs/$app_name.app"
contents="$bundle_root/Contents"

cd "$project_root"
for architecture in arm64 x86_64; do
    swiftc \
        -O \
        -parse-as-library \
        -framework AppKit \
        -framework EventKit \
        -framework ServiceManagement \
        -target "$architecture-apple-macosx14.0" \
        Sources/WordClock/*.swift \
        -o "$project_root/work/$app_name-$architecture"
done

lipo -create \
    "$project_root/work/$app_name-arm64" \
    "$project_root/work/$app_name-x86_64" \
    -output "$project_root/work/$app_name"

rm -rf "$bundle_root"
mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$project_root/work/$app_name" "$contents/MacOS/$app_name"
cp "Support/Info.plist" "$contents/Info.plist"

xattr -cr "$bundle_root"
codesign --force --deep --sign - "$bundle_root"
echo "$bundle_root"
