import Foundation

// MARK: - 1. Utility för URL-generering (Månadsrapporter)

final class MonthlyReportURLGenerator {
    
    private let baseURLString = "https://elmarknad.se/rapporter/laget-pa-elmarknaden"
    
    // Svenska månadsnamn för URL-generering
    private let swedishMonthNames: [Int: String] = [
        1: "januari", 2: "februari", 3: "mars", 4: "april",
        5: "maj", 6: "juni", 7: "juli", 8: "augusti", 
        9: "september", 10: "oktober", 11: "november", 12: "december"
    ]
    
    init() {
        // Ingen konfiguration behövs
    }
    
    /// Genererar URL baserat på aktuell månad på svenska
    func generateURL(for date: Date = Date()) throws -> URL {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.month, .year], from: date)
        
        guard let month = components.month,
              let year = components.year,
              let monthName = swedishMonthNames[month] else {
            throw DisplayableError("Kunde inte extrahera månad från datum.")
        }
        
        // Bygger URL: https://elmarknad.se/rapporter/laget-pa-elmarknaden-[månad]-[år]/
        let urlString = "\(baseURLString)-\(monthName)-\(year)/"
        
        guard let url = URL(string: urlString) else {
            throw DisplayableError("Kunde inte skapa giltig URL för månadsrapporten: \(urlString)")
        }
        
        return url
    }
}

// MARK: - 2. OpenAI Summeringstjänst

actor OpenAIService {
    private let session: URLSession
    // API-nyckeln är kvar här
    private let apiKey: String = "REMOVED_OPENAI_KEY"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Skickar ren text (förväntas vara veckorapporten) till OpenAI för summering.
    func summarize(reportText: String, sourceURL: URL) async throws -> String {
        let systemPrompt = "Du är en expert på elmarknaden. Din uppgift är att läsa den bifogade svenska månadsrapporten (hämtad från \(sourceURL.absoluteString)) och ge en kort (max 3 meningar), mänsklig och enkel summering av vad som primärt påverkar elpriset under denna månad. Svara endast med summeringen."
        
        let model = "gpt-3.5-turbo"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Månadsrapporten (textinnehåll): \n\n" + reportText] 
            ],
            "temperature": 0.3
        ]
        
        // Konvertera payload till Data
        let requestBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        // Skapa förfrågan
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Försök att läsa ut felmeddelande från OpenAI om tillgängligt
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                 throw DisplayableError("OpenAI API Fel: \(error.error.message)")
            }
            throw DisplayableError("OpenAI API returnerade ett felaktigt svar.")
        }
        
        // Parsar svaret
        let completion = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)
        
        guard let summary = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            throw DisplayableError("OpenAI returnerade ingen giltig summering.")
        }
        
        return summary
    }
}

// MARK: - 3. DTO:er för OpenAI API

struct OpenAICompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let role: String
            let content: String
        }
        let message: Message
        let finishReason: String
        
        private enum CodingKeys: String, CodingKey {
            case message, finishReason = "finish_reason"
        }
    }
    let choices: [Choice]
}

struct OpenAIErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
        let type: String
    }
    let error: ErrorDetail
}
