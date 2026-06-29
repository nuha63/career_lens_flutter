#!/bin/bash
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Getting packages..."
flutter pub get

echo "Building web..."
flutter build web --release

echo "Build complete!"
