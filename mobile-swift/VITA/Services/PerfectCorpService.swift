import Foundation
import UIKit

/// PerfectCorp YouCam Skin Analysis API (V2 server-to-server).
///
/// Correct workflow (from official docs at yce.perfectcorp.com):
///
///   Step 1a. POST /s2s/v2.0/file/skin-analysis
///              body: { "file_name": "selfie.jpg" }
///              → result.file_id + result.upload_url + result.headers
///
///   Step 1b. PUT {upload_url}
///              Content-Type: image/jpg
///              body: raw JPEG bytes
///
///   Step 2.  POST /s2s/v2.0/task/skin-analysis
///              body: { "file_id": "...", "dst_actions": ["acne", ...] }
///              → result.task_id
///
///   Step 3.  GET /s2s/v2.0/task/skin-analysis?task_id={task_id}   ← query param
///              poll result.task_status until "success" | "error"
///              results in result.output.{concern}.score (0–100)
///
/// Valid SD dst_actions: acne, wrinkle, pore, texture, pigmentation, hydration
/// (SD and HD cannot be mixed in one request)
///
/// Falls back to demo data when no API key is configured.
enum PerfectCorpService {

    // MARK: - Public models

    enum SkinConditionType: String, CaseIterable, Equatable {
        // These are the exact valid SD concern keys from the PerfectCorp API
        case acne         = "acne"
        case wrinkle      = "wrinkle"
        case pore         = "pore"
        case texture      = "texture"
        case pigmentation = "pigmentation"
        case hydration    = "hydration"

        var displayName: String {
            switch self {
            case .acne:         return "Acne"
            case .wrinkle:      return "Wrinkles"
            case .pore:         return "Pores"
            case .texture:      return "Uneven Texture"
            case .pigmentation: return "Pigmentation"
            case .hydration:    return "Hydration"
            }
        }

        var icon: String {
            switch self {
            case .acne:         return "circle.fill"
            case .wrinkle:      return "waveform"
            case .pore:         return "aqi.medium"
            case .texture:      return "paintpalette.fill"
            case .pigmentation: return "sun.max.fill"
            case .hydration:    return "drop.fill"
            }
        }

        /// All six SD concerns — request them all in one call.
        static var requestedConcerns: [SkinConditionType] { allCases }
    }

    enum FaceZone: String, CaseIterable, Hashable {
        case forehead   = "Forehead"
        case leftCheek  = "Left Cheek"
        case rightCheek = "Right Cheek"
        case nose       = "Nose"
        case chin       = "Chin"
        case underEyes  = "Under Eyes"
    }

    struct SkinCondition: Identifiable {
        let id = UUID()
        let type: SkinConditionType
        let score: Int              // 0–100 from API (higher = more of this condition)
        let severity: Double        // score / 100, used for UI thresholds
        let confidence: Double
        let affectedZones: [FaceZone]
        let heatmapIntensity: [FaceZone: Double]

        var severityLabel: String {
            if severity > 0.65 { return "Severe" }
            if severity > 0.35 { return "Moderate" }
            return "Mild"
        }
    }

    struct AnalysisResult {
        let timestamp: Date
        let overallScore: Int       // 0–100, higher = better skin health
        let conditions: [SkinCondition]
        let source: String          // "perfectcorp" or "demo"
    }

    // MARK: - Errors

    enum APIError: Error, LocalizedError {
        case notConfigured
        case uploadFailed(String)
        case taskCreationFailed(String)
        case taskTimeout
        case parseError(String)
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "PerfectCorp API key not configured. Add it in Settings → Skin Audit."
            case .uploadFailed(let msg):
                return "Upload failed: \(msg)"
            case .taskCreationFailed(let msg):
                return "Task failed: \(msg)"
            case .taskTimeout:
                return "Skin analysis timed out after 30 s. Please try again."
            case .parseError(let msg):
                return "Unexpected API response: \(msg)"
            case .httpError(let code, let body):
                return "API error \(code): \(body)"
            }
        }
    }

    // MARK: - Entry points

    static func analyze(image: UIImage) async throws -> AnalysisResult {
        let config = PerfectCorpConfig.current
        guard config.isConfigured else {
            return await generateDemoResult()
        }
        return try await callRealAPI(image: image, apiKey: config.apiKey)
    }

    static func analyzeDemo() async -> AnalysisResult {
        await generateDemoResult()
    }

    // MARK: - Real API

    private static let base = "https://yce-api-01.makeupar.com"

    private static func callRealAPI(image: UIImage, apiKey: String) async throws -> AnalysisResult {
        // ── Step 1: Upload image ───────────────────────────────────────────────
        let fileID: String
        do {
            fileID = try await uploadImage(image, apiKey: apiKey)
        } catch let e as APIError {
            throw APIError.uploadFailed("[Step 1] \(e.localizedDescription ?? "")")
        }

        // ── Step 2: Create analysis task ───────────────────────────────────────
        let taskID: String
        do {
            taskID = try await createTask(fileID: fileID, apiKey: apiKey)
        } catch let e as APIError {
            throw APIError.taskCreationFailed("[Step 2] \(e.localizedDescription ?? "")")
        }

        // ── Step 3: Poll for result ────────────────────────────────────────────
        let raw: TaskResultResponse
        do {
            raw = try await pollTask(taskID: taskID, apiKey: apiKey)
        } catch let e as APIError {
            throw APIError.taskCreationFailed("[Step 3] \(e.localizedDescription ?? "")")
        }

        return mapResult(raw, timestamp: Date())
    }

    // MARK: Step 1a — Create file entry → get upload_url + file_id

    // POST /s2s/v2.0/file/skin-analysis
    // body: { "files": [{ "file_name": "selfie.jpg" }] }
    // Response: { "status": 200, "result": { "files": [{ "file_id": "...", "upload_url": "..." }] } }
    private struct FileCreateRequest: Encodable {
        let files: [FileEntry]
        struct FileEntry: Encodable {
            let fileName: String    // → "file_name"
        }
    }

    private struct FileCreateResponse: Decodable {
        let result: FileResult
        struct FileResult: Decodable {
            let files: [FileEntry]
            struct FileEntry: Decodable {
                let fileId: String       // "file_id"
                let uploadUrl: String    // "upload_url"
                let headers: [String: String]?
            }
        }
    }

    // MARK: Step 1b — PUT raw bytes to presigned upload_url

    private static func uploadImage(_ image: UIImage, apiKey: String) async throws -> String {
        // Compress to JPEG; stay under 10 MB
        guard let jpeg = bestJPEG(from: image) else {
            throw APIError.uploadFailed("Could not encode image as JPEG.")
        }

        // 1a: Get upload URL + file_id
        let createEndpoint = URL(string: "\(base)/s2s/v2.0/file/skin-analysis")!
        var createReq = URLRequest(url: createEndpoint)
        createReq.httpMethod = "POST"
        createReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        createReq.httpBody = try encoder.encode(FileCreateRequest(files: [.init(fileName: "selfie.jpg")]))
        createReq.timeoutInterval = 15

        let (createData, createResponse) = try await URLSession.shared.data(for: createReq)
        let createBody = String(data: createData, encoding: .utf8) ?? "<binary>"
        print("[PerfectCorp] Step 1a status=\((createResponse as? HTTPURLResponse)?.statusCode ?? 0) body=\(createBody)")
        try checkHTTP(createResponse, data: createData)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let fileInfo = try decoder.decode(FileCreateResponse.self, from: createData)

        guard let firstFile = fileInfo.result.files.first else {
            throw APIError.uploadFailed("API returned empty files array")
        }

        // 1b: PUT raw bytes to the presigned URL
        guard let uploadURL = URL(string: firstFile.uploadUrl) else {
            throw APIError.uploadFailed("Invalid upload_url returned: \(firstFile.uploadUrl)")
        }
        var putReq = URLRequest(url: uploadURL)
        putReq.httpMethod = "PUT"
        putReq.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        putReq.setValue("\(jpeg.count)", forHTTPHeaderField: "Content-Length")
        putReq.httpBody = jpeg
        putReq.timeoutInterval = 30

        let (_, putResponse) = try await URLSession.shared.data(for: putReq)
        print("[PerfectCorp] Step 1b PUT status=\((putResponse as? HTTPURLResponse)?.statusCode ?? 0)")
        try checkHTTP(putResponse, data: Data())

        return firstFile.fileId
    }

    // MARK: Step 2 — Create analysis task

    // POST /s2s/v2.0/task/skin-analysis
    // body: { "file_id": "...", "dst_actions": ["acne", "wrinkle", ...] }
    // Response: { "status": 200, "result": { "task_id": "..." } }
    private struct TaskCreateRequest: Encodable {
        let fileId: String          // → "file_id"
        let dstActions: [String]    // → "dst_actions"
    }

    private struct TaskCreateResponse: Decodable {
        let result: TaskResult
        struct TaskResult: Decodable {
            let taskId: String   // "task_id"
        }
    }

    private static func createTask(fileID: String, apiKey: String) async throws -> String {
        let endpoint = URL(string: "\(base)/s2s/v2.0/task/skin-analysis")!
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(TaskCreateRequest(
            fileId: fileID,
            dstActions: SkinConditionType.requestedConcerns.map(\.rawValue)
        ))

        let (data, response) = try await URLSession.shared.data(for: req)
        let body = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[PerfectCorp] Step 2 status=\((response as? HTTPURLResponse)?.statusCode ?? 0) body=\(body)")
        try checkHTTP(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let parsed = try decoder.decode(TaskCreateResponse.self, from: data)
        return parsed.result.taskId
    }

    // MARK: Step 3 — Poll

    // GET /s2s/v2.0/task/skin-analysis?task_id={task_id}   ← query param
    // Response: { "status": 200, "result": {
    //     "task_id": "...", "task_status": "success"|"error"|"pending",
    //     "output": { "acne": { "score": 45, "result_image_url": "..." }, ... }
    // } }
    private struct TaskResultResponse: Decodable {
        let result: ResultData

        struct ResultData: Decodable {
            let taskStatus: String          // "task_status"
            let output: [String: ConcernOutput]?
        }

        struct ConcernOutput: Decodable {
            let score: Int?                 // 0–100 severity score
            let resultImageUrl: String?     // "result_image_url" (optional, we don't use it)
        }
    }

    private static func pollTask(taskID: String, apiKey: String) async throws -> TaskResultResponse {
        var components = URLComponents(string: "\(base)/s2s/v2.0/task/skin-analysis")!
        components.queryItems = [URLQueryItem(name: "task_id", value: taskID)]
        guard let endpoint = components.url else {
            throw APIError.parseError("Could not build poll URL")
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for attempt in 1...30 {
            let (data, response) = try await URLSession.shared.data(for: req)
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[PerfectCorp] Step 3 poll#\(attempt) status=\((response as? HTTPURLResponse)?.statusCode ?? 0) body=\(body)")
            try checkHTTP(response, data: data)

            let parsed = try decoder.decode(TaskResultResponse.self, from: data)
            switch parsed.result.taskStatus {
            case "success":
                return parsed
            case "error":
                throw APIError.taskCreationFailed("Server reported task error for task_id=\(taskID)")
            default:
                // "pending" or other intermediate status — keep polling
                try? await Task.sleep(for: .seconds(1))
            }
        }
        throw APIError.taskTimeout
    }

    // MARK: Map result → our model

    private static func mapResult(_ raw: TaskResultResponse, timestamp: Date) -> AnalysisResult {
        let output = raw.result.output ?? [:]
        var conditions: [SkinCondition] = []

        for conditionType in SkinConditionType.requestedConcerns {
            guard let out = output[conditionType.rawValue],
                  let score = out.score,
                  score > 10 else { continue }   // skip near-zero readings

            let severity = Double(score) / 100.0
            let zones = defaultZones(for: conditionType)
            let heatmap = Dictionary(
                uniqueKeysWithValues: zones.map { ($0, severity * Double.random(in: 0.8...1.0)) }
            )

            conditions.append(SkinCondition(
                type: conditionType,
                score: score,
                severity: severity,
                confidence: 0.88,
                affectedZones: zones,
                heatmapIntensity: heatmap
            ))
        }

        // Overall: 100 minus weighted severity penalty (higher score = worse condition)
        let penalty = conditions.reduce(0.0) { $0 + $1.severity * 12.0 }
        let overall = Int(min(max(100.0 - penalty, 20.0), 98.0))

        return AnalysisResult(
            timestamp: timestamp,
            overallScore: overall,
            conditions: conditions,
            source: "perfectcorp"
        )
    }

    // MARK: Helpers

    private static func defaultZones(for type: SkinConditionType) -> [FaceZone] {
        switch type {
        case .acne:         return [.forehead, .chin, .nose]
        case .wrinkle:      return [.forehead, .leftCheek, .rightCheek]
        case .pore:         return [.forehead, .nose]
        case .texture:      return [.leftCheek, .rightCheek, .forehead]
        case .pigmentation: return [.leftCheek, .rightCheek, .underEyes]
        case .hydration:    return [.leftCheek, .rightCheek]
        }
    }

    private static func bestJPEG(from image: UIImage) -> Data? {
        for quality: CGFloat in [0.85, 0.65, 0.45] {
            if let d = image.jpegData(compressionQuality: quality), d.count < 8_000_000 {
                return d
            }
        }
        return image.jpegData(compressionQuality: 0.30)
    }

    private static func checkHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw APIError.httpError(http.statusCode, body)
        }
    }

    // MARK: - Demo fallback

    private static func generateDemoResult() async -> AnalysisResult {
        try? await Task.sleep(for: .seconds(1.8))

        var conditions: [SkinCondition] = []

        func makeCondition(_ type: SkinConditionType, score: Int) -> SkinCondition {
            let severity = Double(score) / 100.0
            let zones = defaultZones(for: type)
            return SkinCondition(
                type: type,
                score: score,
                severity: severity,
                confidence: Double.random(in: 0.72...0.92),
                affectedZones: zones,
                heatmapIntensity: Dictionary(
                    uniqueKeysWithValues: zones.map { ($0, severity * Double.random(in: 0.7...1.0)) }
                )
            )
        }

        if Double.random(in: 0...1) < 0.72 {
            conditions.append(makeCondition(.acne, score: Int.random(in: 30...85)))
        }
        if Double.random(in: 0...1) < 0.55 {
            conditions.append(makeCondition(.pore, score: Int.random(in: 25...70)))
        }
        if Double.random(in: 0...1) < 0.48 {
            conditions.append(makeCondition(.texture, score: Int.random(in: 20...65)))
        }
        if Double.random(in: 0...1) < 0.40 {
            conditions.append(makeCondition(.wrinkle, score: Int.random(in: 15...55)))
        }
        if Double.random(in: 0...1) < 0.35 {
            conditions.append(makeCondition(.pigmentation, score: Int.random(in: 20...60)))
        }
        // Hydration is inverted — low score = dry skin (show if score is low)
        let hydrationScore = Int.random(in: 20...80)
        if hydrationScore < 50 {
            conditions.append(makeCondition(.hydration, score: hydrationScore))
        }

        let penalty = conditions.reduce(0.0) { $0 + $1.severity * 14.0 }
        let overall = Int(min(max(85.0 - penalty + Double.random(in: -4...4), 25), 95))
        return AnalysisResult(timestamp: Date(), overallScore: overall, conditions: conditions, source: "demo")
    }
}
