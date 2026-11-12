# Anteckningar till App Review (Sprice för iPhone)

Det här är texten som läggs i fältet "Notes" i App Store Connect, översatt till engelska i slutet av filen eftersom granskarna läser engelska. Svenska först så att den är lätt att kontrollera.

## Vad appen är

Sprice är en iPhone-app (med widget) för svenska hushåll. Den visar vad en kilowattimme el kostar just nu, elpriset under dagen och hur elkostnaden blev månad för månad.

**Så provar granskaren allt utan konto:** gå till fliken **Inställningar** och slå på **Visa exempeldata** (högst upp, under översikten). Då visar alla flikar påhittad data för ett hushåll som inte finns, och texten "Exempeldata" syns högst upp på varje flik. Det går också att trycka på **Prova med exempeldata** på de tomma flikarna. Exempeldatan sparas inte och ändrar inget i appens riktiga data. Slå av reglaget för att gå tillbaka.

Appen har fyra flikar:

1. **Kostnad:** vad en kilowattimme kostar just nu, uppdelat i spotpris, elhandlarens påslag, elnät, skatt och moms.
2. **Priser:** elpriset hela dagen i ett diagram, med de billigaste timmarna markerade.
3. **Historik:** hur kostnaden blev för vald månad, med en förklaring till varför den blev dyrare eller billigare.
4. **Inställningar:** elområde, elavtal, elnätsbolag, ort för temperatur, elbil, export och radering av historik, länkar till integritetspolicy och support.

## Det här fungerar utan inloggning

Ingen inloggning krävs för att starta appen. Utan konto fungerar:

- Kostnad: aktuellt pris per kilowattimme och hur det delas upp. Välj elområde och elnätsbolag under Inställningar för att se avgifterna.
- Priser: dagens och morgondagens elpriser.
- Inställningar, inklusive export och radering av historik.
- Widgeten på hemskärmen (liten, mellan och stor).

Elpriserna hämtas från ett öppet gränssnitt hos elprisetjustnu.se. Appen har inget eget konto eller någon server. Prisdata kan saknas om granskaren har ett nätverk som blockerar tjänsten.

## Det här kräver ett eget konto (valfritt)

Förbrukning kan hämtas från Tibber (kräver kundens egen åtkomstnyckel) eller Vaggeryds Energi (kräver kundens egna inloggningsuppgifter). Båda kopplas under Inställningar, Förbrukning, och används bara för att visa kundens egen förbrukning. De som inte har ett sådant konto kan inte koppla dem.

**Viktigt för granskaren:** utan en datakälla visar fliken Historik bara det genomsnittliga elpriset för månaden. Förbrukning, månadens kostnad, förklaringen till prisförändringen och elbilsgissningen kräver förbrukningsdata från Tibber eller Vaggeryds Energi. Vi kan inte ge ut ett demokonto hos dem, så använd **Visa exempeldata** under Inställningar (se ovan). Då syns alla de vyerna med påhittad data, även månadsvyn, uppdelningen av prisändringen, "Vad drog?" och temperaturjämförelsen. Elbil är påslaget i exempeldatan.

## Kostnaderna är uppskattningar

Alla kostnader är uppskattningar. De räknas ut från spotpriset och de värden användaren själv väljer eller fyller i (påslag, månadsavgifter, elnätsavgifter, skatt och moms). De är inte fakturabelopp, och appen säger det på de ställen där siffrorna visas. Avgifterna för elnätsbolag finns inbyggda i appen och hämtas inte över nätet.

## Elbil är en gissning

Under Inställningar finns en knapp, "Jag har elbil". När den är på letar appen efter timmar som ser ut som laddning i förbrukningen och visar dem under Historik, "Vad drog?". Det är en gissning och appen säger det i texten. Funktionen är avstängd som standard och kräver förbrukningsdata.

## Nätverk och integritet

Appen anropar bara: elprisetjustnu.se (spotpriser), Open-Meteo (dygnstemperatur för en ort användaren väljer själv i en lista, aldrig enhetens position) och, bara om användaren kopplar dem, Tibber och Vaggeryds Energi. Inloggningsuppgifter sparas i Keychain. Allt annat sparas bara på enheten. Ingen spårning, inga annonser, inga köp i appen, ingen analys. Appen använder inte enhetens position. Se integritetspolicyn, som också är länkad under Inställningar.

## Annat

- Ingen AI-analys, inga köp i appen, inga dolda eller vilande funktioner.
- Appen använder en delad datagrupp (App Group) mellan appen och widgeten, och inget annat särskilt tillstånd.
- Språk: svenska.

---

## English version (paste this into App Store Connect)

Sprice is an iPhone app (with widgets) for Swedish households. It shows what a kilowatt hour of electricity costs right now, the price across the day, and how the electricity cost turned out month by month. The app is in Swedish.

To review everything without an account: open the Inställningar tab and turn on **Visa exempeldata** (at the top, under the overview). Every tab then shows invented data for a household that does not exist, and a small "Exempeldata" label appears at the top of each tab. The empty tabs also have a button, **Prova med exempeldata**. The example data is not saved and changes nothing in the app's real data. Turn the switch off to go back.

Four tabs: Kostnad (cost per kWh right now, split into spot price, retailer markup, grid fee, tax and VAT), Priser (today's and tomorrow's prices in a chart), Historik (the cost for a chosen month and why it became more or less expensive) and Inställningar (settings).

No sign-in is needed to start the app. Without an account these work: Kostnad (current price per kWh and its breakdown), Priser (day-ahead spot prices), Inställningar (price area, contract, grid company, export and deletion of history, privacy policy and support links), and the home screen widgets (small, medium, large).

Optional and not needed for review: the user can connect their own Tibber account (personal access token) or Vaggeryds Energi account (customer credentials) under Inställningar > Förbrukning to see their own consumption. We cannot provide demo accounts for these services. Please note: without a connected data source, the Historik tab only shows the average spot price for the month. Consumption, monthly cost, the explanation of price changes and the EV guess need consumption data. Use **Visa exempeldata** in Inställningar (see above) to see all of these views with invented data, including the month view, the cost breakdown, "Vad drog?" and the temperature comparison. The EV setting is on in the example data.

All costs are estimates calculated from the spot price and the values the user chooses or enters (markup, monthly fees, grid fees, tax, VAT). They are not invoice amounts, and the app says so where they are shown. Grid company fees are built into the app and are not downloaded.

EV: a switch under Inställningar ("Jag har elbil") makes the app look for hours that look like charging in the consumption data and show them under Historik ("Vad drog?"). It is a guess and the app says so. It is off by default and needs consumption data.

Network: the app only contacts elprisetjustnu.se (spot prices), Open-Meteo (daily temperature for a town the user picks from a list, never the device location) and, only if the user connects them, Tibber and Vaggeryds Energi. Credentials are stored in the Keychain. Everything else stays on the device. No tracking, no ads, no in-app purchases, no analytics. The app does not use the device location. The privacy policy is linked in Inställningar.

No AI features, no in-app purchases, no hidden or dormant features.
