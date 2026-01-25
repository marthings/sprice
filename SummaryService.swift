import Foundation

// MARK: - 1. Utility för URL-generering (Statisk)

final class WeekURLGenerator {
    
    // ANVÄNDER STATISK URL EFTERSOM DYNAMISK GENERERING MÅSTE SES ÖVER
    private let staticURLString = "https://ei.se/om-oss/nyheter/laget-pa-elmarknaden/arkiv---laget-pa-elmarknaden/2025-04-01-laget-pa-elmarknaden---vecka-13-2025"
    
    init() {
        // Inga kalenderinställningar behövs när vi använder statisk URL.
    }
    
    /// Returnerar den statiska URL:en för veckobrevet.
    func generateURL(for date: Date = Date()) throws -> URL {
        guard let url = URL(string: staticURLString) else {
            throw DisplayableError("Kunde inte skapa giltig URL för veckorapporten.")
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
        let systemPrompt = "Du är en expert på elmarknaden. Din uppgift är att läsa den bifogade svenska veckorapporten (hämtad från \(sourceURL.absoluteString)) och ge en kort (max 3 meningar), mänsklig och enkel summering av vad som primärt påverkar elpriset just denna vecka. Svara endast med summeringen."
        
        let model = "gpt-3.5-turbo"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Veckorapporten (textinnehåll): \n\n" + reportText] 
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
