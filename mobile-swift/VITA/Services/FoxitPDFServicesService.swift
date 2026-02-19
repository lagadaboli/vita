import Foundation

struct FoxitPDFServicesService {
    private static let maxPollAttempts = 30
    private static let pollIntervalNanos: UInt64 = 1_500_000_000

    // MARK: - Response models

    private struct UploadResponse: Decodable {
        let documentId: String
    }

    private struct TaskCreationResponse: Decodable {
        let taskId: String
    }

    private struct TaskStatusResponse: Decodable {
        let status: String
        let resultDocumentId: String?
    }

    // MARK: - Public API

    static func optimize(pdfData: Data, config: FoxitConfig) async throws -> Data {
        guard config.pdfServices.isConfigured else { throw FoxitError.notConfigured }

        var documentId = try await uploadDocument(pdfData: pdfData, config: config)

        documentId = try await runTask(
            endpoint: "/pdf-services/api/documents/modify/pdf-compress",
            payload: [
                "documentId": documentId,
                "compressionLevel": "MEDIUM",
            ],
            config: config
        )

        // Linearization improves byte serving and opening speed in web viewers.
        documentId = try await runBestEffortTask(
            endpoint: "/pdf-services/api/documents/optimize/pdf-linearize",
            payload: ["documentId": documentId],
            inputDocumentId: documentId,
            config: config
        )

        return try await downloadDocument(documentId: documentId, config: config)
    }

    // MARK: - Steps

    private static func uploadDocument(pdfData: Data, config: FoxitConfig) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/pdf-services/api/documents/upload") else {
            throw FoxitError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.pdfServices.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.pdfServices.clientSecret, forHTTPHeaderField: "client_secret")

        let boundary = "vita-boundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"report.pdf\"\r\n".utf8Data)
        body.append("Content-Type: application/pdf\r\n\r\n".utf8Data)
        body.append(pdfData)
        body.append("\r\n--\(boundary)--\r\n".utf8Data)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FoxitError.httpError(code)
        }
        guard let decoded = try? JSONDecoder().decode(UploadResponse.self, from: data) else {
            throw FoxitError.decodingFailed
        }
        return decoded.documentId
    }

    private static func runTask(
        endpoint: String,
        payload: [String: Any],
        config: FoxitConfig
    ) async throws -> String {
        let taskId = try await startTask(endpoint: endpoint, payload: payload, config: config)
        return try await pollTask(taskId: taskId, config: config)
    }

    private static func runBestEffortTask(
        endpoint: String,
        payload: [String: Any],
        inputDocumentId: String,
        config: FoxitConfig
    ) async throws -> String {
        do {
            return try await runTask(endpoint: endpoint, payload: payload, config: config)
        } catch let error as FoxitError {
            switch error {
            case .httpError(let code) where unsupportedOperationCodes.contains(code):
                return inputDocumentId
            case .decodingFailed:
                return inputDocumentId
            default:
                throw error
            }
        }
    }

    private static func startTask(
        endpoint: String,
        payload: [String: Any],
        config: FoxitConfig
    ) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)\(endpoint)") else {
            throw FoxitError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.pdfServices.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.pdfServices.clientSecret, forHTTPHeaderField: "client_secret")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FoxitError.decodingFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FoxitError.httpError(http.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(TaskCreationResponse.self, from: data) else {
            throw FoxitError.decodingFailed
        }
        return decoded.taskId
    }

    private static func pollTask(taskId: String, config: FoxitConfig) async throws -> String {
        guard let url = URL(string: "\(config.baseURL)/pdf-services/api/tasks/\(taskId)") else {
            throw FoxitError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.pdfServices.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.pdfServices.clientSecret, forHTTPHeaderField: "client_secret")

        for _ in 0..<maxPollAttempts {
            try await Task.sleep(nanoseconds: pollIntervalNanos)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw FoxitError.httpError(code)
            }
            guard let decoded = try? JSONDecoder().decode(TaskStatusResponse.self, from: data) else {
                throw FoxitError.decodingFailed
            }

            let status = decoded.status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            switch status {
            case "COMPLETED", "SUCCESS", "SUCCEEDED":
                guard let resultId = decoded.resultDocumentId else { throw FoxitError.decodingFailed }
                return resultId
            case "FAILED", "FAILURE", "ERROR", "CANCELED", "CANCELLED", "ABORTED":
                throw FoxitError.taskFailed(status)
            default:
                continue
            }
        }

        throw FoxitError.httpError(408)
    }

    private static func downloadDocument(documentId: String, config: FoxitConfig) async throws -> Data {
        guard let url = URL(string: "\(config.baseURL)/pdf-services/api/documents/\(documentId)/download") else {
            throw FoxitError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.pdfServices.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.pdfServices.clientSecret, forHTTPHeaderField: "client_secret")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FoxitError.httpError(code)
        }
        return data
    }
}

// MARK: - Helpers

private let unsupportedOperationCodes: Set<Int> = [400, 404, 405, 422]

private extension String {
    var utf8Data: Data { Data(utf8) }
}
