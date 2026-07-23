# RUNBOOK — Mimari, DevOps ve Sıfırdan Ayağa Kaldırma

Bu doküman, bu sitenin **ne olduğunu, neden böyle kurulduğunu ve hiçbir yardım
almadan sıfırdan nasıl ayağa kaldırılacağını** anlatır.

---

## 1. Mimari: Ne yaptık, neden?

### Site "statik" — bu ne demek?

Bu sitenin bir backend'i (sunucuda çalışan kodu) **yok**. `npm run build`
çalıştığında Astro, `.astro` dosyalarını alıp düz HTML + CSS dosyalarına çevirir
ve `dist/` klasörüne koyar. Yayınlanan şey sadece bu dosyalardır.

```
src/pages/index.astro  ──(npm run build)──▶  dist/index.html + CSS
```

Sonuç: veritabanı yok, çalışan process yok, güvenlik yaması gerektiren sunucu
yazılımı yok. Bir web sunucusunun dosyaları olduğu gibi servis etmesi yeterli.

### Neden Astro?

- Çıktısı saf HTML/CSS — tarayıcıya JavaScript göndermez (istemedikçe).
- Component mantığı var (React benzeri) ama build sırasında çözülür.
- İleride blog eklemek istersek Markdown desteği hazır.

Alternatifler: düz HTML yazmak (küçük kalırsa yeterli ama tekrar çoğalır),
Next.js (bu iş için gereksiz ağır).

### Barındırma: Neden Cloudflare Pages, neden kendi sunucumuz değil?

| | Cloudflare Pages | Kendi VPS'imiz |
|---|---|---|
| Maliyet | Ücretsiz | ~€5/ay |
| SSL sertifikası | Otomatik | Bizim işimiz (Caddy halleder) |
| Dünya geneli hız (CDN) | Var, otomatik | Yok (tek lokasyon) |
| Bakım | Sıfır | İşletim sistemi güncellemeleri bizde |

Statik site için VPS harcamaya değmez. **VPS'i mobil uygulama backend'leri için
saklıyoruz** — onlar çalışan process gerektirdiği için Pages'te barınamaz.
(Bkz. bölüm 5: hedef mimari.)

---

## 2. Deploy süreci: Push'tan yayına ne oluyor?

```
git push (main)
   │
   ▼
GitHub  ──webhook──▶  Cloudflare Pages
                          │  1. repo'yu klonlar
                          │  2. npm install && npm run build çalıştırır
                          │  3. dist/ içeriğini CDN'ine dağıtır
                          ▼
                      https://<proje>.pages.dev  (ve bağlıysa kendi domain)
```

Buna **CI/CD** denir: kod push'lanınca build ve yayın otomatik tetiklenir.
Elle hiçbir dosya kopyalanmaz; "sunucuya dosya atmayı unutmak" diye bir hata
sınıfı yoktur. Ayrıca her PR/branch için otomatik önizleme URL'i oluşur.

**Rollback:** Cloudflare Pages panelinde eski deploy'lardan birine "Rollback"
diyebilirsin; ya da git'te `git revert` ile kötü commit'i geri alıp push'larsın.

---

## 3. Sıfırdan ayağa kaldırma (yeni bilgisayar / felaket senaryosu)

Gereken tek şey: git repo'su (GitHub'da duruyor) + Node.js.

```bash
# 1. Node.js kur (macOS): https://nodejs.org veya
brew install node

# 2. Repo'yu çek
git clone git@github.com:Bedirhangun/portfolio.git
cd portfolio

# 3. Bağımlılıkları kur ve çalıştır
npm install
npm run dev        # → http://localhost:4321
```

Yayın tarafı zaten Cloudflare'de tanımlı olduğu için hiçbir şey yapmak
gerekmez; `main`'e push atan herkes yayınlamış olur.

### Cloudflare Pages'i sıfırdan bağlamak (hesap silinirse / yeni proje)

1. https://dash.cloudflare.com → **Workers & Pages → Create → Pages →
   Connect to Git**
2. GitHub hesabını yetkilendir, `portfolio` repo'sunu seç.
3. Build ayarları:
   - Framework preset: **Astro**
   - Build command: `npm run build`
   - Build output directory: `dist`
4. **Save and Deploy** — 1-2 dakikada `https://<proje>.pages.dev` yayında.
5. Kendi domain'i bağlamak: proje → **Custom domains → Set up a custom domain**.
   Domain Cloudflare'deyse DNS kaydı otomatik eklenir, SSL otomatik gelir.

---

## 4. Alternatif: Docker ile kendi sunucunda yayınlamak

Şu an buna ihtiyaç yok, ama VPS'e geçtiğimizde site de dahil her şey bu
kalıpla çalışacak. Mantık: **build sonucu (dist/) bir Nginx imajının içine
gömülür**, ortaya çıkan imaj her yerde aynı şekilde çalışır.

Repo'daki [`Dockerfile`](../Dockerfile):

```dockerfile
# Aşama 1: build — Node imajında siteyi derle
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Aşama 2: runtime — sadece statik dosyalar + nginx kalır (~10 MB)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
```

Buna **multi-stage build** denir: Node, node_modules vb. build aracı olan her
şey ilk aşamada kalır; yayına giden imajda sadece HTML/CSS + nginx olur.

```bash
docker build -t portfolio .
docker run -p 8080:80 portfolio   # → http://localhost:8080
```

VPS'te bunun önüne Caddy (reverse proxy) girer — bkz. bölüm 5.

---

## 5. Hedef mimari: Tek VPS'te her şey

Mobil uygulama backend'leri gelince kurulacak yapı (referans için):

```
İnternet
   │ :80/:443
   ▼
┌──────────────────────────── VPS (Hetzner, ~€5/ay) ────────────────────────┐
│  Caddy (reverse proxy + otomatik SSL)                                     │
│    ├── asesisitme.com        → container: ases-web                        │
│    ├── api.app1.bedirhan.dev → container: app1-api (.NET)                 │
│    └── api.app2.bedirhan.dev → container: app2-api (.NET)                 │
│                                                                           │
│  Postgres (tek container, app başına ayrı database)                       │
│  Hepsi tek docker-compose.yml içinde tanımlı                              │
└───────────────────────────────────────────────────────────────────────────┘

Portfolio → Cloudflare Pages'te kalır (VPS'e taşımaya gerek yok)
```

Parçaların görevleri:

- **Caddy**: Dışarıdan gelen tüm HTTP(S) trafiğini karşılar, domain'e göre
  doğru container'a yönlendirir. Let's Encrypt SSL sertifikalarını otomatik
  alır ve yeniler — `Caddyfile`'da domain başına 2-3 satır config.
- **Docker Compose**: Tüm container'ların tanımı tek YAML dosyasında.
  Sunucu değişse bile `git clone` + `docker compose up -d` = her şey ayakta.
- **Postgres + yedekleme**: Günlük `pg_dump` cron'u + yedeklerin sunucu
  dışına (Backblaze B2 / Cloudflare R2) kopyalanması. **Yedeği olmayan
  veritabanı yok sayılır.**

---

## 6. Sözlük

| Terim | Anlamı |
|---|---|
| **Statik site** | Sunucuda kod çalıştırmayan, önceden üretilmiş HTML dosyaları |
| **CDN** | İçeriği dünyanın her yerindeki sunucularda kopyalayıp en yakından sunan ağ |
| **CI/CD** | Push sonrası build ve yayının otomatik yapılması |
| **Reverse proxy** | Trafiği karşılayıp arkadaki doğru servise yönlendiren sunucu (Caddy) |
| **Container / imaj** | Uygulama + tüm bağımlılıklarının tek paket halinde, her makinede aynı çalışan hali |
| **Multi-stage build** | Build araçlarını yayın imajına sokmadan derleme tekniği |
| **VPS** | Kiralık sanal sunucu (Virtual Private Server) |
| **Rollback** | Sorunlu yayını önceki çalışan sürüme geri alma |
