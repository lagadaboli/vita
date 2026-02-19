import Foundation

enum FoxitError: Error, LocalizedError {
    case notConfigured
    case invalidBaseURL
    case httpError(Int)
    case decodingFailed
    case taskFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Foxit API credentials are not configured for both Document Generation and PDF Services. Please add them in Settings."
        case .invalidBaseURL:
            return "Foxit base URL is invalid. Update it in Settings."
        case .httpError(let code):
            return "Foxit API returned HTTP \(code)."
        case .decodingFailed:
            return "Failed to decode Foxit API response."
        case .taskFailed(let status):
            return "Foxit PDF task failed with status: \(status)."
        }
    }
}

struct FoxitDocumentGenerationService {
    private struct GenerationRequest<T: Encodable>: Encodable {
        let outputFormat: String
        let base64FileString: String
        let documentValues: T
    }

    private struct GenerationResponse: Decodable {
        let base64FileString: String
    }

    static func generate(
        templateBase64: String,
        values: some Encodable,
        config: FoxitConfig
    ) async throws -> Data {
        guard config.documentGeneration.isConfigured else { throw FoxitError.notConfigured }

        guard let url = URL(string: "\(config.baseURL)/document-generation/api/GenerateDocumentBase64") else {
            throw FoxitError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.documentGeneration.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.documentGeneration.clientSecret, forHTTPHeaderField: "client_secret")

        let body = GenerationRequest(
            outputFormat: "pdf",
            base64FileString: templateBase64,
            documentValues: values
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FoxitError.decodingFailed }
        guard (200..<300).contains(http.statusCode) else { throw FoxitError.httpError(http.statusCode) }

        guard
            let decoded = try? JSONDecoder().decode(GenerationResponse.self, from: data),
            let pdfData = Data(base64Encoded: decoded.base64FileString)
        else { throw FoxitError.decodingFailed }

        return pdfData
    }
}
