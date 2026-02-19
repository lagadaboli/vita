import Foundation

struct FoxitPDFServicesService {
    private static let maxPollAttempts = 30

    // MARK: - Response models

    private struct UploadResponse: Decodable {
        let documentId: String
    }

    private struct CompressResponse: Decodable {
        let taskId: String
    }

    private struct TaskStatusResponse: Decodable {
        let status: String
        let resultDocumentId: String?
    }

    // MARK: - Public API

    static func optimize(pdfData: Data, config: FoxitConfig) async throws -> Data {
        guard config.isConfigured else { throw FoxitError.notConfigured }

        let documentId = try await uploadDocument(pdfData: pdfData, config: config)
        let taskId = try await compressDocument(documentId: documentId, config: config)
        let resultDocumentId = try await pollTask(taskId: taskId, config: config)
        return try await downloadDocument(documentId: resultDocumentId, config: config)
    }

    // MARK: - Steps

    private static func uploadDocument(pdfData: Data, config: FoxitConfig) async throws -> String {
        let url = URL(string: "\(FoxitConfig.baseURL)/pdf-services/api/documents/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.clientSecret, forHTTPHeaderField: "client_secret")

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

    private static func compressDocument(documentId: String, config: FoxitConfig) async throws -> String {
        let url = URL(string: "\(FoxitConfig.baseURL)/pdf-services/api/documents/modify/pdf-compress")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.clientSecret, forHTTPHeaderField: "client_secret")

        let bodyDict: [String: Any] = ["documentId": documentId, "compressionLevel": "MEDIUM"]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FoxitError.httpError(code)
        }
        guard let decoded = try? JSONDecoder().decode(CompressResponse.self, from: data) else {
            throw FoxitError.decodingFailed
        }
        return decoded.taskId
    }

    private static func pollTask(taskId: String, config: FoxitConfig) async throws -> String {
        let url = URL(string: "\(FoxitConfig.baseURL)/pdf-services/api/tasks/\(taskId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.clientSecret, forHTTPHeaderField: "client_secret")

        for _ in 0..<maxPollAttempts {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw FoxitError.httpError(code)
            }
            guard let decoded = try? JSONDecoder().decode(TaskStatusResponse.self, from: data) else {
                throw FoxitError.decodingFailed
            }
            if decoded.status == "COMPLETED" {
                guard let resultId = decoded.resultDocumentId else { throw FoxitError.decodingFailed }
                return resultId
            }
        }
        throw FoxitError.httpError(408)
    }

    private static func downloadDocument(documentId: String, config: FoxitConfig) async throws -> Data {
        let url = URL(string: "\(FoxitConfig.baseURL)/pdf-services/api/documents/\(documentId)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.clientId, forHTTPHeaderField: "client_id")
        request.setValue(config.clientSecret, forHTTPHeaderField: "client_secret")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FoxitError.httpError(code)
        }
        return data
    }
}

// MARK: - Helpers

private extension String {
    var utf8Data: Data { Data(utf8) }
}
