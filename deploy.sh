#!/bin/bash
set -e

REPO_PATH="/TV-Tracker/"   # <-- must match repo name + case

echo "🚀 Clean & build"
flutter clean
flutter pub get
flutter build web --release --base-href "$REPO_PATH"

# SPA refresh fix
cp build/web/index.html build/web/404.html

echo "🛠  Patch <base href> in any generated index.html files"
# macOS/BSD sed needs -i ''
sed -i '' "s|<base href=\"/\">|<base href=\"$REPO_PATH\">|g" build/web/index.html
if [ -f build/web/assets/index.html ]; then
  sed -i '' "s|<base href=\"/\">|<base href=\"$REPO_PATH\">|g" build/web/assets/index.html
fi

echo "🚀 Deploy to gh-pages (orphan)"
git push origin --delete gh-pages 2>/dev/null || true
git branch -D gh-pages 2>/dev/null || true
git checkout --orphan gh-pages
git --work-tree build/web add --all
git --work-tree build/web commit -m "Deploy to GitHub Pages"
git push origin HEAD:gh-pages --force
git checkout -f main
git branch -D gh-pages 2>/dev/null || true

echo "✅ Done. URL:"
echo "   https://maxpaxio.github.io${REPO_PATH}"
