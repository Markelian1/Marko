# App për Regjistrime Faturash

Ky projekt është një aplikacion i thjeshtë **front-end** për menaxhim faturash.
Qëllimi i tij është të të japë një bazë të qartë që mund ta zgjerosh më tej.

## Çfarë bën aktualisht

- Regjistron faturat e reja (nr. fature, klient, datë, shumë, status).
- Ruan të dhënat në `localStorage` (pra në shfletues, pa backend).
- Lejon kërkim sipas nr. faturës ose klientit.
- Lejon filtrim sipas statusit.
- Llogarit statistika:
  - numri i faturave,
  - shuma totale,
  - të paguara,
  - të papaguara.
- Lejon fshirje individuale dhe fshirje totale.

---

## Si ta realizosh hap pas hapi (lokalisht)

### 1) Klono ose hap projektin

```bash
git clone <repo-url>
cd Marko
```

Nëse e ke tashmë projektin, vetëm futu te dosja:

```bash
cd /workspace/Marko
```

### 2) Nise një server statik

Mënyra më e thjeshtë me Python:

```bash
python3 -m http.server 4173
```

### 3) Hape në browser

Vizito:

```text
http://localhost:4173
```

### 4) Testo rrjedhën bazë

- Shto një faturë të re nga forma.
- Verifiko që shfaqet në tabelë.
- Përdor kërkimin dhe filtrin e statusit.
- Rifresko faqen: të dhënat duhet të mbesin (sepse ruhen në `localStorage`).

---

## Si ta zgjerosh në version profesional

Nëse do app "real" për biznes, zakonisht të duhen këto 4 hapa:

### Hapi A — Backend + Database

Shto backend (p.sh. Node.js/Express ose Laravel) dhe databazë (PostgreSQL/MySQL).

Model minimal i faturës në DB:

- `id`
- `invoice_number` (unik)
- `client_name`
- `invoice_date`
- `amount`
- `status`
- `created_at`

### Hapi B — API (CRUD)

Ndërto endpoint-e:

- `GET /api/invoices`
- `POST /api/invoices`
- `PUT /api/invoices/:id`
- `DELETE /api/invoices/:id`

Pastaj në `app.js`, zëvendëso `localStorage` me thirrje `fetch` drejt API-së.

### Hapi C — Autentikim & role

Shto login dhe role p.sh.:

- `admin` (menaxhon gjithçka)
- `operator` (shton/ndryshon fatura)
- `viewer` (vetëm lexon)

### Hapi D — Raporte & eksport

- Eksport në PDF/Excel.
- Filtrim sipas intervalit të datës.
- Dashboard me totalet mujore.

---

## Strukturë e thjeshtë e projektit

- `index.html` — forma, filtra, tabela.
- `styles.css` — dizajni.
- `app.js` — logjika e faturave dhe ruajtja lokale.
- `README.md` — dokumentimi.

---

## Problemet më të zakonshme

### Porti i zënë

Nëse `4173` është i zënë:

```bash
python3 -m http.server 8080
```

dhe hap:

```text
http://localhost:8080
```

### Të dhënat nuk ruhen

Kontrollo nëse browser-i ka të aktivizuar `localStorage` dhe nuk je në private mode me kufizime.

### Karakteret shqip / renditja

Aplikacioni përdor UTF-8 dhe normalizim për kërkim më të mirë, por nëse ke të dhëna nga burime të ndryshme, bëj gjithmonë trim/normalizim në backend.

---

## Rekomandim praktik

Nëse do, në hapin tjetër mund ta kalojmë këtë projekt nga "statik" në "full-stack":

1. Node.js + Express API
2. PostgreSQL
3. Login me JWT
4. Deploy në Render/Railway/Vercel

Kjo do ta bëjë aplikacionin të gatshëm për përdorim real nga ekipi.
