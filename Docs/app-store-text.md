# Texter och svar till App Store Connect

Utkast, skrivet på vardaglig svenska. Kopiera in i App Store Connect när du är nöjd. Allt som står under "Svar" är vad appen faktiskt gör, kontrollerat mot koden 2026-11-11 (se `Docs/integritet.md`).

## Namn och undertitel

- **Namn:** Sprice
- **Undertitel** (högst 30 tecken, den här är 24): `Vad kostar elen just nu?`

## Marknadsföringstext (högst 170 tecken, den här är 144)

Se vad en kilowattimme kostar just nu, när elen är billigast i dag och varför månadens elkostnad blev som den blev. Allt stannar på din telefon.

Texten kan ändras när som helst utan ny granskning.

## Beskrivning

Sprice visar vad din el kostar, just nu och över tid. Inga konton, inga annonser och ingen spårning. Allt du fyller i stannar på din telefon.

**Vad en kilowattimme kostar**
Se priset just nu och hur det delas upp: spotpris, elhandlarens påslag, elnät, skatt och moms. Du ser direkt hur mycket av priset som är själva elen och hur mycket som är avgifter.

**Elpriset hela dagen**
Ett diagram med dagens och morgondagens priser, kvart för kvart. De billigaste timmarna är markerade, så det är lätt att välja när du startar tvättmaskinen eller laddar bilen.

**Hur månaden blev**
Välj en månad och se vad elen kostade. Sprice förklarar varför det blev dyrare eller billigare än månaden före: använde du mer el, blev spotpriset högre eller ändrades avgifterna? Du kan också jämföra med hur kallt eller varmt det varit.

**Din egen förbrukning**
Har du Tibber eller Vaggeryds Energi kan du koppla ditt konto och se din riktiga förbrukning. Det är valfritt. Utan konto visar appen priser och en uppskattad kostnad.

**Elbil**
Har du elbil kan appen peka ut timmar som ser ut som laddning. Det är en gissning, och appen säger det.

**Widget**
Lägg priset på hemskärmen, i liten, mellan eller stor storlek.

**Dina uppgifter är dina**
All historik och alla inställningar sparas bara på din telefon. Du kan exportera historiken som en fil eller radera den när du vill.

Alla kostnader är uppskattningar som räknas ut från spotpriset och de värden du själv fyller i. De är inte fakturabelopp.

Elpriser tillhandahålls av Elpriset just nu.se. Temperaturer från Open-Meteo.com.

## Sökord (högst 100 tecken, kommaseparerade, den här är 99)

```
elpris,spotpris,elkostnad,elnät,kvartspris,förbrukning,elområde,elbil,kWh,elräkning,timpris,elavtal
```

Varumärken som Tibber och Vaggeryds Energi är med flit inte med bland sökorden. Apple kan avvisa sökord som är någon annans varumärke. Namnen står bara i beskrivningen, där de säger vad appen fungerar med.

## Kategori

- **Primär:** Verktyg (Utilities)
- **Sekundär:** Ekonomi (Finance)

Verktyg passar bäst. Ekonomi är ett rimligt andraval.

## Övriga svar i App Store Connect

| Fråga | Svar |
| --- | --- |
| Pris | Gratis |
| Åldersgräns | Alla frågor besvaras med Ingen eller Nej. Resultatet blir 4+. |
| Exportregler (kryptering) | Appen använder bara Apples inbyggda kryptering för vanliga nätverksanrop. Redan satt i appen (`ITSAppUsesNonExemptEncryption` är falskt). |
| Innehåll från andra | Ja, appen visar elpriser från elprisetjustnu.se och temperaturer från Open-Meteo. Båda är öppna tjänster och namnges i appen (Inställningar, Om Sprice). Martin intygar att rättigheterna finns. |
| Reklam | Nej |
| Köp i appen | Nej |
| Support-adress | https://github.com/marthings/sprice/issues (tillfällig, ersätt när du bestämt) |
| Integritetspolicy | https://github.com/marthings/sprice/blob/main/Docs/integritet.md (tillfällig, ersätt när du bestämt) |
| Inloggning för granskaren | Ingen inloggning krävs för att starta. Se `AppReviewNotes.md`, där det står att fliken Historik visar förbrukning först när man har ett Tibber- eller Vaggeryd-konto. |

## Appens integritetsetiketter (App Privacy)

### Svar: "Vi samlar inte in några uppgifter" (Data Not Collected)

Apple räknar en uppgift som insamlad först när den lämnar telefonen och ägaren eller någon annan kan komma åt den. I Sprice gäller följande, kontrollerat i koden:

| Fråga | Svar | Förklaring |
| --- | --- | --- |
| Samlar du in uppgifter från appen? | **Nej** | Inget skickas till Martin eller till någon server som Martin har. Det finns ingen egen server. |
| Spårning (Tracking) | **Nej** | Ingen spårning, inget reklam-ID (IDFA), inga reklamnätverk, ingen statistik. Ingen fråga om spårning visas. |
| Analys- eller kraschverktyg från tredje part | **Nej** | Det finns inga sådana bibliotek. Det enda externa biblioteket är BorderBeam, ett ritbibliotek som inte gör några nätverksanrop. |
| Plats | **Nej** | Appen använder aldrig telefonens position. Temperaturen hämtas för en ort som användaren själv väljer i en lista. |

### Vad som faktiskt lämnar telefonen

Det här är skälet till svaret ovan, och det Apple kan fråga om.

| Mottagare | Skickas | Varför det inte är "insamling" |
| --- | --- | --- |
| elprisetjustnu.se | Datum och elområde i adressen (och IP-adress, som alltid) | Bara för att hämta priser. Inget som pekar ut användaren. |
| Open-Meteo | Koordinater för en av åtta förvalda orter som användaren väljer (och IP-adress) | Bara för att hämta temperatur. Det är ortens koordinater, inte telefonens position. |
| Tibber och Vaggeryds Energi | Användarens egen inloggning, och bara om användaren själv kopplar kontot | Går direkt från telefonen till användarens egen elleverantör, för att hämta användarens egna uppgifter. Martin får aldrig se dem. |

Svaret är Martins ansvar. Om du vill vara extra försiktig kan du i stället ange att appen samlar in **Användaruppgifter (Other User Content)** eller **Grov plats (Coarse Location)**, båda "Inte kopplade till användaren" och "Inte för spårning", med syftet "Appens funktioner". Det är sällan nödvändigt för en app som den här, och ett onödigt "ja" gör att appen ser mer ingripande ut än den är. Jag rekommenderar "Samlar inte in uppgifter".

### Efter etiketterna

- Fyll i integritetspolicyns adress (se tabellen ovan).
- Etiketterna ska ändras om appen någon gång får en egen server, statistik, kraschrapporter eller annonser.

## Skärmbilder

Se `Docs/app-store-release.md`. Bilderna för iPhone 6,9 tum (1320 x 2868, ljust läge) är tagna från simulatorn med en kopia av Martins telefondata. De ligger inte i repot.
