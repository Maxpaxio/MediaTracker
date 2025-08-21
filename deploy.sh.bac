#!/bin/bash
set -e

# === Config ===
REPO=git@github.com:maxpaxio/TV-Tracker.git   # your repo
BRANCH=gh-pages
REPO_PATH="/TV-Tracker/"                      # must match repo name exactly (case sensitive)

echo "🚀 Clean & build"
flutter clean
flutter pub get
flutter build web --release --base-href "$REPO_PATH"

# SPA refresh fix
cp build/web/index.html build/web/404.html

echo "📂 Preparing deploy folder"
rm -rf .deploy-tmp
mkdir .deploy-tmp
cp -r build/web/* .deploy-tmp/

echo "🚀 Deploy to GitHub Pages"
cd .deploy-tmp
git init
git checkout --orphan $BRANCH   # orphan ensures no conflicts, ignores existing refs
git add .
git commit -m "Deploy to GitHub Pages ($(date))"
git remote add origin $REPO
git push origin $BRANCH --force
cd ..
rm -rf .deploy-tmp

echo "✅ Done! Site should be live at:"
echo "   https://maxpaxio.github.io$REPO_PATH"