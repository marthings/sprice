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
        // ÄNDRAD: Nu lagrar vi både summeringen och den fullständiga URL:en
        case loaded(summary: String, url: URL) 
        case failed(String)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), 
                 (.loadingURL, .loadingURL), 
                 (.fetchingReport, .fetchingReport), 
                 (.summarizing, .summarizing), 
                 (.failed, .failed):
                return true
            case (.loaded(let lS, let lU), .loaded(let rS, let rU)):
                return lS == rS && lU == rU
            default:
                return false
            }
        }
    }
    
    @Published private(set) var state: State = .idle
    
    private let urlGenerator: WeekURLGenerator
    private let openAIService: OpenAIService
    private let session: URLSession
    
    init(
        session: URLSession = .shared,
        urlGenerator: WeekURLGenerator = WeekURLGenerator(),
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
            // 1. Generera URL baserat på aktuell vecka
            let reportURL = try urlGenerator.generateURL()
            
            state = .fetchingReport
            
            // 2. Hämta rått innehåll (Web Scraping)
            let (data, response) = try await session.data(from: reportURL)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw DisplayableError("Kunde inte hämta veckorapporten. Statuskod: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            
            guard let reportHTML = String(data: data, encoding: .utf8) else {
                throw DisplayableError("Kunde inte tolka veckorapportens innehåll.")
            }
            
            // NYTT STEG: Parsa/städa HTML till ren text
            let cleanReportText = try cleanHTMLToPlainText(reportHTML)
            
            state = .summarizing
            
            // 3. Skicka den rena texten till OpenAI för summering
            let summary = try await openAIService.summarize(reportText: cleanReportText, sourceURL: reportURL)
            
            // 4. Ladda med summering och URL
            state = .loaded(summary: summary, url: reportURL)
            
        } catch let error as DisplayableError {
            state = .failed(error.message)
        } catch {
            print("Oväntat fel vid summering: \(error)")
            state = .failed("Ett oväntat fel inträffade vid hämtning eller summering.")
        }
    }
}
