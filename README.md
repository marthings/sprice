# Spotprice

Spotprice är en SwiftUI-app för svenska elpriser och elkostnader. Projektet innehåller en macOS-app för menyraden, en iOS-app och en WidgetKit-widget som delar samma pris-, förbruknings- och kostnadslogik.

Målet är att visa mer än bara spotpriset: appen kombinerar marknadens kvartspris med användarens elavtal, skatter, avgifter och valfria elnätsuppgifter för att ge en mer realistisk kostnadsbild.

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![iOS](https://img.shields.io/badge/iOS-app-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-green)

## Nuvarande Funktionalitet

### Prisdata

- Hämtar spotpriser från `elprisetjustnu.se`.
- Stödjer elområdena `SE1`, `SE2`, `SE3` och `SE4`.
- Hanterar kvartsprisdata och uppdaterar på 15-minutersintervall.
- Bygger dagsdata för diagram med låg, medel och hög prisnivå.

### Kostnadsmodell

Kostnadsberäkningen utgår från `CostProfile`, som samlar de inställningar som påverkar användarens pris:

- Elområde.
- Avtalstyp:
  - `Kvartspris`
  - `Rörligt månadspris`
  - `Fast pris`
- Elhandlarens påslag och månadsavgift.
- Avtalat pris för fast eller rörligt månadspris.
- Valfri elnätsleverantör, säkringsstorlek, fast nätavgift och överföringsavgift.
- Energiskatt, elcertifikatsavgift, moms och valfri effekttariff.
- Källa och precision för kostnaden: uppskattad, användarinmatad, importerad eller provider-baserad.

Appen kan visa en uppskattad kostnad utan provider-anslutning. Elnätskostnader ingår först när användaren väljer nätbolag eller när tariffdata finns tillgänglig.

### Förbrukningsdata

Provider-systemet är byggt för flera datakällor. Inbyggda providers idag:

- Tibber.
- Vaggeryds Energi.

Providers kan hämta månadsförbrukning, dagsförbrukning, timvärden och i vissa fall kvartsvärden. Förbrukningsdata används för månadsstatistik, effekttoppar och mer precis månadskostnad när tillräcklig data finns.

### macOS-App

`Spotprice` är macOS-appen i menyraden.

Den innehåller:

- Menyradslabel med aktuellt pris/kostnad.
- Dashboardvy i menyn.
- Diagram för dagens priser.
- Detaljerad callout med pris- och kostnadskomponenter.
- Snabbstatistik för dagens prisspann.
- Kostnadsexempel för vanliga aktiviteter.
- Månadsförbrukning, månadskostnad och effekttoppar när förbrukningsdata finns.
- Inställningar för elområde, elavtal, elnät och förbrukningsprovider.

### iOS-App

`SpotpriceApp` startar i `DashboardView` och har tre flikar:

- `Kostnad`: aktuell kostnad och kostnadsexempel.
- `Dagens elpris`: dagsdiagram, prisstatistik och marknadsjämförelse.
- `Förbrukning`: månadsförbrukning, effekttoppar och månadskostnad när provider-data är konfigurerad.

iOS-appen har en egen settingsvy för:

- Förbrukningsprovider.
- Elområde.
- Elhandelsavtal.
- Elnätsbolag och säkringsstorlek.

### Widget

`SpotpriceWidget` är en WidgetKit-extension som idag stödjer `.systemSmall`.

Widgeten visar:

- Aktuell uppskattad totalkostnad i kr/kWh när den kan beräknas.
- Fallback till spotpris i öre/kWh.
- Mini-diagram för dagen.
- Månadsförbrukning och uppskattad månadskostnad när cachad förbrukning finns.

Widgeten läser delade inställningar och cachad förbrukning via App Group `group.mb.Spotprice`. Den hämtar inte provider-credentials direkt.

## Projektstruktur

- `Shared/Models`: modeller för spotpris, förbrukning, tariff och kostnadsprofil.
- `Shared/Services`: nätverk, spotpriser, förbrukning, elnätstariffer och total kostnadsberäkning.
- `Shared/ViewModels`: `SpotPriceViewModel` och gemensam laddningslogik.
- `Shared/Providers`: provider-protokoll, registry, credentials och inbyggda providers.
- `Shared/Components`: SwiftUI-komponenter som kan delas mellan targets.
- `Shared/DesignSystem`: färger, typografi, spacing och återanvändbara styles.
- `Spotprice`: macOS-menyradsappen.
- `SpotpriceApp`: iOS-appen.
- `SpotpriceWidget`: WidgetKit-widgeten.
- `Docs`: produkt- och implementationsplaner.

## Teknik

- Swift 6.
- SwiftUI.
- Observation med `@Observable`.
- Swift Concurrency med `async`/`await`.
- WidgetKit.
- App Group-delning via `UserDefaults(suiteName:)`.
- URLSession-baserade services med injicerbar session.

## Dokumentation

Dokumenten i `Docs` och `Shared/Docs` är inte alla aktuella produktbeskrivningar. De ska läsas som planerings- och sprintmaterial:

- `Docs/business-case.md`: affärs- och produktcase för den bredare riktningen.
- `Docs/ios-app-menubar-parity-plan.md`: historisk plan för att bygga iOS-paritet med menyradsappen. Flera delar är redan implementerade.
- `Docs/ios-widget-plan.md`: plan för en separat iOS-widgetextension. Den är inte implementerad ännu.
- `Docs/historical-cost-and-consumption-plan.md`: sprintplan för SwiftData-baserad historik, aggregeringar och möjlig framtida CloudKit-synk.
- `Docs/trust-and-release-readiness-sprint.md`: prioriterad sprintplan för kostnadskorrekthet, tester, tarifftransparens, credential-säkerhet, historikexport och release-readiness.
- `Docs/tariffs-and-costs-sprint.md`: sprintlogg för kostnadsprofil, tariff, avtalstyper, widget och copy. Den innehåller både klara punkter och kvarvarande verifiering.

## Kända Gap

- Projektet saknar test target och automatiserade tester för kostnadsberäkning, prisintervall, historik och provider-dekodning.
- En del debug-loggning finns kvar i pris-, förbruknings-, menyrads- och widgetflöden.
- `GridTariffService` använder lokala tariffpresets som standard. Stöd för fjärr-API finns förberett men är inte aktivt.
- Lokala tariffpresets behöver tydligare källa, giltighet, confidence och användarcopy innan de bör betraktas som release-klara.
- Historikfunktionen behöver export- och raderingskontroller innan den bör betraktas som release-klar.

## Utveckling

1. Öppna `Spotprice.xcodeproj` i Xcode.
2. Välj relevant scheme för macOS-app, iOS-app eller widget.
3. Bygg med `Cmd+B` eller kör med `Cmd+R`.
4. Validera både app och widget när ändringar påverkar `Shared`, `ConsumptionSettings`, `CostProfile`, `TotalCostService` eller widgetens dataväg.

## Status

README:n beskriver aktuell implementation i projektet. Vision, framtida integrationer och större produktresonemang ligger i dokumenten under `Docs`.
