#!/usr/bin/env bash
set -e

# Packages
sudo apt-get update -y
sudo apt-get install -y curl unzip xz-utils libgtk-3-0 libglu1-mesa

# Flutter
FLUTTER_VERSION=3.22.0
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -o /tmp/flutter.tar.xz
sudo tar -C /usr/local -xJf /tmp/flutter.tar.xz
echo 'export PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH"' >> ~/.bashrc
export PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:$PATH"

# Enable web
flutter --version
flutter config --enable-web
flutter precache --web

# Chrome (for web-server we don’t strictly need GUI chrome, but it’s fine to have)
# Optional: comment these lines if you prefer using the "web-server" device only
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-linux.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get update -y && sudo apt-get install -y google-chrome-stable || true
