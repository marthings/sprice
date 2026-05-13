# Spotprice

En modern macOS-menyapplikation för att följa spotpriset på el i realtid och förstå din elförbrukning.

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## Översikt

Spotprice är en elegant macOS-applikation som bor i menyraden och ger dig snabb tillgång till aktuella elpriser, din förbrukning och kostnader. Appen är byggd för användare som vill ha koll på sina elkostnader utan att behöva logga in på olika webbportaler.

### Huvudfunktioner

**Realtidspriser**
- Visar aktuellt elpris direkt i menyraden (öre/kWh)
- Automatisk uppdatering var 15:e minut
- Visuell graf över dagens priser med färgkodning (låg, medel, hög)
- Stöd för alla svenska elområden (SE1-SE4)

**Förbrukningsanalys**
- Månatlig förbrukningsstatistik
- Daglig förbrukningshistorik
- Identifiering av effekttoppar för att optimera förbrukningen
- Kostnadsberäkningar baserat på faktisk förbrukning, spotpris och uppskattade avgifter

**Nätavgifter**
- Integration med svenska elnätsföretag
- Uppskattade nättariffer och standardvärden
- Beräkning av uppskattad total kostnad inklusive nätavgift

**Flera elleverantörer**
- Stöd för **Tibber** (via GraphQL API)
- Stöd för **Vaggeryd Energi**
- Utbyggbar arkitektur för fler leverantörer

### Perfekt för

- Husägare med rörligt elpris som vill optimera sin förbrukning
- Tibber-kunder som vill ha snabb åtkomst till sina data
- Den som vill förstå sina elkostnader bättre
- Användare som uppskattar minimalistiska, snygga appar

---

## Teknisk beskrivning

Spotprice är byggd med modern Swift och SwiftUI för macOS 15.0+. Projektet följer best practices för app-utveckling med tydlig separation av ansvar och en modulär arkitektur.

### Arkitektur

#### Core Components

**App Structure**
- `SpotpriceApp` - Huvudapplikationen med MenuBarExtra för menyintegration
- `AppDelegate` - Hanterar app lifecycle och systemhändelser
- Widget Extension - iOS/macOS widget-stöd via WidgetKit

**MVVM Pattern**
Projektet använder Model-View-ViewModel mönstret:

- **ViewModels**
  - `SpotPriceViewModel` - Huvudviewmodel med `@Observable` för automatisk UI-uppdatering
  - Periodisk auto-refresh var 15:e minut via structured concurrency

- **Services** (Business Logic Layer)
  - `SpotPriceService` - Hämtar spotpriser från elprisetjustnu.se API
  - `ConsumptionService` - Beräknar förbrukning, effekttoppar och kostnader
  - `GridTariffService` - Hanterar uppskattade nättariffer och standardvärden

- **Provider System** (Plugin Architecture)
  ```
  Protocol: ElectricityProvider
  ├── TibberProvider (GraphQL API)
  └── VaggerydProvider (REST API)

  ProviderRegistry - Dynamic provider registration
  ProviderCredentials - Secure credential storage
  ```

#### Data Flow

```
User Action → ViewModel → Service → Provider/API
                ↓           ↓
              State      Transform
                ↓           ↓
           SwiftUI ← Formatted Data
```

1. **Data Fetching**: ViewModels använder `async/await` för att hämta data från services
2. **State Management**: `@Observable` macro för reaktiv UI med minimal boilerplate
3. **Periodic Refresh**: Structured concurrency task som körs kontinuerligt
4. **Settings Sync**: NotificationCenter och async/await för data loading när inställningar ändras

#### Nyckelteknologier

**Swift Concurrency**
- Modern `async/await` för asynkron kod
- `Task` för periodisk uppdatering och cancellation
- `MainActor` isolation för UI-säkerhet
- `Sendable` conformance för thread-safe services

**SwiftUI & Observation**
- `@Observable` macro (Swift 5.9+) istället för legacy `@Published`
- Custom charts med SwiftUI Charts
- Liquid Glass design system för modern UI
- Adaptiv layout för olika skärmstorlekar

**Networking**
- `URLSession` med custom `NetworkSession`
- GraphQL för Tibber API
- REST för Vaggeryd och Spotprice APIs
- Robust error handling med `DisplayableError` protocol

**Persistence**
- `UserDefaults` med App Group för widget-delning
- `ConsumptionSettings` singleton med multi-provider credential storage
- JSON encoding/decoding för komplex data
- Automatisk migrering från legacy settings

#### Design Patterns

**Protocol-Oriented Design**
```swift
protocol ElectricityProvider {
    static var identifier: String { get }
    static var displayName: String { get }
    static var credentialFields: [CredentialField] { get }

    func testConnection() async throws
    func fetchConsumption(year: Int, month: Int) async throws -> ConsumptionData
    func fetchDailyConsumption(year: Int, month: Int) async throws -> [DailyConsumption]
    func fetchHourlyConsumption(startDate: Date, endDate: Date) async throws -> [HourlyConsumption]
}
```

**Dependency Injection**
Services accepterar dependencies via init för enkel testning:
```swift
init(
    service: SpotPriceService? = nil,
    consumptionService: ConsumptionService? = nil,
    now: @escaping () -> Date = { Date() }
)
```

**Error Handling**
Custom `DisplayableError` för användarvänliga felmeddelanden:
```swift
struct DisplayableError: Error {
    let message: String
}
```

#### Datamodeller

**Core Models**
- `SpotPriceItem` - Rådata från API (timeStart, timeEnd, sekPerKWh)
- `DayChartData` - Chart-optimerad data med buckets och thresholds
- `ConsumptionData` - Månadsdata med kWh och kostnad
- `DailyConsumption` / `HourlyConsumption` - Granulär förbrukningsdata
- `GridTariffModels` - Nättariffer med effekt- och energitariffer

**Chart Data**
Tertile-baserad färgkategorisering för intuitiv prisvisualisering:
```swift
struct PriceBucket {
    let start: Date
    let end: Date
    let orePerKWh: Double
    let category: PriceCategory  // .low, .medium, .high
}
```

#### Views & Components

**Reusable Components**
- `StatCardView` - Återanvändbar kort-komponent
- `PriceChangeIndicator` - Visuell indikator för prisförändringar
- `SpotPriceBarChart` - Custom bar chart med SwiftUI Charts
- `ProviderPicker` - Leverantörsväljare med dynamisk provider registry

**Main Views**
- `ModernMenuBarView` - Huvudvy i menyraden
- `SettingsView` - Inställningar med provider credentials
- `CostCalculationSection` - Detaljerad kostnadsuppdelning
- `MonthlyStatsSection` - Månadsstatistik och toppdagar

#### Configuration & Settings

**ConsumptionSettings**
- Singleton pattern med `@Observable` för automatisk UI-uppdatering
- App Group support för widget sharing
- Multi-provider credential storage
- Automatic migration från legacy single-provider setup
- NotificationCenter integration för cross-component updates

**Design System**
Centraliserad design configuration i `DesignSystem`:
- Färgpalett (low, medium, high price colors)
- Typografi (SF Pro, Osans custom fonts)
- Spacing och corner radius
- Chart configuration

#### Testing & Quality

**Testability**
- Protocol-based architecture för enkel mocking
- Dependency injection för isolerade unit tests
- Date injection för deterministiska tester
- Separate `NetworkSession` för mock responses

**Code Quality**
- Swift 6 strict concurrency checking
- Sendable conformance för thread safety
- Private access control för encapsulation
- Comprehensive error handling

### Framtida utveckling

Möjliga förbättringar:
- Fler elleverantörer (Vattenfall, E.ON, etc.)
- Push-notifikationer vid låga priser
- ML-baserade prisförutsägelser
- Exportfunktion för data (CSV, PDF)
- iOS companion app med widget
- Energispartips baserat på förbrukningsprofil

### Krav

- macOS 15.0 eller senare
- Xcode 16.0+ för utveckling
- Swift 6.0
- API-nyckel från din elleverantör (Tibber eller Vaggeryd)

### Installation för utvecklare

1. Klona repository
2. Öppna `Spotprice.xcodeproj` i Xcode
3. Bygg och kör med `Cmd+R`
4. Konfigurera din elleverantör i Settings

### Licens

[Lägg till licensinformation här]

### Kontakt

[Lägg till kontaktinformation här]

---

**Byggd med ❤️ för den svenska elmarknaden**
