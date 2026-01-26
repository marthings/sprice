import Foundation
import Combine
import SwiftUI

@MainActor
final class SummaryViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loadingURL
        case fetchingReport
        case summarizing
        // UPPDATERAD: Nu lagrar vi summering, URL och om det är föregående månads data
        case loaded(summary: String, url: URL, isPreviousMonth: Bool) 
        case failed(String)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), 
                 (.loadingURL, .loadingURL), 
                 (.fetchingReport, .fetchingReport), 
                 (.summarizing, .summarizing), 
                 (.failed, .failed):
                return true
            case (.loaded(let lS, let lU, let lP), .loaded(let rS, let rU, let rP)):
                return lS == rS && lU == rU && lP == rP
            default:
                return false
            }
        }
    }
    
    @Published private(set) var state: State = .idle
    
    private let urlGenerator: MonthlyReportURLGenerator
    private let openAIService: OpenAIService
    private let session: URLSession
    
    init(
        session: URLSession = .shared,
        urlGenerator: MonthlyReportURLGenerator = MonthlyReportURLGenerator(),
        openAIService: OpenAIService = OpenAIService()
    ) {
        self.session = session
        self.urlGenerator = urlGenerator
        self.openAIService = openAIService
    }
    
    // NY FUNKTION: För att konvertera HTML till ren text
    private func cleanHTMLToPlainText(_ html: String) throws -> String {
        guard let data = html.data(using: .utf8) else {
            throw DisplayableError("Kunde inte koda HTML till data.")
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        // Konvertera HTML till NSAttributedString, vilket strippar de flesta taggar.
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
             // Fallback: Om konverteringen misslyckas (t.ex. p.g.a ogiltig HTML), returnera rå HTML
             print("VARNING: Kunde inte konvertera HTML till NSAttributedString. Skickar rå HTML till OpenAI.")
             return html
        }
        
        // Returnera den rena texten
        return attributedString.string
    }
    
    func loadSummary() async {
        // Förhindra laddning om den redan laddar/summerar
        if case .loadingURL = state { return }
        if case .fetchingReport = state { return }
        if case .summarizing = state { return }

        state = .loadingURL
        
        do {
            // 1. Försök först med aktuell månad
            let currentMonthURL = try urlGenerator.generateURL()
            
            // Försök hämta aktuell månads rapport
            if let result = try await attemptToFetchReport(from: currentMonthURL) {
                state = .loaded(summary: result.summary, url: result.url, isPreviousMonth: false)
                return
            }
            
            // 2. Om aktuell månad misslyckas, försök föregående månad
            let previousMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            let previousMonthURL = try urlGenerator.generateURL(for: previousMonthDate)
            
            if let result = try await attemptToFetchReport(from: previousMonthURL) {
                // Lägg till notis om att rapporten kommer snart för aktuell månad
                let enhancedSummary = result.summary + "\n\nObs: Rapporten för aktuell månad (januari 2026) kommer snart. Detta baseras på föregående månads data."
                state = .loaded(summary: enhancedSummary, url: result.url, isPreviousMonth: true)
                return
            }
            
            // 3. Om båda misslyckas
            throw DisplayableError("Kunde inte hämta varken aktuell eller föregående månads rapport.")
            
        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch {
            print("Oväntat fel vid summering: \(error)")
            state = .failed("Ett oväntat fel inträffade vid hämtning eller summering.")
        }
    }
    
    // HJÄLPFUNKTION: Försöker hämta och summera rapport från given URL
    private func attemptToFetchReport(from url: URL) async throws -> (summary: String, url: URL)? {
        state = .fetchingReport
        
        let (data, response) = try await session.data(from: url)
        
        // Kontrollera om HTTP-svaret är lyckat
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Om det inte är 404, kasta fel. Om det är 404, returnera nil för att försöka nästa månad
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                print("Rapport inte funnen för URL: \(url.absoluteString)")
                return nil
            }
            throw DisplayableError("Oväntat HTTP-fel vid hämtning från \(url.absoluteString). Statuskod: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        guard let reportHTML = String(data: data, encoding: .utf8) else {
            throw DisplayableError("Kunde inte tolka rapportens innehåll från \(url.absoluteString)")
        }
        
        // Parsa HTML till ren text
        let cleanReportText = try cleanHTMLToPlainText(reportHTML)
        
        state = .summarizing
        
        // Skicka till OpenAI för summering
        let summary = try await openAIService.summarize(reportText: cleanReportText, sourceURL: url)
        
        return (summary: summary, url: url)
    }
}
