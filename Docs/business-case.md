# Sparks

> *Din el. Din data. Dina regler.*

---

## Grundtes

Dagens energimarknad har blivit oöverblickbar för konsumenten. Kvartspriser sedan oktober 2025, effekttariffer hos vissa nätbolag men inte andra, 170 nätbolag med helt olika avgiftsmodeller, energiskatt, påslag och moms – ibland på två separata fakturor. Totalkostnaden per kWh är ofta 3–5 gånger högre än spotpriset som visas i befintliga appar.

Konsumenten lämnas blind.

Samtidigt pågår en parallell utveckling som är minst lika viktig: **elbolagen bygger inlåsning**. Tibber, Greenely och andra erbjuder smarta funktioner – men bara om du är kund. Din data, din historik, dina integrationer och dina automatiseringar lever i deras moln. Byter du elbolag förlorar du allt.

Och det stannar inte där. Elbolagen vill att du kopplar in dina batterier, elbilsladdare och värmepumpar i deras molnbaserade styrsystem. De vill kontrollera dina resurser. Det skapar inte bara inlåsning – det skapar en allvarlig säkerhetsrisk för hela elnätet.

**Sparks utgår från en annan princip: att konsumenten ska ha full kontroll över sin energidata, sina egna regler och sin egen valfrihet. Och att elkostnaden ska vara begriplig – i kronor och ören, inte bara kilowattimmar.**

---

## Problemet

### 1. Ingen visar den verkliga kostnaden

En svensk elkonsument kan få *två separata fakturor* från *två olika bolag* – en från elhandelsbolaget och en från nätbolaget – båda med egna avgiftsstrukturer, energiskatt och moms. Vissa konsumenter får en samlingsfaktura, men oavsett format består totalkostnaden av samma komponenter:

**Elhandelsfakturan** (från ditt elhandelsbolag):

- **Spotpris** (Nord Pool) – sätts per kvart sedan oktober 2025, men de flesta konsumenter med rörligt avtal betalar ett månadsmedelvärde. Bara de med kvartsprisavtal (~14% av hushållen) betalar det faktiska kvartsspot-priset.
- **Elhandlarens påslag** – typiskt 7–30 öre/kWh. OBS: även Tibber och Greenely har påslag utöver spot. Tibber tar ~8,75 öre/kWh inkl. moms i fast spotpåslag plus elcertifikatsavgift. Greenely har liknande påslag utöver sin månadsavgift.
- **Elcertifikatsavgift** – ~1,75 öre/kWh inkl. moms
- **Månadsavgift** – 49 kr (Tibber), 69 kr (Greenely), 0–79 kr (övriga)
- **Energiskatt** – 54,875 öre/kWh inkl. moms (2025)
- **Moms** – 25% på spotpris, påslag och elcertifikat

**Elnätsfakturan** (från ditt lokala nätbolag – ett annat bolag):

- **Fast årsavgift** – beror på säkringsstorlek, varierar kraftigt per nätbolag (t.ex. 2 145 kr/år för 16A lägenhet hos Vattenfall, 5 050 kr/år för villa)
- **Rörlig överföringsavgift** – öre/kWh, varierar per nätbolag (t.ex. 39 öre/kWh hos Vattenfall, 20,8 öre/kWh hos andra)
- **Effektavgift** – kr/kW baserat på dina effekttoppar, finns hos 30–50 nätbolag, alla med *olika* beräkningsmodeller (topp-3, topp-5, medelvärde, med/utan nattrabatt)
- **Höglast/låglast-differentiering** – varierar per nätbolag. Vissa har 50% reduktion nattetid, andra har ingen differentiering alls
- **Säsongsdifferentiering** – vissa nätbolag har olika priser vinter (nov–mar) och sommar (apr–okt)
- **Moms** – 25% på alla poster ovan

**Sammanfattat:** Konsumenten betalar spotpris + påslag + elcertifikat + energiskatt + månadsavgift + fast nätavgift + rörlig nätavgift + eventuell effektavgift + moms (på båda fakturorna). Det är 8–10 separata kostnadskomponenter från två olika bolag med helt olika prismodeller.

Befintliga appar visar i bästa fall spotpriset. Konsumenten ser "40 öre/kWh" och tror det är billigt – men betalar i verkligheten 2–3 kr/kWh. **Ingen app ger hela bilden utan att kräva att du är kund hos ett specifikt elbolag.**

### 2. Elbolagen bygger inlåsning, inte frihet

Tibber (49 kr/mån + spot + påslag), Greenely (69 kr/mån + spot + påslag) och elbolagens egna appar erbjuder alla smarta funktioner: realtidsmätning, elbilsladdning, värmestyrning. Men allt kräver att du är kund. Byter du elbolag:

- Förlorar du din förbrukningshistorik
- Tappar du dina automationer och styrregler
- Måste du koppla om smarta hem-integrationer
- Blir du av med insikter och jämförelser

Detta skapar ett lock-in som gör att konsumenten stannar kvar även om det finns billigare eller bättre alternativ. Elbolagen konkurrerar inte längre bara på pris – de konkurrerar på inlåsning.

### 3. Effekttariffernas kaos

Regeringen slopade kravet på effekttariffer den 13 mars 2026 – men 30–50 nätbolag har redan infört dem och flera (t.ex. Ellevio) har meddelat att de fortsätter. Energimarknadsinspektionen ska utreda en ny modell till april 2027.

Resultatet är ett lapptäcke: vissa konsumenter betalar effektavgift, andra inte. De som gör det har helt olika modeller beroende på nätbolag – topp-3-timmar, topp-5-timmar, medelvärden, med eller utan nattrabatt, med eller utan säsongsvariation. Förvirringen är total – och behovet av ett oberoende verktyg som ger klarhet har aldrig varit större.

### 4. Elbolagens molnstyrning – en säkerhetsrisk för elnätet

Elbolagen ser "behind the meter" som affärskritiskt för sin framtid. De vill att kunderna kopplar in sina resurser – batterier, elbilsladdare, värmepumpar – i elbolagets molnbaserade styrsystem. Syftet är att aggregera kundernas resurser till virtuella kraftverk och erbjuda stödtjänster (frekvensreglering) mot Svenska kraftnät. Elbolaget tjänar pengar på kundens resurser och delar en del av intäkten med kunden.

Det låter bra i teorin. I praktiken skapar det en enorm systemrisk.

**Scenariot:** Elbolagen har i sin molnplattform direkt åtkomst till varje enskild enhet i kundernas hem – de kan styra din specifika laddbox, din specifika värmepump, ditt specifika batteri. Om elbolagets system hackas får angriparen samma finkorniga kontroll. Med bara ~50 000 hushåll à 10 kW täcks hela Svenska kraftnäts upphandlade FCR-D-volym (500 MW). En enda lyckad attack mot ett elbolags molnplattform kan i teorin slå på – eller stänga av – alla anslutna resurser simultant och destabilisera hela det svenska elsystemet.

**Integritetsrisken:** Som villkor för att få smarta funktioner tvingas konsumenten dela detaljerad persondata med elbolaget – vilka enheter som finns i hemmet, exakta förbrukningsmönster, när man är hemma, när man sover, när man laddar bilen. Konsumenten bör själv kunna bestämma vilken data som delas och med vem – inte tvingas dela allt som villkor för att få grundläggande funktionalitet.

**Vår hållning:** Konsumenten ska aldrig behöva koppla in sina enheter direkt i elbolagets molnsystem. Styrning av enheter ska ske lokalt – inte via ett elbolags moln.

Om konsumenten vill delta i stödtjänstmarknaden (via en aggregator, vilket alltid krävs) ska det ske på konsumentens villkor – genom en lokal hem-hjärna som bara exponerar abstraherade resurser, inte specifika enheter. Även om en aggregator hackas kan angriparen i bästa fall *begära* aktivering – men varje hem fattar sitt eget beslut och kan säga nej. Hem-hjärnan kan ha:

- **Lokala säkerhetsgränser** – vägrar aktivering som överstiger fördefinierade effekttak
- **Anomalidetektion** – avvisar ovanliga mönster (t.ex. "aktivera allt nu" mitt i natten)
- **Rate limiting** – begränsar hur ofta och hur snabbt resurser kan aktiveras
- **Manuell override** – konsumenten kan alltid stänga av deltagandet med en knapptryckning

Skillnaden mot dagens modell: idag kan en hackare styra *varje enskild enhet* i tiotusentals hem. Med lokala hem-hjärnor minskar attackytan dramatiskt – varje hem är en autonom enhet som fattar egna beslut. (Mer om hem-hjärnan under Fas 3.)

---

## Lösningen

**Sparks är en mjukvaruprodukt.** Appen och dess integrationer är kärnan. Eventuell hårdvara (hem-hjärna) är en naturlig vidareutveckling men ett separat beslut som fattas längre fram.

### Designprinciper

Tre principer som genomsyrar allt vi bygger:

**1. Kostnad först, kWh sedan.**
Allt i Sparks visar kronor och ören i första hand. "Din tvätt kostade 3,47 kr (1,2 kWh)" – inte tvärtom. kWh är sekundärt. Det är kostnaden som påverkar plånboken och det är kostnaden konsumenten förstår.

**2. Använd det du redan har.**
Sparks ska aldrig kräva att användaren byter ut hårdvara eller byter elbolag. Vi integrerar med konsumentens befintliga utrustning och tjänster:
- Befintliga P1-donglar – **Saveeye** i första hand (redan använd av Jönköping Energi/Pejla, Ellevio, Greenely, Göteborg Energi m.fl.), HomeWizard P1 Meter
- Befintliga elbolags-API:er – Tibber (officiellt GraphQL API), Greenely, och fler. Har man redan en Tibber Pulse behöver man inte en Saveeye – vi hämtar data via Tibbers API.
- Befintliga smarta mätare i hemmet – Fronius Smart Meter, SolarEdge, Huawei, Sungrow etc. via Solar API. Alla med batterianläggning har redan en smart mätare kopplad – vi ska kunna läsa den.
- Befintliga Shelly-enheter – inte som P1-dongel (Shelly har ingen), utan som mätning av individuella apparater eller säkringsgrupper. En Shelly Plug S på tvättmaskinen ger exakt data: *"Din tvätt 60° kostade 3,47 kr"*. Det är *precis* det vardagsexempel som gör appen magisk.

**3. Elbolagsoberoende.**
Sparks fungerar oavsett om du har Tibber, Greenely, Vattenfall, Göteborg Energi eller något annat bolag. Du ska kunna byta elbolag utan att förlora en enda datapunkt eller funktion. Du har full kontroll över din data – export och radering när du vill.

### Datahantering

Sparks lagrar användarens data i molnet – det är en förutsättning för att appen, insikterna och gamification ska fungera. Det gäller i alla faser. Skillnaden mot elbolagen är inte *var* datan lagras, utan *vem som kontrollerar den*:

- **Elbolagsoberoende** – datan är inte knuten till ett elavtal. Byt elbolag, behåll all data och funktionalitet.
- **Exporterbar** – all din data kan när som helst exporteras i öppet format
- **Transparens** – tydlig redovisning av exakt vilken data som lagras och varför
- **Enkel radering** – du kan radera all din data med en knapptryckning
- **Ingen fjärrstyrning via molnet** – Sparks moln läser data och ger insikter, men styr aldrig dina enheter. Styrning sker lokalt (Fas 3).

### Fas 1: Appen – Förstå din verkliga kostnad

En elbolagsoberoende app som samlar ihop alla kostnadsdelar och visar totalpriset i realtid. Användaren väljer elområde, nätbolag och säkringsstorlek, matar in sitt elavtals påslag – och får en komplett bild.

**Kärnfunktioner:**

- **Totalkostnad i realtid** – spotpris + påslag + nätavgift + effekttariff + energiskatt + moms = verkligt pris per kWh just nu, i kronor
- **Månadsprognos** – enkel prognos för månadens elkostnad baserad på faktisk förbrukning hittills, kostnadsprofil och hur stor del av månaden som passerat
- **Vardagsexempel** – "Tvättmaskinen kostar 4,80 kr just nu – starta kl. 02 och spara 3 kr"
- **Tidsoptimering** – skjutreglage för att se kostnad vid annan tidpunkt, förslag på bästa tid
- **Effekttoppsmedvetenhet** – visa hur samtidig användning av apparater påverkar effektavgiften
- **Push-notiser** – "Elpriset är ovanligt lågt just nu – bra läge att tvätta!"
- **Prisvy** – 24h-graf med *totalpris* (inte bara spot), färgkodad i kronor

**Integrationer redan i Fas 1:**

- **Tibber API** (officiellt GraphQL) – Martin har redan fungerande integration. Ger förbrukningsdata för Tibber-kunder utan extra hårdvara.
- **Greenely API** – om tillgängligt, samma approach
- **elprisetjustnu.se** – för spotprisdata oberoende av elbolag
- **Önska ditt elbolag** – användare som saknar integration kan önska sitt elbolag, vilket styr prioriteringen av nya integrationer

**Tariff-databas:**

En komplett databas över samtliga svenska nätbolags tariffstrukturer – fast avgift, rörlig avgift, effektavgift (modell, kr/kW, beräkningsmetod), hög-/låglasttider, säsongsvariationer. Delvis automatiserbar via RISE/Göteborg Energis öppna API för elnätsavgifter, som redan täcker över hälften av Sveriges elnätskunder och siktar på att bli nordisk standard.

**Plattformar:** iOS och macOS primärt (Swift/SwiftUI, baserat på Martins befintliga Spotprice-kodbas), Android, web. Windows önskvärt längre fram.

### Fas 2: Elbolagsoberoende realtidsdata (fortfarande mjukvara)

Fas 1 hämtar data via elbolagens egna API:er – vilket ger värde men bibehåller ett visst beroende. Fas 2 gör Sparks *helt fristående* genom att integrera mot oberoende datakällor. Fortfarande ren mjukvara – ingen egen hårdvara.

- **Saveeye-integration** (förstahandsval för P1-data) – P1-dongel som redan används av JEAB/Pejla, Ellevio, Greenely, Göteborg Energi m.fl. Enheten är inte låst till ett bolag och kostar ~600–700 kr som engångskostnad. Konsumenten köper dongeln, kopplar mot Saveeyes moln, och Sparks integrerar mot deras API. **Detta är nyckeln till fullständigt oberoende – realtidsdata utan att vara beroende av elbolagets API.**
- **Solar API / växelriktare** – Fronius Smart Meter, SolarEdge, Huawei, Sungrow. Alla med solceller eller batterianläggning har redan dessa mätare installerade – vi läser data via deras molntjänster, helt oberoende av elbolag.
- **Shelly-enheter** – för mätning av individuella apparater eller säkringsgrupper. Shellys breda ekosystem (Plug S, 1PM, EM, Pro 3EM) ger unik data: vad *specifika* apparater faktiskt drar och kostar. "Torktumlaren kostade 8,20 kr – 65% dyrare än om du kört den kl. 03."
- **RISE API för elnätsavgifter** – automatiserad hämtning av nätbolags tariffdata
- **Smart hem-integration** – Home Assistant, Homey – data stannar hos konsumenten
- **Fler elbolags-API:er** – baserat på användarnas önskemål från Fas 1
- **Insikter** – personliga besparingsförslag baserat på verklig data (se separat avsnitt)
- **Affiliate/jämförelse** – "Med ditt förbrukningsmönster skulle du spara 2 400 kr/år med avtal X hos Y"

### Fas 3: Lokal hårdvara – en möjlig framtid

Fas 1 och 2 är ren mjukvara. Fas 3 introducerar möjligheten till en fysisk enhet – men det är ett separat beslut som kan fattas senare.

Visionen: en **lokal hem-hjärna** – en liten enhet som placeras vid routern, kopplad med ethernet, som samlar in data från alla befintliga sensorer och mätare och fattar lokala beslut om styrning. Enheten styr dina apparater direkt – utan att styrkommandon passerar internet eller ett elbolags moln.

Detta kan realiseras på flera sätt – och vi behöver inte välja nu:

- **Egen hårdvara** – dedikerad enhet med Sparks-mjukvara
- **Samarbete med Spotpilot** – de har redan en lokalt körande styrplattform med AI-optimering
- **Home Assistant-integration** – Sparks-logiken (tariff-DB, kostnadsoptimering, abstraherat stödtjänstgränssnitt) som addon/plugin till HA
- **Kombination** – egen enhet för konsumenter utan teknisk kompetens, plugin för HA-communityn
- **Home display** – en dedikerad skärm (kök, hall) som alltid visar aktuell totalkostnad, förbrukning och besparingsmöjligheter. Kan vara en fristående produkt eller en app för befintliga surfplattor.

**Varför lokal styrning?**

- **Valfrihet** – Byt elbolag utan att förlora automationer eller styrregler
- **Integritet** – Dina enheter och deras styrning exponeras aldrig mot elbolag eller andra externa aktörer
- **Säkerhet** – Ingen extern aktör kan fjärrstyra dina resurser (se avsnitt om säkerhetsrisk ovan)
- **Beredskap** – Styrningen fungerar vid internetavbrott. Och om du har full backup i hemmet – även vid strömavbrott.
- **Snabbhet** – Lokal bearbetning ger realtidsrespons utan molnfördröjning – kritiskt för lastbalansering och effekttoppsstyrning

**Vad hem-hjärnan gör:**

- Samlar in data från befintliga P1-donglar (Saveeye, HomeWizard), solcellsväxelriktare (Fronius, SolarEdge), batterilagring, elbilsladdare, Shelly-enheter
- Fattar optimala beslut baserat på *totalpris* (inte bara spotpris), effekttariff, egen produktion och förbrukningsmönster
- Styr apparater lokalt efter användarens egna regler – styrkommandon passerar aldrig internet
- Kommunicerar med aggregatorer och nätbolag vid behov – men på användarens villkor och genom ett abstraherat gränssnitt

**Stödtjänster – på konsumentens villkor:**

Svenska kraftnät upphandlar stödtjänster (FCR-D, FCR-N, aFRR, mFRR) för att hålla frekvensen i elnätet på 50 Hz. Privatpersoner kan delta via aggregatorer (BSP-aktörer) som samlar ihop många små resurser till bud om minst 0,1 MW.

Idag kräver detta att konsumenten kopplar in sina enheter direkt i aggregatorns molnsystem – med alla integritets- och säkerhetsrisker det innebär.

**Sparks-modellen:** Hem-hjärnan exponerar *abstraherade resurser* mot aggregatorn. De ser bara:

- Tillgänglig effekt (t.ex. "3 kW")
- Svarstid (t.ex. "2 sekunder")
- Varaktighet (t.ex. "20 minuter")
- Tillgänglighet (tidsfönster)

De behöver **inte** veta att det är ett Huawei-batteri, en Zaptec-laddare och en NIBE värmepump. Hem-hjärnan förhandlar lokalt och bestämmer *vilka* resurser som aktiveras och i vilken ordning – baserat på konsumentens egna regler och preferenser. Aggregatorn får det de behöver (effekt, hastighet, tillgänglighet). Konsumenten behåller kontrollen och integriteten.

Det blir en förhandling mellan aggregatorns system och hemmets hjärna – istället för att aggregatorn har direkt tillgång till alla individuella enheter.

---

## Marknaden

- **5 miljoner hushåll** i Sverige
- **73,6%** har rörligt elavtal (SCB, aug 2025) – 3,7 miljoner hushåll
- **14,1%** har kvartspris – ~700 000 hushåll med störst incitament att optimera
- **~2 miljoner** villaägare som direkt påverkas av nätavgifter och effekttariffer
- **~250 000** solcellsinstallationer – premiumsegment med stort behov av optimering
- Elbilspenetrationen ökar stadigt – varje elbilshushåll har starka skäl att förstå och styra sin förbrukning

**Adresserbar marknad (fas 1):** Hushåll med rörligt elavtal som aktivt vill förstå och optimera – uppskattningsvis 1–1,5 miljoner hushåll.

Sparks ger även mervärde för hushåll med fast elpris. Även de betalar nätavgift med alla dess komponenter – inklusive eventuell effektavgift – och har nytta av att se sin verkliga totalkostnad och kunna optimera effekttoppar. Men det största värdet finns hos de med rörligt pris, där beteendeförändring direkt påverkar kostnaden.

---

## Konkurrenslandskap

### Översikt

| Aktör | Vad de erbjuder | Vad de saknar |
|-------|----------------|---------------|
| **Tibber** | Pulse-mätare, smart styrning, elbilsladdning, Grid Rewards. 49 kr/mån + spot + påslag. | Kräver Tibber-avtal för fulla funktioner. Data i Tibbers moln. Inlåsning. |
| **Greenely** | Kvartspris, realtidsmätare (Saveeye), VPP, smarta integrationer. 69 kr/mån + spot + påslag. | Kräver Greenely-avtal. Kundlåst data. Inlåsning. |
| **Göteborg Energi (typ.)** | Kundapp med Elkollen, Smart laddning, fakturor. Öppet API (RISE) för nätavgifter. | Bara egna kunder. Begränsad funktionalitet. Ingen totalkostnadsbild. |
| **Spotpilot** | Lokal AI-styrning av hembatterier, spotprisoptimering. Kör lokalt utan moln. | Kräver batteri (~50–150 tkr investering). Liten målgrupp. Oklart hur ekonomin skalas. |
| **Spot / Elpris idag** | Enkel spotpris-visning | Bara spotpris. Ej nätavgift, skatt, effekttariff. Visar öre/kWh, inte verklig kostnad. |
| **Home Assistant** | Lokal kontroll, enormt ekosystem, öppen källkod | Kräver teknisk kompetens. Ingen tariff-DB. Ingen totalkostnadsberäkning. |
| **Sparks** | **Oberoende. Komplett totalkostnad i kronor. Vardagsexempel. Integrerar med befintlig utrustning. Lokal data på sikt.** | Ny aktör utan användardata. |

### Djupdykning: Tre typer av aktörer

**1. Tibber – det smarta elbolaget som bygger inlåsning**

Tibber är den mest avancerade konkurrenten. De erbjuder Pulse-realtidsmätare (P1, KM och CT-varianter) som kopplas till elmätarens P1/HAN-port och skickar förbrukningsdata varannan sekund till Tibber-appen. Funktioner inkluderar lastbalansering, effektlarm, smart elbilsladdning och värmestyrning. De säljer även Homey Pro (2026) som smart hub och har lanserat Tibber Bridge för molnbaserad batteristyrning.

Men Tibbers modell bygger på inlåsning: Pulse *fungerar* utan Tibber-avtal, men då får du bara 24 timmars realtidsdata och ingen historik, ingen effektkontroll för elbilsladdning, och inga smarta styrfunktioner. All data lagras i Tibbers moln. Byter du elbolag förlorar du dina insikter, automationer och historik. Tibber tar 49 kr/mån plus påslag (~8,75 öre/kWh inkl. moms) utöver spotpriset – de konkurrerar inte på att vara billigast, utan på att göra dig beroende av deras ekosystem.

**Vår skillnad:** Sparks ger insikt *utan* att byta elbolag. Din data är din. Har du redan en Tibber Pulse hämtar vi data via deras API – du behöver inte köpa ny hårdvara. Och på sikt ger hem-hjärnan lokal styrning utan molnberoende.

**2. Göteborg Energi – det traditionella elbolaget som försöker bli smart**

Typiskt för Sveriges kommunala och regionala energibolag. Deras app erbjuder fakturor, Elkollen (sätt sparmål), elprisinformation och nyligen Smart laddning för elbil. De använder Saveeye som realtidsmätare. De har även – tillsammans med RISE – utvecklat ett öppet API för att dela elnätspriser, vilket visar att även de ser behovet av öppenhet.

Men grundproblemet kvarstår: alla funktioner kräver att du är kund. Appen ger ingen totalkostnadsbild, inga apparatexempel, ingen oberoende rådgivning. Och om du byter från Göteborg Energi till exempelvis Tibber börjar du om från noll. Samma mönster gäller JEAB, ÖKAB, Ellevio och i princip alla svenska nätbolag och elhandelsbolag.

**Vår skillnad:** Sparks fungerar oavsett elbolag. Vi kan till och med hjälpa dig jämföra – och byta – utan att förlora funktionalitet.

**3. Spotpilot – rätt vision, fel ingång**

Spotpilot delar mycket av vår filosofi. De erbjuder AI-baserad styrning av hembatterier som kör *lokalt* i hemnätverket – väder och spotpriser hämtas en gång per dag, resten sker utan moln. De optimerar laddning/urladdning baserat på spotpris, förbrukningsprognos och solproduktion.

Men Spotpilot börjar i hårdvaruänden: du måste ha ett hembatteri (50 000–150 000 kr investering) för att överhuvudtaget kunna använda tjänsten. Det begränsar målgruppen till kanske 50 000–100 000 hushåll i Sverige. Dessutom är deras affärsmodell otydlig – styrning av en liten installerad bas av batterier genererar begränsade löpande intäkter.

**Vår skillnad:** Sparks börjar med insikt och beteendeförändring (app) som når 3,7 miljoner hushåll med rörligt avtal – och bygger sedan mot styrning och hårdvara. Spotpilot bygger en bra motor men har få bilar att sätta den i. Vi bygger en stor bilpark (appanvändare) och kan efterhand erbjuda motorn.

---

## Insikter – betala för det som sparar dig pengar

En av de mest spännande intäktsmöjligheterna. Baserat på användarens förbrukningsdata kan Sparks generera konkreta, personliga besparingsförslag – insikter som direkt påverkar plånboken.

**Exempel på insikter:**

- *"Du kan sänka din huvudsäkring från 25A till 20A – besparing ~1 200 kr/år på den fasta nätavgiften."*
- *"Ditt förbrukningsmönster passar bättre för elavtal X hos Y – besparing ~2 400 kr/år."* (affiliate-intäkt)
- *"Dina tre högsta effekttoppar den här månaden var alla tisdagar kl. 17 – sprid ut matlagning och elbilsladdning så sparar du ~150 kr/mån i effektavgift."*
- *"Din torktumlare drog 3,8 kWh igår – 65% dyrare än om du kört den kl. 03. Snittkostnad: 8,20 kr vs. 4,95 kr."* (kräver Shelly-integration)
- *"Din tvättmaskin drar 15% mer per tvätt än genomsnittet – dags att byta?"* (affiliate-möjlighet)
- *"Du har solceller men inget batteri. Med ditt produktionsmönster skulle ett batteri spara ~8 000 kr/år."* (affiliate/lead gen)

**Modell:**

- **Gratis:** Grundläggande insikter (bästa/sämsta timme, enkel jämförelse med igår)
- **Premium:** Avancerade insikter (säkringsrekommendation, effekttoppsanalys, detaljerade apparatkostnader, historiska trender)
- **Affiliate:** Elavtalsjämförelse, produktrekommendationer (laddboxar, batterier, smarta hem-produkter, nya vitvaror) – provision vid byte/köp

Insikterna blir bättre ju mer data vi har. Det skapar en naturlig uppgraderingstrappa: gratis → koppla in dongel/API → mer data → bättre insikter → premium värt att betala för.

---

## Gamification – tävla om att vara smartast

Energioptimering kan vara tråkigt. Sparks gör det roligt.

- **Sparks-poäng** – samla poäng för smarta beteenden (tvättade under lågpristimme, undvek effekttopp, sänkte snittkostnad)
- **Tävla mot vänner** – lägsta snittpris per kWh, störst besparing denna månad
- **Lokala topplistor** – per kommun, per nätbolag, per elområde. "Du betalade 1,47 kr/kWh i snitt denna vecka – 23% bättre än förra veckan och topp-15% i Vaggeryds kommun."
- **Achievements** – "Tvättmästaren" (alltid tvättat under 1 kr/kWh), "Nattuglan" (80% av förbrukning nattetid), "Topptrimmare" (inga effekttoppar över X kW på 30 dagar)
- **Månadstävlingar** – med priser i samarbete med partners

Gamification driver engagemang och retention – och engagerade användare genererar mer data, vilket gör insikterna bättre, vilket gör premium mer värdefullt.

---

## Affärsmodell

| Intäktskälla | Beskrivning |
|-------------|-------------|
| **Gratis + annonser** | Grundversion: totalpris baserat på spotpris + manuellt inmatade uppgifter. Relevanta annonser (solceller, smarta hem, elavtal). |
| **Premium-prenumeration** | Annonsfri. Realtidsdata (via dongel/API). Avancerade insikter. Apparatkostnader (Shelly). Historik. Gamification. 39–59 kr/mån. |
| **Affiliate / lead gen** | Elavtalsjämförelse, produktrekommendationer, säkringsbyte-förmedling. CPA/CPC-modell. Potentiellt den största intäktskällan på sikt. |
| **Hem-hjärna** | Hårdvara + ev. tjänsteabonnemang. Separat beslut längre fram. |

Affärsmodellen är medvetet uppbyggd för att aldrig skapa den inlåsning vi kritiserar hos andra. Konsumentens data är alltid exporterbar. Sparks fungerar oavsett elbolag.

**Affiliate som nyckelintäkt:** Sparks har en unik position för affiliate-intäkter eftersom vi sitter på konsumentens *verkliga* förbrukningsdata och kan ge genuint personliga rekommendationer – inte generiska jämförelser. "Med *ditt* förbrukningsmönster sparar du 2 400 kr/år med avtal X" är betydligt mer övertygande (och konverterande) än en vanlig elavtalsjämförelse.

---

## Befintlig kodbas

Martin Berggren har redan utvecklat en macOS-menyapp (**Spotprice**) i Swift 6 / SwiftUI som visar:
- Realtids-spotpriser i menyraden (öre/kWh), automatisk uppdatering var 15:e minut
- Visuell graf med färgkodning (låg, medel, hög)
- Månatlig och daglig förbrukningsstatistik
- Effekttoppsidentifiering
- Nättariffer och kostnadsberäkningar
- Stöd för alla elområden (SE1–SE4)

Appen har en modulär provider-arkitektur med fungerande integration mot Tibbers GraphQL API och Vaggeryd Energi. Arkitekturen är utbyggbar – nya elleverantörer kan läggas till via ett ElectricityProvider-protokoll.

Denna kodbas utgör den tekniska grunden. Eftersom den är skriven i Swift/SwiftUI är iOS och macOS de naturliga primärplattformarna – båda kan nås från samma kodbas. Android och web utvecklas separat men delar backend och affärslogik. Windows är önskvärt längre fram.

---

## Risker

| Risk | Hantering |
|------|-----------|
| Tibber/Greenely lägger till liknande funktion | Deras funktioner kräver avtal. Vår styrka är oberoende och det kommer de aldrig erbjuda – det går emot deras affärsmodell. |
| Spotpilot breddar sig mot app/insikt | De saknar tariff-DB och bred målgrupp. Samarbete möjligt och kanske önskvärt. |
| Svårt att hålla tariff-DB aktuell | RISE API automatiserar delar. Community-rapportering. Årsvis manuell uppdatering för resten. |
| Låg betalningsvilja hos konsumenter | Gratis grundversion + annonser som bas. Premium motiveras av insikter som *sparar* användaren pengar. Affiliate kan vara större intäkt. |
| Egen hårdvara kräver kapital och certifiering | Fas 3 – separat beslut. Kan realiseras via samarbete (Spotpilot, HA) snarare än egen tillverkning. Fokus på mjukvara först. |
| Home Assistant-communityn bygger liknande | Samarbeta snarare än konkurrera. HA saknar tariff-DB, konsumentvänlighet och kostnadsberäkning. Sparks kan bli HA:s "frontend för vanliga människor". |
| Effekttariff-landskapet ändras (ny utredning april 2027) | Appen hanterar alla tariffmodeller. Förändring ökar behovet av tydlighet – bra för oss. |
| Elbolags-API:er stängs eller begränsas | Diversifiera datakällor. Saveeye/P1-donglar ger data oberoende av elbolag. RISE API minskar beroendet av enskilda aktörer. |

---

## Vision

Sparks börjar som en enkel app som ger svar på en vardagsfråga: *"Vad kostar elen egentligen?"*

Men den långsiktiga visionen är större. Vi tror att framtidens energikonsument inte vill vara en passiv mottagare som låter sitt elbolag bestämma när bilen laddas eller när värmepumpen körs. Vi tror att konsumenten vill ha kontroll – inte bara över sin förbrukning, utan över sin data, sina beslut och sin valfrihet.

Det innebär en oberoende energiplattform med lokal styrning som konsumenten kontrollerar. Som fungerar oavsett elbolag. Som skyddar privatlivet. Vars styrning överlever ett internetavbrott. Som till och med kan överleva ett strömavbrott – om du har full backup i hemmet. Och som ger konsumenten en genuin förhandlingsposition på en marknad som hittills designats av och för elbolagen.

Elbolagen behöver inte veta vilka enheter du har – bara att du har resurser tillgängliga. Hem-hjärnan förhandlar. Du bestämmer villkoren.

Vi börjar med att göra elkostnaden begriplig. Vi slutar med att ge hushållet sin egen energihjärna.

---

*Idén utvecklas av Mikael och Martin Berggren.*
*Ansökan inskickad till Startupprogrammet Start 74, Science Park Jönköping, mars 2026.*

---

## Bilaga: Inskickad pitch (Start 74)

> Svenska hushåll har aldrig haft svårare att förstå sin verkliga elkostnad. Kvartspriser, effekttariffer hos vissa nätbolag men inte andra, 170 olika avgiftsmodeller, energiskatt, påslag och moms – det är rörigt och svårbegripligt, och totalkostnaden är ofta 3–5 gånger högre än spotpriset som visas i befintliga appar. Konsumenten lämnas utan verktyg att förstå vad elen faktiskt kostar - och vad man kan göra för att påverka kostnaden.
>
> De appar som finns idag kräver att du är kund hos ett specifikt elbolag. Vår idé är en helt oberoende app som samlar ihop alla kostnadsdelar och visar totalpriset i realtid, översatt till konkreta vardagsexempel: "Tvättmaskinen kostar 4,80 kr nu – starta kl. 02 och spara 3 kr."
>
> Potentialen för vidareutveckling är stor: koppling mot smarta hem-system eller egen hårdvara för realtidsmätning och styrning.
>
> Idén utvecklas tillsammans med Martin Berggren

