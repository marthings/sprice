import Foundation

// MARK: - OpenAI Summeringstjänst

actor OpenAIService {
    private let session: URLSession
    private let apiKey: String = "REMOVED_OPENAI_KEY"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Analyzes monthly consumption comparison and explains price differences
    func analyzeMonthlyComparison(_ comparison: MonthlyComparison) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "sv_SE")
        dateFormatter.dateFormat = "MMMM yyyy"

        let currentMonthStr = dateFormatter.string(from: comparison.current.monthDate)
        let currentKWh = String(format: "%.0f", comparison.current.totalKWh)
        let currentPrice = String(format: "%.1f", comparison.currentAvgPrice)
        let currentCost = String(format: "%.0f", comparison.current.totalKWh * comparison.currentAvgPrice / 100)

        var previousSection = ""
        var priceDiffSection = ""

        if let prev = comparison.previous,
           let prevPrice = comparison.previousAvgPrice {
            let prevMonthStr = dateFormatter.string(from: prev.monthDate)
            let prevKWh = String(format: "%.0f", prev.totalKWh)
            let prevPriceStr = String(format: "%.1f", prevPrice)
            let prevCost = String(format: "%.0f", prev.totalKWh * prevPrice / 100)

            previousSection = """

            FÖRRA MÅNADEN (\(prevMonthStr)):
            • Förbrukning: \(prevKWh) kWh
            • Snittpris: \(prevPriceStr) öre/kWh
            • Kostnad: ~\(prevCost) kr
            """

            if let priceChange = comparison.priceChangePercent {
                let sign = priceChange >= 0 ? "+" : ""
                priceDiffSection = "\n\nPRISSKILLNAD: \(sign)\(String(format: "%.1f", priceChange))%"
            }
        }

        let systemPrompt = """
        Du är en svensk elmarknadsexpert. Analysera användarens elförbrukning:

        DENNA MÅNAD (\(currentMonthStr)):
        • Förbrukning: \(currentKWh) kWh
        • Snittpris: \(currentPrice) öre/kWh
        • Kostnad: ~\(currentCost) kr\(previousSection)\(priceDiffSection)

        Förklara kort (2-3 meningar) varför priset skiljer sig.
        Beakta: väder, vindkraft, kärnkraft, import/export, säsong.
        Skriv enkelt och konkret på svenska.
        """

        let model = "gpt-3.5-turbo"
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Ge mig en kort analys av prisläget."]
            ],
            "temperature": 0.3
        ]

        let requestBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw DisplayableError("OpenAI API Fel: \(error.error.message)")
            }
            throw DisplayableError("OpenAI API returnerade ett felaktigt svar.")
        }

        let completion = try JSONDecoder().decode(OpenAICompletionResponse.self, from: data)

        guard let summary = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            throw DisplayableError("OpenAI returnerade ingen giltig analys.")
        }

        return summary
    }
}

// MARK: - DTO:er för OpenAI API

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
