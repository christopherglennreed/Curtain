#!/bin/bash

# Build and Package Curtain

set -e

echo "Building Curtain..."
rm -rf .build
swift build

echo "Creating app bundle..."
rm -rf dist
mkdir -p dist/Curtain.app/Contents/MacOS
mkdir -p dist/Curtain.app/Contents/Resources

# Copy executable
cp .build/debug/Curtain dist/Curtain.app/Contents/MacOS/

# Copy icon
cp curtain.png dist/Curtain.app/Contents/Resources/

# Create Info.plist
cat > dist/Curtain.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Curtain</string>
    <key>CFBundleIdentifier</key>
    <string>com.christopherreed.curtain</string>
    <key>CFBundleName</key>
    <string>Curtain</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Creating installer package..."
pkgbuild --root dist \
         --identifier com.christopherreed.curtain \
         --version 1.0.0 \
         --install-location /Applications \
         Curtain-1.0.0.pkg

echo "Done! Package created: Curtain-1.0.0.pkg"
echo "Users can install by double-clicking the .pkg file"
