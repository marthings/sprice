# Sprice i App Store: läget och vad som återstår

Det här dokumentet ersätter de fem gamla planerna från juni 2026 (App Store-förberedelser, TestFlight-plan, förtroendesprint, inlämningssprint och granskningsfynd). De finns kvar i git-historiken. Här står bara det som gäller idag.

Uppdaterat: 2026-11-11, mot grenen `live-background` (f39e214).

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
- [x] Tillgänglighet: textstorlek, kontrast, Minska rörelse och Lågenergiläge är hanterade. Prisdiagrammet och elbilsdiagrammet går att läsa upp.
- [x] Avgifterna räknas med de belopp som gällde när perioden var, och sparad historik har räknats om.
- [x] Appen låste sig vid start efter omräkningen. Det är åtgärdat.

**Det här finns i App Store Connect idag** (kontrollerat 2026-11-11): bara appens namn och språk (svenska) finns. Beskrivning, nyckelord, undertitel, kategori, åldersgräns, support-adress, integritetspolicy och skärmbilder är tomma. EU-handlarstatus är inte angiven.

## Att göra

Storlek: liten är under en timme, medel är några timmar, stor är en dag eller mer.

### Stoppar inlämning

- [ ] Skriv och lägg ut en integritetspolicy (kort, appen sparar allt på enheten). Martin lägger ut sidan, kod skriver texten. Liten.
- [ ] Ange en support-adress (en sida eller en e-postadress som fungerar). Martin. Liten.
- [ ] Ange EU-handlarstatus i App Store Connect (EU:s krav på att visa vem som säljer appen). Martin. Liten.
- [ ] Fyll i appens text: undertitel, beskrivning på svenska, nyckelord och kategori. Martin, kod skriver ett utkast. Liten.
- [ ] Svara på åldersfrågorna i App Store Connect. Martin. Liten.
- [ ] Fyll i integritetsetiketterna i App Store Connect. Martin, kod skriver svaren. Liten. Kom ihåg att appen hämtar temperatur från Open-Meteo (med koordinaterna för vald ort, aldrig din position) och elpriser från elprisetjustnu.se.
- [ ] Ange innehållsrättigheter och pris (gratis) i App Store Connect. Martin. Liten.
- [ ] Besluta om typsnittet. PP Object Sans kräver betald licens för App Store. Köp licensen eller byt till ett fritt typsnitt. Martin bestämmer, kod byter vid behov. Liten eller medel.
- [ ] Lägg in knappar i iOS-appen för att rensa historiken och exportera den. Det finns bara i macOS-appen idag. Kod. Medel.
- [ ] Lägg in ett sätt att koppla från Tibber eller Vaggeryds Energi och radera inloggningen. Idag finns bara knappen Klar. Kod. Liten eller medel.
- [ ] Lägg in länkar i Inställningar till integritetspolicy och support, med en rad om att all data stannar på enheten. Kod, när adresserna finns. Liten.
- [ ] Skriv om `AppReviewNotes.md` så att den beskriver iOS-appen (fyra flikar, vad som funkar utan inloggning, att kostnader är uppskattningar). Nu beskriver den macOS-appen. Kod. Liten.
- [ ] Ta skärmbilder för iPhone (6,9 och 6,5 tum) och för iPad, eftersom appen är byggd för båda. Kolla också att iPad-layouten ser bra ut. Kod tar bilderna, Martin godkänner. Medel.

### Bör fixas före release

- [ ] Gör en testrunda på riktig telefon enligt `Docs/TESTA.md`, särskilt widgeten, kvartsbyten och dagsskiften. Martin, kod hjälper till. Medel.
- [ ] Testa lägen utan nätverk, med felaktig inloggning och med delvis data. Appen ska visa vad som saknas utan att något annat slutar fungera. Martin och kod. Medel.
- [ ] Skriv automatiska tester för kostnadsberäkningen, uppdelningen av prisändringen, avgifter per datum och omräkningen av historiken. Det finns inget testprojekt alls, och mycket ny räknelogik har tillkommit. Kod. Stor.
- [ ] Rätta historiska avgifter för fler nätbolag än Vaggeryd. Idag byter bara Vaggeryds avgifter vid årsskiftet. Övriga bolag räknas med dagens avgifter hela vägen. Kod. Medel.
- [ ] Bestäm hur fasta månadsavgifter ska visas när månaderna har olika många dagar. Idag blir oktober cirka 15 kr dyrare än september bara för att den har en dag till. Kod. Liten.
- [ ] Visa tydligt för användaren om historiken inte kan sparas. Idag stängs den av tyst om lagringen inte går att öppna. Kod. Medel.
- [ ] Kontrollera att widgeten visar att datan är gammal när appen inte har uppdaterat på länge, och att den visar samma pris som appen. Kod. Liten.
- [ ] Gå igenom texterna så att inget låter som exakta fakturabelopp. Uppskattat, egna värden och värden från leverantör ska vara tydligt skilda. Martin läser, kod ändrar. Liten.
- [ ] Rätta README: den visar gamla märken och säger att iOS-widgeten inte finns, och listan över kända brister stämmer inte längre. Kod. Liten.
- [ ] Jämför Elbil-funktionen med Martins riktiga laddning. Texten säger att det är en gissning. Martin. Liten.

### Trevligt att ha

- [ ] Dela upp de två största klasserna (inställningarna och huvudmodellen) så att de blir lättare att ändra. Kod. Stor.
- [ ] Låt pris och historik räknas i bakgrunden även i vanligt flöde, inte bara vid omräkningen. Kod. Medel.
- [ ] Engelsk beskrivning om appen ska lanseras utanför Sverige. Martin och kod. Liten.
- [ ] Låt bakgrunden bli varmare när priset är högt jämfört med dygnet. Kod. Liten eller medel.
- [ ] Extern testning med fler testare (kräver att Apple granskar testversionen först). Martin. Liten.
- [ ] Fjärrhämtade nätavgifter i stället för inbyggda tabeller. Kod. Stor.
- [ ] macOS-appen: signering för utdelning utanför App Store, godkännande hos Apple och en nedladdningssida. Martin och kod. Stor.
- [ ] Städa bland de äldre planeringsdokumenten (affärscase, widgetplan med flera) och märk vad som är klart. Kod. Liten.

## Det här har öppnats eller ändrats av senare arbete

- Appen hämtar nu temperatur från Open-Meteo. Det måste med i integritetsetiketter och policy.
- iOS-widgeten har tre storlekar. Gamla planer sa bara liten. Skärmbilderna ska visa rätt.
- Fasta avgifter delas nu av från priset per kilowattimme. Det gör uppdelningen i Historik mer rättvis, men räknelogiken saknar tester.
- Omräkningen av historiken körs nu i bakgrunden, en månad i taget. Vid första start efter en uppdatering kan den ta en stund.
- Den levande bakgrunden står stilla vid Minska rörelse, i Lågenergiläge och när appen inte syns. Behöver provas på telefonen.
- Elbilsfunktionen och temperaturjämförelsen fanns inte i de gamla planerna och har ingen egen testlista förutom `Docs/TESTA.md`.
