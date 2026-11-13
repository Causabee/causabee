# F009 · Die App-Store-Seite auf Deutsch

The German App Store page, written here so it can be read, tested and changed with the rest of the
feature. It is posted by hand in App Store Connect when the release is prepared — the English page
stays exactly as it is, for every other store. `GermanTests` "F009 AC-7" reads this file: every field
is there, inside Apple's limit, in German, and no field names mail as the only source.

Each heading is a field in App Store Connect, with Apple's own limit. The words under it are the
field, exactly as it is pasted in.

## Name · höchstens 30 Zeichen

Causabee

## Untertitel · höchstens 30 Zeichen

Organisiert. Und privat.

## Werbetext · höchstens 170 Zeichen

Jedes Wort der App auf Deutsch, mit Datum und Zahlen, wie dein Gerät sie schreibt. Deine Anliegen behalten ihre Sprache: ein deutsches deutsch, ein englisches englisch.

## Schlüsselwörter · höchstens 100 Zeichen

Anliegen,Aufgaben,Termine,Pflege,Umzug,Dokumente,Screenshots,Notizen,privat,Familie,Behörde,Mail

## Beschreibung · höchstens 4000 Zeichen

Causabee macht aus allem, was hereinkommt, ein klares Anliegen: Mails, Screenshots aus WhatsApp, Fotos, Dateien und Scans, Notizen, was du im Chat sagst. Daraus wird: was als Nächstes kommt, wer was macht, und bis wann.

ORGANISIERT

Aufgaben, Termine, Dateien und Personen – herausgezogen aus dem, was hereinkommt, und dort abgelegt, wo sie hingehören. Aufgaben sind deine, geteilte, oder die von anderen. Worauf du wartest, steht getrennt von dem, was du selbst tust.

Neue Informationen bringen nur die wenigen Dinge, auf die es ankommt. Was du als nicht nötig markierst, kommt nicht wieder.

Kalender und Erinnerungen, immer auf demselben Stand: einen Termin oder eine Aufgabe fügst du mit einem Tippen hinzu. Änderst du etwas hier oder dort, folgt die andere Seite – auf allen deinen Geräten.

Jede Angabe hat ihre Quelle. Jede Aufgabe und jeder Termin verweist zurück auf das, woraus er entstanden ist – eine Mail, eine Datei, ein Foto, eine Notiz. Ein Tippen, und du siehst es selbst.

Ein Ordner für jedes Anliegen: seine Dateien, mit Namen, die du lesen kannst, in iCloud Drive oder einem Ordner deiner Wahl.

UND PRIVAT

Gesundheit, Geld, Familie: je persönlicher ein Anliegen, desto mehr kommt es darauf an, dass die KI nie einen echten Namen, eine echte Adresse, eine echte Nummer sieht. Was hereinkommt, bleibt auf deinen Geräten und in deiner eigenen iCloud – die KI sieht immer nur eine Verkleidung.

IN DEINER SPRACHE

Die App spricht die Sprache deines Geräts. Ein Anliegen behält die Sprache, in der es geschrieben wurde. Nichts wird übersetzt.

CAUSABEE PRO

Ohne Pro sortiert das Modell von Apple auf deinem Gerät, und nichts verlässt es. Mit Pro liest eine größere KI, was hereinkommt, schreibt den Überblick und antwortet im Chat – mit verkleideten Namen. Pro gibt es im Monat oder im Jahr, und du kannst jederzeit aufhören.

## Was getestet werden soll · höchstens 4000 Zeichen

Neu in dieser Beta: Causabee spricht Deutsch. Auf einem deutschen iPhone, iPad oder Mac ist jedes Wort der App deutsch, mit Datum und Zahlen so, wie dein Gerät sie schreibt. Deine Anliegen behalten ihre eigene Sprache – ein deutsches liest sich deutsch, ein englisches englisch – und nichts, was schon darin steht, ändert sich.

Worauf du schauen kannst:

1. Stell dein Gerät auf Deutsch, oder in den Einstellungen deines Geräts nur Causabee, und starte die App neu.
2. Geh durch den Start. Tippe etwas ein, das dir im Kopf liegt – daraus wird dein erstes Anliegen. Oder füge einen Screenshot, ein Foto oder eine Datei hinzu.
3. Schau auf den Überblick, den Plan, die Dateien und den Chat. Fällt dir ein englisches Wort auf? Ein Satz, der abgeschnitten ist oder nicht passt?
4. Stell die Schrift größer (Einstellungen › Anzeige & Helligkeit › Textgröße). Passt noch alles?
5. Leg über „Beispiel ausprobieren“ die erfundenen Anliegen an: die App spricht deutsch, die englischen Anliegen bleiben englisch.

Schreib uns, welches Wort nicht stimmt – ein steifes, ein falsches, ein englisches. Darum geht es in dieser Beta.

## Die Bilder

The five screenshots are the same runs as the English ones, with the app's language set to German:
`scripts/intro-shots.sh` and the App Store's sizes from the simulator, started with
`-AppleLanguages (de)`. They are taken when the release is prepared, so they show the release's own
screens; they are not in the repository, as the English ones are not.
