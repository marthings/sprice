# Testa Sprice

Sprice visar vad din el kostar just nu och hur kostnaden blev över tid. Appen lägger ihop spotpriset, elhandlarens påslag, elnät, skatt och moms, och kan hämta din egen förbrukning om du har Vaggeryds Energi eller Tibber.

Tack för att du testar! Det som behöver prövas mest är att siffrorna stämmer med din faktura och att inget känns krångligt eller konstigt.

## Installera

1. Installera appen **TestFlight** från App Store på din iPhone, om du inte redan har den.
2. Öppna inbjudan du fick till din e-post eller i TestFlight, och tryck **Installera** eller **Acceptera**.
3. Starta Sprice från TestFlight eller från hemskärmen. Nya versioner dyker upp i TestFlight, och du får en avisering.

Du behöver iOS 26 eller senare.

## Ställ in först

Gå till fliken **Inställningar** och gå uppifrån och ner:

- [ ] **Elområde.** Välj SE1, SE2, SE3 eller SE4. Står det inte på fakturan: Småland ligger i SE3.
- [ ] **Elhandel.** Välj avtalstyp (kvartspris, rörligt månadspris eller fast pris) och fyll i påslag och månadsavgift som på din faktura, inklusive moms.
- [ ] **Elnät.** Välj ditt nätbolag. Kontrollera att fast avgift och överföringsavgift stämmer med fakturan.
- [ ] **Förbrukning, Datakälla.** Har du Vaggeryds Energi eller Tibber kan du logga in här för att få din egen förbrukning. Det är valfritt. Utan inloggning visar appen ändå priser och en uppskattad kostnad.
- [ ] **Temperatur.** Välj den ort som ligger närmast dig. Appen använder inte din position.
- [ ] **Elbil.** Slå på om du har elbil (se längre ner).

## Testrunda

Ta det i den ordning du vill. Skriv upp det som ser konstigt ut, även om du är osäker.

### Kostnad

- [ ] Det stora priset högst upp ska vara ungefär detsamma som på andra elprissidor för ditt elområde, plus påslag, nät, skatt och moms.
- [ ] Cirkeldiagrammet delar upp en kilowattimme i spotpris, påslag, elnät, skatt, certifikat, fasta avgifter och moms. Summan ska bli priset i mitten.
- [ ] Tryck på i-knapparna. Texten ska vara begriplig utan förkunskaper.
- [ ] Kolla att "Medel", "Lågt" och "Högt" känns rimligt jämfört med dagens priser.

### Priser

- [ ] Diagrammet visar dagens kvartspriser. Byt mellan idag och imorgon (imorgon kommer ut runt kl. 13).
- [ ] Raden högst upp berättar när det är billigast och dyrast. Stämmer det med diagrammet?
- [ ] Det gröna fältet i diagrammet visar de billigaste timmarna. Passar det med det du ser?
- [ ] Peka eller dra på diagrammet och se att pris och tid följer med.

### Historik

- [ ] Välj en månad med pilarna överst. Summan i **Månadens siffror** ska ligga nära månadens faktura (elhandel och nät tillsammans).
- [ ] Tryck **Visa detaljer** och kolla uppdelningen i priskomponenter.
- [ ] Kortet **Därför blev det dyrare** (eller billigare) förklarar skillnaden mot förra månaden. Förstår du texten? Stämmer "Mer el", "Spotpris" och "Påslag, elnät och skatt" med hur du upplevde månaden?
- [ ] Temperaturraderna jämför med förra månaden och förra året. Verkar det rimligt?
- [ ] **Kostnad per dag**: dyraste dagen ska stämma med din känsla. Linjen visar temperatur.
- [ ] Öppna den pågående månaden. Det ska gå snabbt, och appen får inte hänga sig.

### Inställningar

- [ ] Ändra påslag eller elområde och gå tillbaka till Kostnad. Priset ska ändras direkt.
- [ ] Skriv in ett värde med komma (till exempel 4,5) och kolla att det sparas rätt.
- [ ] Logga in på din datakälla med fel lösenord. Du ska få ett tydligt meddelande, och resten av appen ska fungera som vanligt.

### Widgets

- [ ] Lägg till Sprice-widgeten på hemskärmen (håll in på en tom plats, tryck på plus, sök efter Sprice). Prova liten, mellan och stor.
- [ ] Priset i widgeten ska vara samma som i appen.
- [ ] Vänta till nästa kvart (klockan :00, :15, :30 eller :45). Widgeten ska ha bytt pris inom några minuter.
- [ ] Ändra något i Inställningar och se att widgeten följer med.

### Elbil

- [ ] Slå på **Jag har elbil** i Inställningar. Under Historik kan kortet **Vad drog?** dyka upp med en gissning om vilka timmar som var laddning.
- [ ] Jämför med dina riktiga laddningar. Hittar appen dem? Pekar den ut något som inte var laddning (till exempel bastu eller värmepump)? Det är en gissning, så fel är intressanta för oss.

### Utseende och tillgänglighet

- [ ] Prova mörkt läge. Texten ska vara lätt att läsa mot bakgrunden.
- [ ] Bakgrunden är landskapsbilden och står stilla. Ser den ut att ha djup (en svag blå himmel högst upp, ett varmt sken vid horisonten) utan att kortens text eller klockan högst upp blir svårare att läsa? Titta i både ljust och mörkt läge.
- [ ] Slå på **Visa exempeldata** under Inställningar. Alla flikar ska visa påhittad data, med texten Exempeldata högst upp. Slå av igen och se att dina egna siffror är tillbaka.
- [ ] Gör texten större under Inställningar, Skärm och ljusstyrka, Textstorlek. Inget ska klippas eller hamna över annat.

## Bra att veta

- **Det är uppskattningar.** Appen räknar ut kostnaden från de värden du anger och från priserna. Den matchar inte alltid fakturan ören för ören.
- **Förbrukningen ligger efter.** Vaggeryds Energi lämnar ut preliminär data med ungefär en dags fördröjning, så de senaste timmarna eller dagen kan saknas eller ändras i efterhand.
- **Leverantörer.** Just nu stöds Vaggeryds Energi och Tibber för förbrukning. Avgifter som ändrades vid årsskiftet räknas bara rätt bakåt för Vaggeryds elnät. För andra nätbolag används dagens avgifter för alla månader.
- **Elbil är en gissning.** Appen kan inte veta vad som drog el.
- **Temperaturen** hämtas från Open-Meteo för den ort du väljer. Inget annat om dig skickas dit.
- All din historik sparas bara på din telefon. Om du tar bort appen försvinner den.

## Så rapporterar du ett fel

Det enklaste: ta en skärmbild i appen. Tryck på bilden som dyker upp nere till vänster, tryck på **Dela** och välj **Skicka beta-feedback**. Skriv en rad om vad du förväntade dig och vad som hände. Du kan också skaka telefonen medan du är i appen för att öppna feedback.

Berätta gärna:

- Vilken flik och vilken månad eller dag det gällde.
- Vad du förväntade dig och vad du såg i stället. Skriv siffran du hade väntat dig om du vet den (till exempel från fakturan).
- Dina inställningar: elområde, avtalstyp och om du har loggat in på en datakälla.
- Om appen hängde sig eller kraschade, och vad du gjorde precis innan. Kraschar skickas till oss automatiskt via TestFlight.
- Vilken version du har (står i TestFlight under appen) och vilken iPhone och iOS-version.
