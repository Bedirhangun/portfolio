# Portfolio — bedirhangundoner.dev

Kişisel portfolio sitem. Astro ile yazılmış, tamamen statik bir site.

## Hızlı başlangıç

```bash
npm install      # bağımlılıkları kur (bir kez)
npm run dev      # geliştirme sunucusu → http://localhost:4321
npm run build    # production çıktısı → dist/ klasörü
npm run preview  # dist/ içeriğini local'de test et
```

## Proje yapısı

```
portfolio/
├── astro.config.mjs      # Astro ayarları (site URL'i burada)
├── package.json          # bağımlılıklar ve komutlar
├── public/               # olduğu gibi kopyalanan dosyalar (favicon, CV.pdf vb.)
├── src/
│   ├── pages/
│   │   └── index.astro   # ana sayfa — TÜM İÇERİK BURADA
│   └── styles/
│       └── global.css    # renk paleti ve genel stiller
└── dist/                 # build çıktısı (git'e girmez)
```

## İçerik nasıl güncellenir?

`src/pages/index.astro` dosyasının en üstündeki (`---` blokları arası) iki diziyi düzenle:

- `projects` → proje kartları (başlık, açıklama, etiketler)
- `skills` → yetenek etiketleri

Renkleri değiştirmek için `src/styles/global.css` içindeki `:root` değişkenlerine bak
(`--accent` ana vurgu rengi).

## Nasıl yayınlanır?

Ayrıntılı mimari ve deploy süreci için [docs/RUNBOOK.md](docs/RUNBOOK.md) dosyasına bak.
Kısaca: `main` branch'ine push → Cloudflare Pages otomatik build alıp yayınlar.
