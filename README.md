# App për Regjistrime Faturash

Ky projekt është një aplikacion i thjeshtë **front-end** për menaxhim faturash.

## Çfarë bën aktualisht

- Regjistron faturat e reja (nr. fature, klient, datë, shumë, status).
- Ruan të dhënat në `localStorage` (pa backend).
- Lejon kërkim dhe filtrim sipas statusit.
- Llogarit statistika (numri i faturave, totali, të paguara, të papaguara).
- Lejon fshirje individuale dhe totale.

---

## Ku do shkojë ky kod?

Ke 3 opsione të thjeshta:

1. **Në kompjuterin tënd (lokalisht)**
   - E përdor vetëm ti, për testim.
2. **Në GitHub (ruajtje/versionim)**
   - E ruan si projekt me histori ndryshimesh.
3. **Në hosting (që të hapet online me link)**
   - P.sh. Netlify, Vercel, GitHub Pages.

> Ky projekt është statik (`index.html`, `styles.css`, `app.js`), prandaj mund të publikohet direkt në platformat e mësipërme.

---

## Si ta realizosh tani (hap pas hapi)

## 1) Krijo projektin lokalisht

```bash
git clone <repo-url>
cd Marko
```

Nëse je tashmë te projekti:

```bash
cd /workspace/Marko
```

## 2) Testoje lokalisht

Nise serverin:

```bash
python3 -m http.server 4173
```

Hape në browser:

```text
http://localhost:4173
```

Kontrollo:
- shto një faturë,
- filtro/kërko,
- rifresko faqen (duhet të mbetet në `localStorage`).

---

## 3) Kaloje kodin në GitHub (rekomandohet)

Nëse nuk e ke bërë ende:

```bash
git init
git add .
git commit -m "Initial invoice app"
git branch -M main
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main
```

Pas këtij hapi, kodi yt është online në GitHub.

---

## 4) Publikoje app-in online (2 mënyra më të lehta)

### Opsioni A — Netlify (shumë i thjeshtë)

1. Hyr te [https://netlify.com](https://netlify.com)
2. **Add new site** → **Import from Git**
3. Zgjidh repo-n në GitHub
4. Build command: *(lëre bosh)*
5. Publish directory: `.`
6. Kliko **Deploy site**

Do marrësh një link p.sh. `https://emri-yt.netlify.app`.

### Opsioni B — GitHub Pages

1. Shko te repo në GitHub
2. **Settings** → **Pages**
3. **Source**: Deploy from a branch
4. Branch: `main`, folder: `/root`
5. **Save**

Pas pak minutash del linku p.sh. `https://username.github.io/repo`.

---

## E rëndësishme (për këtë version)

Ky version ruan faturat në `localStorage`, pra:

- të dhënat ruhen **vetëm në browser-in e atij përdoruesi**;
- nuk ka databazë qendrore;
- nuk ka login multi-user.

Nëse futesh nga telefon tjetër ose browser tjetër, nuk i sheh të njëjtat të dhëna.

---

## Si ta bësh app real për biznes

Duhet ta kalosh në arkitekturë me backend + databazë:

1. **Backend** (Node.js/Express ose Laravel)
2. **Database** (PostgreSQL/MySQL)
3. **API CRUD** (`GET/POST/PUT/DELETE /api/invoices`)
4. **Autentikim** (JWT + role)
5. **Deploy**
   - Frontend: Vercel/Netlify
   - Backend + DB: Render/Railway/Supabase

---

## Struktura e projektit

- `index.html` — forma, tabela, filtrat.
- `styles.css` — dizajni.
- `app.js` — logjika, `localStorage`, renderimi.
- `README.md` — udhëzuesi.

---

## Probleme të zakonshme

### Porti 4173 i zënë

Përdor port tjetër:

```bash
python3 -m http.server 8080
```

Pastaj hap:

```text
http://localhost:8080
```

### Nuk ruhen të dhënat

- mos përdor private/incognito mode me kufizime;
- verifiko që browser-i lejon `localStorage`.

---

## Çfarë të bësh tani konkretisht

Nëse pyetja jote është: **"Ku ta kaloj këtë kod?"**, përgjigjja praktike është:

1. Kaloje në **GitHub** (ruajtje dhe backup).
2. Publikoje në **Netlify** (ta hapësh me link online).
3. Kur të jesh gati për përdorim real nga ekipi, bëjmë versionin me backend+database.
