"""Writes TVArt/Localizable.xcstrings (source: English, translation: Dutch)."""
import json, sys

OUT = sys.argv[1]
plain = {
    "Renaissance": "Renaissance",
    "Piet Mondrian": "Piet Mondriaan",
    "Automatic": "Automatisch",
    "Show whole artwork": "Volledig werk tonen",
    "Fill screen": "Beeldvullend",
    "Untitled": "Zonder titel",
    "Version %@": "Versie %@",
    "Settings": "Instellingen",
    "Exhibition": "Tentoonstelling",
    "Time per artwork": "Tijd per kunstwerk",
    "Display": "Weergave",
    "Shuffle": "Willekeurige volgorde",
    "Slow zoom (Ken Burns)": "Langzame zoom (Ken Burns)",
    "Museum label on each artwork": "Museumbordje bij elk werk",
    "Floating clock": "Zwevende klok",
    "Show remote tips": "Bedieningstips tonen",
    "Siri Remote": "Siri Remote",
    "◀ ▶": "◀ ▶",
    "▲": "▲",
    "▼ / click": "▼ / klik",
    "⏯": "⏯",
    "Hold click": "Klik ingedrukt houden",
    "Previous / next": "Vorige / volgende",
    "Favorite on/off": "Favoriet aan/uit",
    "Show museum label": "Museumbordje tonen",
    "Pause / resume": "Pauze / hervat",
    "About TVArt": "Over TVArt",
    "Artworks are loaded live from the open-access collections of The Metropolitan Museum of Art and the Cleveland Museum of Art. Only works marked public domain by the museum are shown.":
        "Kunstwerken worden live geladen uit de open collecties van The Metropolitan Museum of Art en het Cleveland Museum of Art. Alleen werken die het museum als publiek domein markeert worden getoond.",
    "On": "Aan",
    "Off": "Uit",
    "My favorites": "Mijn favorieten",
    "Saved on this Apple TV": "Bewaard op deze Apple TV",
    "Choose an artist or collection": "Kies een kunstenaar of collectie",
    "Artworks are loaded live from the open-access collections of The Metropolitan Museum of Art and the Cleveland Museum of Art. Internet connection required.":
        "Kunstwerken worden live geladen uit de open collecties van The Metropolitan Museum of Art en het Cleveland Museum of Art. Internetverbinding vereist.",
    "Your museum. On the biggest screen.": "Jouw museum. Op het grootste scherm.",
    "COLLECTION": "COLLECTIE",
    "Start exhibition": "Start tentoonstelling",
    "All works": "Alle werken",
    "Favorites only": "Alleen favorieten",
    "Fetching paintings from the museums…": "Schilderijen ophalen bij de musea…",
    "No favorites yet. Press ▲ during an exhibition to save an artwork.":
        "Nog geen favorieten. Druk tijdens een tentoonstelling op ▲ om een werk te bewaren.",
    "No favorites for this artist yet.": "Nog geen favorieten voor deze kunstenaar.",
    "The museum collections can't be reached right now, or no public-domain works were found.":
        "De museumcollecties zijn nu niet bereikbaar, of er zijn geen rechtenvrije werken gevonden.",
    "Try again": "Opnieuw proberen",
    "This artwork couldn't be loaded. Press ▶ for the next one.": "Dit kunstwerk kon niet worden geladen. Druk op ▶ voor het volgende.",
    "◀ ▶ browse   ▲ favorite   ⏯ pause   hold click: settings": "◀ ▶ bladeren   ▲ favoriet   ⏯ pauze   klik ingedrukt houden: instellingen",
    "Paused": "Gepauzeerd",
    "⏸  Paused": "⏸  Gepauzeerd",
    "▶  Resumed": "▶  Hervat",
    "♥  Saved to favorites": "♥  Bewaard in favorieten",
    "Removed from favorites": "Verwijderd uit favorieten",
    "Masterpieces on your biggest screen": "Meesterwerken op je grootste scherm",
    "TVArt. Masterpieces on your biggest screen.": "TVArt. Meesterwerken op je grootste scherm.",
    "%lld / %lld": "%lld / %lld",
    "%@, %@": "%@, %@",
    "TVArt": "TVArt",
    "Best known": "Bekendste",
    "Title A–Z": "Naam A–Z",
    "Title Z–A": "Naam Z–A",
    "Year: oldest first": "Jaartal: oud → nieuw",
    "Year: newest first": "Jaartal: nieuw → oud",
    "Sort by": "Sorteren op",
    "Search": "Zoeken",
    "Artists": "Kunstenaars",
    "Paintings": "Schilderijen",
    "No paintings found.": "Geen schilderijen gevonden.",
    "Artist or painting": "Kunstenaar of schilderij",
    "Search by artist or painting, for example “Van Gogh”, “Sterrennacht” or “Mona Lisa”.":
        "Zoek op kunstenaar of schilderij, bijvoorbeeld “Van Gogh”, “Sterrennacht” of “Mona Lisa”.",
    "Very soft": "Heel zacht",
    "Soft": "Zacht",
    "Normal": "Normaal",
    "Music": "Muziek",
    "Classical music in the background": "Klassieke muziek op de achtergrond",
    "Volume": "Volume",
    "Debussy – Clair de lune · Satie – Gymnopédie No. 1 (Michael Laucke) · Chopin – Nocturne Op. 9 No. 2 (Frank Lévy). Public-domain recordings via Wikimedia Commons, played one after another on a loop.":
        "Debussy – Clair de lune · Satie – Gymnopédie nr. 1 (Michael Laucke) · Chopin – Nocturne op. 9 nr. 2 (Frank Lévy). Opnames uit het publieke domein via Wikimedia Commons, na elkaar in een doorlopende loop.",
    "%@ – %@": "%@ – %@",
    "All masters": "Alle meesters",
    "Landscapes": "Landschappen",
    "Portraits": "Portretten",
    "Still lifes & flowers": "Stillevens & bloemen",
    "Cities & architecture": "Stad & architectuur",
    "Sea & water": "Zee & water",
    "Everyday life": "Dagelijks leven",
    "Never": "Nooit",
    "Screensavers": "Screensavers",
    "Screensaver": "Screensaver",
    "Start automatically": "Automatisch starten",
    "Theme": "Thema",
    "While TVArt shows art, the Apple TV screensaver stays off, so artworks can stay on screen for hours.":
        "Zolang TVArt kunst toont, blijft de screensaver van de Apple TV uit. Zo kunnen kunstwerken urenlang in beeld blijven.",
    "Collecting masterpieces from all masters. The first time takes a moment.":
        "Meesterwerken van alle meesters verzamelen. De eerste keer duurt dit even.",
    "No artworks found for this screensaver yet.": "Nog geen kunstwerken gevonden voor deze screensaver.",
    "Press Menu to close.": "Druk op Menu om te sluiten.",
    "Artworks and titles come from Wikidata and Wikimedia Commons, supplemented by the open-access collections of The Metropolitan Museum of Art and the Cleveland Museum of Art. Only public-domain works are shown. These settings are also available in the Apple TV Settings app.":
        "Kunstwerken en titels komen van Wikidata en Wikimedia Commons, aangevuld met de open collecties van The Metropolitan Museum of Art en het Cleveland Museum of Art. Alleen werken uit het publieke domein worden getoond. Deze instellingen staan ook in de Instellingen-app van de Apple TV.",
    "Artworks come from Wikidata and Wikimedia Commons, The Metropolitan Museum of Art and the Cleveland Museum of Art. Internet connection required.":
        "Kunstwerken komen van Wikidata en Wikimedia Commons, The Metropolitan Museum of Art en het Cleveland Museum of Art. Internetverbinding vereist.",
}
plurals = {
    "%lld seconds": (("%lld second", "%lld seconds"), ("%lld seconde", "%lld seconden")),
    "%lld minutes": (("%lld minute", "%lld minutes"), ("%lld minuut", "%lld minuten")),
    "%lld artworks": (("%lld artwork", "%lld artworks"), ("%lld kunstwerk", "%lld kunstwerken")),
    "%lld works": (("%lld work", "%lld works"), ("%lld werk", "%lld werken")),
    "After %lld minutes": (("After %lld minute", "After %lld minutes"), ("Na %lld minuut", "Na %lld minuten")),
}

def unit(v):
    return {"stringUnit": {"state": "translated", "value": v}}

strings = {}
for k, nl in plain.items():
    strings[k] = {"localizations": {"nl": unit(nl)}}
for k, (en, nl) in plurals.items():
    strings[k] = {"localizations": {
        "en": {"variations": {"plural": {"one": unit(en[0]), "other": unit(en[1])}}},
        "nl": {"variations": {"plural": {"one": unit(nl[0]), "other": unit(nl[1])}}},
    }}
with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}, f, ensure_ascii=False, indent=2)
print(len(strings), "strings")
