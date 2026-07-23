#!/usr/bin/env bash
# Statik bir siteyi GitHub Pages'te yayınlar (repo oluşturma dahil).
#
# Kullanım:
#   ./publish-site.sh <proje-klasörü> [repo-adı]
#   örn: ./publish-site.sh ~/Documents/GitHub/yeni-site
#
# Yaptıkları:
#   1. Klasörde git repo yoksa başlatır, değişiklikleri commit'ler
#   2. GitHub'da repo yoksa oluşturur (keychain'deki token ile)
#   3. Astro projesiyse Pages workflow'unu ekler (yoksa)
#   4. Push'lar ve GitHub Pages'i etkinleştirir
#
# Gereksinim: git push'un çalıştığı bir GitHub oturumu (osxkeychain'de token).

set -euo pipefail

DIR="${1:?Kullanım: publish-site.sh <proje-klasörü> [repo-adı]}"
DIR="$(cd "$DIR" && pwd)"
NAME="${2:-$(basename "$DIR")}"
USER_LOGIN=""

token() {
  printf "protocol=https\nhost=github.com\n" | git credential fill 2>/dev/null \
    | awk -F= '/^password/{print $2}'
}

api() { # api <method> <path> [json-body]
  local method="$1" path="$2" body="${3:-}"
  curl -s -X "$method" "https://api.github.com$path" \
    -H "Authorization: Bearer $(token)" \
    -H "Accept: application/vnd.github+json" \
    ${body:+-d "$body"}
}

USER_LOGIN=$(api GET /user | python3 -c "import json,sys;print(json.load(sys.stdin)['login'])")
echo "GitHub kullanıcısı: $USER_LOGIN — repo: $NAME"

cd "$DIR"

# 1. Git repo + commit
if [ ! -d .git ]; then
  git init -q
  printf 'node_modules/\ndist/\n.astro/\n' > .gitignore
fi
git add -A
git diff --cached --quiet || git commit -qm "chore: publish"

# 2. GitHub'da repo oluştur (varsa hata verme)
if ! api GET "/repos/$USER_LOGIN/$NAME" | grep -q '"full_name"'; then
  api POST /user/repos "{\"name\":\"$NAME\",\"private\":false}" > /dev/null
  echo "Repo oluşturuldu: https://github.com/$USER_LOGIN/$NAME"
fi
git remote get-url origin >/dev/null 2>&1 || \
  git remote add origin "https://github.com/$USER_LOGIN/$NAME.git"

# 3. Astro ise workflow ekle
if [ -f package.json ] && grep -q '"astro"' package.json && [ ! -f .github/workflows/deploy.yml ]; then
  mkdir -p .github/workflows
  cat > .github/workflows/deploy.yml <<'YAML'
name: Deploy to GitHub Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: withastro/action@v3
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
YAML
  git add .github && git commit -qm "ci: GitHub Pages workflow"
  echo "UYARI: astro.config.mjs içine base: '/$NAME' eklemeyi unutma!"
fi

# 4. Push + Pages'i aç
git branch -M main
git push -qu origin main
api POST "/repos/$USER_LOGIN/$NAME/pages" '{"build_type":"workflow"}' > /dev/null || true

echo "Tamam. Birkaç dakika içinde yayında: https://$USER_LOGIN.github.io/$NAME/"
echo "Build durumu: https://github.com/$USER_LOGIN/$NAME/actions"
