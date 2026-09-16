# Mewati Panel

Private Flutter APK. Sirf tere phone pe. Cloudflare R2 + billing + Supabase catalog, KYC, upload, SQL, live listeners.

**Public git pe asli keys mat daalna.** `lib/secrets.dart` gitignore pe hai. Clone ke baad `cp lib/secrets.example.dart lib/secrets.dart`.

## 1. Secrets

`lib/secrets.dart` kholo, `PASTE_*` hatao:

| Field | Kahan se |
|---|---|
| `r2AccountId` / `r2AccessKey` / `r2SecretKey` | R2 → Manage R2 API Tokens → Admin Read & Write |
| `cfApiToken` | Profile → API Tokens → Billing Read + Analytics Read (`cfat_…`) |
| `supabaseServiceKey` | Supabase → Settings → API → `service_role` |
| `dbPassword` | Supabase → Settings → Database → password |

Public URL `mewati-songs` already set hai.

## 2. APK (local)

```bash
flutter pub get
flutter test
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`

Keystore nahi to debug-signed release. Apna keystore: `android/key.properties.example` → `android/key.properties`.

## 3. GitHub

Private repo rakho.

```bash
cd mewati_admin
git init
git add .
git commit -m "Mewati Panel"
git branch -M main
git remote add origin YOUR_PRIVATE_REPO
git push -u origin main
```

Push se pehle `secrets.dart` me `PASTE_` check karo. Keys fill karke APK **local** banao, ya private repo pe keys ke saath push karke Actions chalao.

Actions: **Build Admin APK** → artifact.

## Tabs

| Tab | Kaam |
|---|---|
| Home | Live, KYC, R2 vs player, Cloudflare bill/quota, alerts, Scan/Upload |
| Storage | Buckets, folders, create/delete, scan, bulk upload (2 parallel) |
| Catalog | Gap, duplicates, folders |
| People | Live IP/city · singer KYC |
| Lab | SQL |

182 pehle se DB me hain — Sync unhe dubara insert nahi karega.
