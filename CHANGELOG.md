# Changelog

## 1.0.0 (build 3) — 2026-10-18

**Opgelost**
- Er laadden geen kunstwerken. Oorzaak: de beeldserver van het Art Institute of Chicago blokkeert apps nu met een Cloudflare-botcheck (HTTP 403), en The Met heeft zijn oude zoek-API (`/v1/search`) op 1 oktober 2026 uitgezet. TVArt gebruikt nu de nieuwe Met-zoek-API (`/v1.1/search`) plus het **Cleveland Museum of Art** (Open Access, CC0).
- Rustig tempo richting The Met (max. 3 gelijktijdige verzoeken); bij een 403/429 stopt de app die sessie met The Met en gaat hij verder met Cleveland.
- Collecties worden 7 dagen op het apparaat bewaard: sneller openen en minder verzoeken.
- Schilderijen staan bovenaan, daarna tekeningen en prenten.
- Salvador Dalí verwijderd (niet publiek domein, er kwam nooit iets) en vervangen door Frans Hals.

**Nieuw**
- Instellingen in Apple TV-stijl, zoals de Instellingen-app: het kunstwerk links en een lijst rechts. Eén klik zet een optie aan/uit of kiest de volgende waarde, met Menu ga je terug. Opent schermvullend.
- De app is volledig Nederlands en Engels en volgt de taal van het apparaat; bij andere talen wordt Engels gebruikt (String Catalog met meervoudsvormen).

## 1.0.0 (build 2) — 2026-10-18

**Nieuw**
- Nieuwe filmische splashscreen: het schilderij komt onder een museumspot scherp in beeld, het vergulde TVArt-woordmerk verschijnt met een lichtschittering en de tagline volgt. Respecteert "Verminder beweging".
- Nieuw gelaagd app-icoon (parallax): oxbloedrode museummuur, een eigen impasto-landschap en een vergulde museumlijst. Plus nieuwe Top Shelf-afbeeldingen (standaard en breed).
- Vernieuwd startscherm met hero-banner en echte kunstwerk-covers per kunstenaar in plaats van symbolen.
- "Mijn favorieten" als eigen collectie op het startscherm (favorieten worden nu met titel/afbeelding bewaard).
- Museumbordje (titel, kunstenaar, jaar, bron) bij elk werk, verdwijnt automatisch.
- Weergave-instelling: Automatisch / Volledig werk tonen / Beeldvullend, met vervaagde achtergrond bij staande werken.
- Instellingen sluiten automatisch na een minuut zonder wijziging (tegen inbranden); zwevende klok beweegt rustig over het scherm.
- Bundled lettertype Cormorant Garamond (SIL OFL) voor de huisstijl.

**Opgelost**
- App-icoon en Top Shelf werden nooit gebruikt: de afbeeldingen stonden in `BrandingAssets/` buiten de asset catalog en `ASSETCATALOG_COMPILER_APPICON_NAME` ontbrak. Nu correct als `App Icon & Top Shelf Image.brandassets` met App Store-icoon (1280×768 + @2x).
- Siri Remote-bediening in de tentoonstelling werkte niet zodra de knoppen verborgen waren (geen focusbaar element). Nieuwe bediening: ◀ ▶ bladeren, ▲ favoriet, ▼/klik bordje, ⏯ pauze, klik ingedrukt houden = instellingen, Menu = terug.
- Ken Burns-zoom startte niet bij nieuwe werken; nu per werk een langzame drift vanuit een wisselend ankerpunt.
- Zwart flitsen/spinner tussen schilderijen: beelden worden nu vooraf geladen en vloeiend overgevloeid.
- Willekeurige volgorde kon hetzelfde werk vaak herhalen; nu een geschudde volgorde zonder directe herhaling.
- Instellingen in `@AppStorage` binnen een ObservableObject ververste de UI niet betrouwbaar; omgezet naar `@Published` + UserDefaults.
- "Bedieningstips tonen" deed niets; nu gekoppeld aan de tips onder het museumbordje.
- Overzichtsraster laadde volledige 1686px-afbeeldingen als thumbnail; nu lichte thumbnails (600px / Met small).
- Grote museumscans (20+ MP) worden nu naar 4K verkleind bij het decoderen, zodat de Apple TV niet zonder geheugen komt.
- Snel achter elkaar ◀/▶ drukken telt nu correct op en toont nooit een ouder werk; bordje en favoriet horen altijd bij het werk in beeld.
- Werken zonder kunstenaarsnaam (anoniem) verschijnen niet meer onder een kunstenaar.
- Met-API haalde 24 objecten één voor één op; nu in kleine parallelle batches (sneller laden).
- Info.plist opgeschoond (iOS-oriëntaties verwijderd, `ITSAppUsesNonExemptEncryption`, lanceerkleur, fonts).
- Development Team ingesteld op EU3UY476T6, gedeeld Xcode-scheme toegevoegd.

## 1.0.0 (build 1) — 2026-10-18

- Initial native Apple TV release project.
- Artist-first browsing with 18 artist and period selections.
- Live public-domain artworks from Chicago and Metropolitan Museum collections.
- Full-screen timed art display with zoom, shuffle, remote control, clock, favorites and settings.
