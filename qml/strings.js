.pragma library
// UI texts. Pixel-font texts are UPPER CASE. A missing language falls back to English.
var lang = "en";
var texts = {
    "title":     { "en": "MEEBLOCKS", "pl": "MEEBLOCKS" },
    "newGame":   { "en": "NEW GAME", "pl": "NOWA GRA" },
    "resume":    { "en": "CONTINUE", "pl": "WZNÓW" },
    "level":     { "en": "LEVEL", "pl": "POZIOM" },
    "colours":   { "en": "COLOURS", "pl": "KOLORY" },
    "green":     { "en": "GREEN", "pl": "ZIELONE" },
    "atari":     { "en": "RAINBOW", "pl": "TĘCZA" },
    "ghost":     { "en": "SHADOW", "pl": "CIEŃ" },
    "sound":     { "en": "SOUND", "pl": "DŹWIĘK" },
    "on":        { "en": "ON", "pl": "TAK" },
    "off":       { "en": "OFF", "pl": "NIE" },
    "scores":    { "en": "TOP 10", "pl": "TOP 10" },
    "about":     { "en": "ABOUT", "pl": "O GRZE" },
    "back":      { "en": "BACK", "pl": "WRÓĆ" },
    "next":      { "en": "NEXT", "pl": "NASTĘPNY" },
    "score":     { "en": "SCORE", "pl": "PUNKTY" },
    "lines":     { "en": "LINES", "pl": "LINIE" },
    "best":      { "en": "BEST", "pl": "REKORD" },
    "paused":    { "en": "PAUSE", "pl": "PAUZA" },
    "gameOver":  { "en": "GAME OVER", "pl": "KONIEC GRY" },
    "newRecord": { "en": "NEW RECORD", "pl": "NOWY REKORD" },
    "place":     { "en": "PLACE %1", "pl": "MIEJSCE %1" },
    "menu":      { "en": "MENU", "pl": "MENU" },
    "noScores":  { "en": "NO SCORES YET", "pl": "BRAK WYNIKÓW" },
    "clearAsk":  { "en": "CLEAR TOP 10?", "pl": "WYCZYŚCIĆ?" },
    "clear":     { "en": "CLEAR", "pl": "WYCZYŚĆ" },
    "yes":       { "en": "YES", "pl": "TAK" },
    "no":        { "en": "NO", "pl": "NIE" },
    "help":      { "en": "Slide left or right: move.  Slide up or down: rotate.  Double tap: the piece falls to the bottom at once (where its shadow shows).  Tap the pause square or leave the app to pause. Sound can be switched off in the menu.",
                   "pl": "Przesunięcie w lewo lub w prawo: ruch.  Przesunięcie w górę lub w dół: obrót.  Podwójne stuknięcie: klocek spada na sam dół (tam, gdzie widać jego cień).  Kwadrat pauzy lub wyjście z gry zatrzymuje grę. Dźwięk wyłączysz w menu." },
    "aboutText": { "en": "A falling blocks puzzle in the spirit of the 8-bit era. Fill whole rows to clear them; every 10 rows the game gets faster.",
                   "pl": "Układanka ze spadającymi klockami w duchu ery 8-bit. Zapełniaj całe rzędy, aby je usunąć; co 10 rzędów gra przyspiesza." },
    "credit":    { "en": "Designed and written by Claude (Anthropic) together with smyhu for the Nokia N9.",
                   "pl": "Zaprojektowany i napisany przez Claude (Anthropic) wspólnie ze smyhu dla Nokii N9." }
};
function setLanguage(code) { lang = (code || "en").substring(0, 2).toLowerCase(); }
function tr(key) {
    var t = texts[key];
    if (!t) return key;
    return t[lang] !== undefined ? t[lang] : t["en"];
}
function trl(key, code) {
    var t = texts[key];
    if (!t) return key;
    return t[code] !== undefined ? t[code] : t["en"];
}
