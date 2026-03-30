# App për Regjistrime Faturash

Ky është një aplikacion i thjeshtë frontend (HTML/CSS/JavaScript) për:
- regjistrimin e faturave,
- kërkimin e tyre sipas klientit ose numrit të faturës,
- ruajtjen lokale të të dhënave në `localStorage`,
- eksportimin në format CSV.

## Si të përdoret lokalisht

1. Hap `index.html` në shfletues.
2. Plotëso formularin dhe kliko **Shto faturën**.
3. Përdor fushën e kërkimit për filtrim.
4. Përdor **Eksporto CSV** për shkarkim.
5. Përdor **Fshi të gjitha** për të fshirë regjistrimet.

## Publikimi në Render

Ky repo është gati për Render me `render.yaml`.

### Opsioni 1 (më i lehtë): me GitHub
1. Krijo një repository në GitHub dhe ngarko këto file.
2. Shko te [render.com](https://render.com) dhe hyr me llogarinë tënde.
3. Kliko **New +** → **Blueprint**.
4. Zgjidh repository-n tënd.
5. Render lexon automatikisht `render.yaml` dhe e publikon si **Static Site**.

### Opsioni 2: manual në Render
1. **New +** → **Static Site**.
2. Lidhe me repository-n në GitHub.
3. Vendos:
   - **Build Command**: `echo "No build step needed"`
   - **Publish Directory**: `.`
4. Kliko **Create Static Site**.

Pas deploy, Render të jep një URL publike (p.sh. `https://regjistrime-faturash.onrender.com`).

## Ku t’i dërgosh kodet

Më e mira është t’i dërgosh në një nga këto forma:
- **GitHub repo link** (rekomandohet), ose
- **ZIP file** me `index.html`, `app.js`, `styles.css`, `README.md`, `render.yaml`.

Nëse do që ta publikojmë bashkë hap pas hapi, më dërgo linkun e GitHub repo-s.

## Shënim

Të dhënat ruhen vetëm në shfletuesin lokal të pajisjes ku përdoret aplikacioni.
