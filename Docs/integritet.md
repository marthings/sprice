# Integritetspolicy för Sprice

Senast ändrad: 11 november 2026

Sprice visar vad elen kostar just nu och hur kostnaden blev över tid. Det här är en kort och ärlig beskrivning av vad appen gör med dina uppgifter.

**Kort version:** allt du fyller i och all historik stannar på din telefon. Vi har ingen server, inga konton, ingen spårning, ingen statistik och inga annonser.

## Vad appen sparar

Allt sparas bara på din telefon. Inget av det skickas till oss.

- **Dina inställningar:** elområde, avtal, påslag, avgifter, valt elnätsbolag, säkringsstorlek, vald ort för temperatur och om du har elbil.
- **Historik:** elpriser, din förbrukning och uträknade kostnader per månad, dag och timme. Förbrukning finns bara om du har kopplat appen till Tibber eller Vaggeryds Energi.
- **Inloggning till Tibber eller Vaggeryds Energi**, om du väljer att koppla dem. Den sparas i telefonens Keychain, det skyddade förvaret som iOS har för lösenord.
- **Ett litet utdrag** av historiken, så att widgeten på hemskärmen kan visa månadens kostnad.

Uppgifterna delas bara mellan appen och dess widget på samma telefon. Appen använder inte iCloud, så de förs inte över till dina andra enheter.

## Vilka anrop appen gör över nätet

Appen pratar bara med de här tjänsterna. De ser din IP-adress, som alla webbplatser gör, men inget annat som pekar ut vem du är.

| Tjänst | Varför | Vad som skickas |
| --- | --- | --- |
| elprisetjustnu.se | Hämta spotpriser | Vilket datum och elområde (SE1 till SE4) du tittar på |
| Open-Meteo (open-meteo.com) | Hämta dygnstemperatur till jämförelserna i Historik | Koordinaterna för den ort du valt i Inställningar, till exempel Vaggeryd. Aldrig din position. |
| Tibber (api.tibber.com) | Bara om du kopplar Tibber: hämta din förbrukning | Din åtkomstnyckel från Tibber |
| Vaggeryds Energi (api-minasidor.vaggerydsenergi.se) | Bara om du kopplar Vaggeryds Energi: hämta din förbrukning | Kundnummer, lösenord, konto-ID och anläggnings-ID som du själv fyllt i |

Uppgifterna till Tibber och Vaggeryds Energi går direkt från din telefon till dem. De passerar aldrig någon server som vi har.

## Det här gör appen inte

- Den använder inte din position och ber inte om åtkomst till den.
- Den har ingen spårning, ingen statistik och inga analysverktyg.
- Den visar inga annonser och delar ingenting med reklamföretag.
- Den har inga köp i appen och inget konto hos oss.
- Den läser inte dina kontakter, bilder eller andra appars data.

## Så raderar du dina uppgifter

- **Historiken:** gå till Inställningar och välj Radera historik. Då tas sparade priser, förbrukning och kostnader bort från telefonen, och widgetens utdrag rensas.
- **Inloggningen:** gå till Inställningar, Förbrukning, och välj Koppla från. Då tas inloggningen bort från telefonen och appen slutar hämta förbrukning. Du får välja om historiken från den datakällan också ska raderas.
- **Allt:** ta bort appen. Då försvinner historik och inställningar. Använd gärna Koppla från först, eftersom iOS ibland låter uppgifter i Keychain ligga kvar efter att en app tagits bort.

Ditt konto hos Tibber eller Vaggeryds Energi påverkas inte. Det raderar du hos dem.

## Hur länge uppgifterna finns kvar

Så länge du har appen och inte raderar dem själv. Appen skickar inga uppgifter om dig till oss, så vi har inget att spara eller radera på vår sida.

## Barn

Appen riktar sig inte till barn och samlar inte in uppgifter om någon.

## Ändringar

Om appen börjar göra något nytt med dina uppgifter ändrar vi den här sidan först. Datumet överst visar när den senast ändrades.

## Kontakt

Frågor om integritet eller något annat: öppna ett ärende på https://github.com/marthings/sprice/issues
