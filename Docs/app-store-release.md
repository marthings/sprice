# Sprice i App Store: läget och vad som återstår

Det här dokumentet ersätter de fem gamla planerna från juni 2026 (App Store-förberedelser, TestFlight-plan, förtroendesprint, inlämningssprint och granskningsfynd). De finns kvar i git-historiken. Här står bara det som gäller idag.

Uppdaterat: 2026-11-11, mot grenen `appstore-blockers` (bygger på `release-docs`).

## Så ligger vi till

Bara iOS-appen med widgeten lämnas in till App Store. Menyradsappen på macOS delas ut för hand och stoppar aldrig iOS-releasen.

**Klart**
- [x] TestFlight fungerar. Bygge 202611111812 är uppladdat och godkänt av Apple, och intern testning är redo.
- [x] Appen "Sprice" finns i App Store Connect (appens id är `mb.SpotpriceApp`).
- [x] Signering sker automatiskt via Xcode med Martins Apple-konto.
- [x] Exportefterlevnad är avklarad. Appen använder ingen särskild kryptering, så frågan dyker inte upp.
- [x] Release-bygget går att arkivera och Apple tar emot det.
- [x] Minsta iOS-version är 26.0 för appen och widgeten.
- [x] Integritetsfil finns för alla fyra delarna (appen, widgeten och macOS-motsvarigheterna).
- [x] Appikonen kommer från Icon Composer och godkändes vid uppladdningen.
- [x] Widgeten byggs och delar data med appen. iOS-widgeten finns i storlekarna liten, mellan och stor.
- [x] Bara det som behövs är påslaget i appens behörigheter (en delad datagrupp för appen och widgeten).
- [x] Ingen reklam, ingen spårning, inga köp i appen och ingen molnsynk. Historiken stannar på enheten.
- [x] Felsökningsutskrifter är borttagna ur koden.
- [x] Tillgänglighet: textstorlek och kontrast är hanterade. Bakgrunden är stilla, så det finns ingen rörelse att stänga av. Prisdiagrammet och elbilsdiagrammet går att läsa upp.
- [x] Avgifterna räknas med de belopp som gällde när perioden var, och sparad historik har räknats om.
- [x] Appen låste sig vid start efter omräkningen. Det är åtgärdat.

**Det här finns i App Store Connect idag** (kontrollerat 2026-11-11): bara appens namn och språk (svenska) finns. Beskrivning, nyckelord, undertitel, kategori, åldersgräns, support-adress, integritetspolicy och skärmbilder är tomma. EU-handlarstatus är inte angiven.

## Att göra

Storlek: liten är under en timme, medel är några timmar, stor är en dag eller mer.

### Stoppar inlämning

- [x] Integritetspolicyn är skriven (`Docs/integritet.md`) och kontrollerad mot koden. Martin lägger ut sidan på rätt adress. Kvar: lägga ut den och byta adressen i `AppLinks`. Liten.
- [ ] Bestäm en support-adress (en sida eller en e-postadress som fungerar) och byt `AppLinks.support`. Idag pekar den på GitHub-ärenden som tillfällig adress. Martin. Liten.
- [ ] Ange EU-handlarstatus i App Store Connect (EU:s krav på att visa vem som säljer appen). Martin. Liten.
- [ ] Läs utkastet i `Docs/app-store-text.md` (undertitel, beskrivning, nyckelord, kategori) och klistra in det i App Store Connect. Martin. Liten.
- [ ] Svara på åldersfrågorna i App Store Connect. Svaren står i `Docs/app-store-text.md`, resultatet blir 4+. Martin. Liten.
- [ ] Fyll i integritetsetiketterna i App Store Connect. Svaren är klara i `Docs/app-store-text.md` (rekommendation: samlar inte in uppgifter). Martin. Liten.
- [ ] Ange innehållsrättigheter och pris (gratis) i App Store Connect. Martin. Liten.
- [x] Typsnittet är bytt till Apples egna (SF). PP Object Sans och filerna är borttagna ur alla tre apparna. Klart.
- [x] iOS-appen har nu Exportera historik (delningsmenyn, samma CSV som macOS) och Radera historik med bekräftelse. Klart.
- [x] Under Inställningar, Förbrukning finns Koppla från. Den tar bort inloggningen och frågar om historiken från datakällan också ska raderas. Klart.
- [x] Inställningar har en sektion Om Sprice med länkar till integritetspolicy och support, och en rad om att all data stannar på telefonen. Klart (adresserna är tillfälliga, se ovan).
- [x] `AppReviewNotes.md` beskriver nu iOS-appen, på svenska och engelska. Klart.
- [x] Skärmbilder för iPhone 6,9 tum är tagna (fem stycken, ljust läge). Apple skalar dem till de mindre iPhone-storlekarna. Klart.
- [x] Appen och widgeten är bara för iPhone (enhetstyp iPhone). Inga iPad-skärmbilder behövs. Klart.
- [x] Under Inställningar finns Visa exempeldata. Då visar alla flikar påhittad data för ett hushåll som inte finns, utan konto. Granskaren får veta hur man slår på det i `AppReviewNotes.md`. Klart.

### Bör fixas före release

- [ ] Gör en testrunda på riktig telefon enligt `Docs/TESTA.md`, särskilt widgeten, kvartsbyten och dagsskiften. Martin, kod hjälper till. Medel.
- [ ] Testa lägen utan nätverk, med felaktig inloggning och med delvis data. Appen ska visa vad som saknas utan att något annat slutar fungera. Martin och kod. Medel.
- [ ] Skriv automatiska tester för kostnadsberäkningen, uppdelningen av prisändringen, avgifter per datum och omräkningen av historiken. Det finns inget testprojekt alls, och mycket ny räknelogik har tillkommit. Kod. Stor.
- [ ] Rätta historiska avgifter för fler nätbolag än Vaggeryd. Idag byter bara Vaggeryds avgifter vid årsskiftet. Övriga bolag räknas med dagens avgifter hela vägen. Kod. Medel.
- [ ] Bestäm hur fasta månadsavgifter ska visas när månaderna har olika många dagar. Idag blir oktober cirka 15 kr dyrare än september bara för att den har en dag till. Kod. Liten.
- [ ] Visa tydligt för användaren om historiken inte kan sparas. Idag stängs den av tyst om lagringen inte går att öppna. Kod. Medel.
- [ ] Kontrollera att widgeten visar att datan är gammal när appen inte har uppdaterat på länge, och att den visar samma pris som appen. Kod. Liten.
- [ ] Gå igenom texterna så att inget låter som exakta fakturabelopp. Uppskattat, egna värden och värden från leverantör ska vara tydligt skilda. Martin läser, kod ändrar. Liten.
- [ ] Gör det möjligt att koppla Vaggeryds Energi från telefonen. Hjälptexten säger åt användaren att använda Chrome och utvecklarverktyg (Cmd+Option+I), vilket inte går på en iPhone. Kod. Medel.
- [ ] Rensa inloggningen i Keychain när appen installeras om. iOS låter den ligga kvar efter att appen tagits bort. Kod. Liten.
- [ ] Rätta README: den visar gamla märken och säger att iOS-widgeten inte finns, och listan över kända brister stämmer inte längre. Kod. Liten.
- [ ] Jämför Elbil-funktionen med Martins riktiga laddning. Texten säger att det är en gissning. Martin. Liten.

### Trevligt att ha

- [ ] Dela upp de två största klasserna (inställningarna och huvudmodellen) så att de blir lättare att ändra. Kod. Stor.
- [ ] Låt pris och historik räknas i bakgrunden även i vanligt flöde, inte bara vid omräkningen. Kod. Medel.
- [ ] Engelsk beskrivning om appen ska lanseras utanför Sverige. Martin och kod. Liten.
- [ ] Extern testning med fler testare (kräver att Apple granskar testversionen först). Martin. Liten.
- [ ] Fjärrhämtade nätavgifter i stället för inbyggda tabeller. Kod. Stor.
- [ ] macOS-appen: signering för utdelning utanför App Store, godkännande hos Apple och en nedladdningssida. Martin och kod. Stor.
- [ ] Städa bland de äldre planeringsdokumenten (affärscase, widgetplan med flera) och märk vad som är klart. Kod. Liten.

## Det här har öppnats eller ändrats av senare arbete

- Appen hämtar nu temperatur från Open-Meteo. Det måste med i integritetsetiketter och policy.
- iOS-widgeten har tre storlekar. Gamla planer sa bara liten. Skärmbilderna ska visa rätt.
- Fasta avgifter delas nu av från priset per kilowattimme. Det gör uppdelningen i Historik mer rättvis, men räknelogiken saknar tester.
- Omräkningen av historiken körs nu i bakgrunden, en månad i taget. Vid första start efter en uppdatering kan den ta en stund.
- Bakgrunden är stilla. Den rörliga bakgrunden (PR 9) är borttagen. Djupet kommer från en fast, mjuk färgskiftning, ett varmt sken vid horisonten och en svag skuggning i kanterna. Behöver ses på telefonen i ljust och mörkt läge.
- Exempeldata (Inställningar, Visa exempeldata) skrivs aldrig till den riktiga historiken, widgetens data eller inloggningen. Den använder ett eget minne som kastas bort när den stängs av. Priser och temperatur hittas på i appen, så läget fungerar utan nät.
- Elbilsfunktionen och temperaturjämförelsen fanns inte i de gamla planerna och har ingen egen testlista förutom `Docs/TESTA.md`.
- En prognos för månaden kunde bli miljarder kronor när det bara fanns förbrukning till månadens första sekund. Prognosen visas nu först när det finns minst ett halvt dygn av data.
- Granskaren behöver inget konto för att se Historik. Exempeldata slås på under Inställningar och visar alla delar. Det står i `AppReviewNotes.md`.
- Elpriser och temperatur ska krediteras. Elpriset just nu.se ber om det, och Open-Meteo kräver namn. Båda finns nu som länkar under Inställningar, Om Sprice.
