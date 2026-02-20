import Foundation
import UIKit

/// PerfectCorp YouCam Skin Analysis API (V2 server-to-server).
///
/// Correct workflow (from official docs at yce.perfectcorp.com):
///
///   Step 1a. POST /s2s/v2.0/file/skin-analysis
///              body: { "file_name": "selfie.jpg", "content_type": "image/jpeg", "file_size": 12345 }
///              → result.file_id + result.upload_url + result.headers
///
///   Step 1b. PUT {upload_url}
///              Content-Type: image/jpg
///              body: raw JPEG bytes
///
///   Step 2.  POST /s2s/v2.0/task/skin-analysis
///              body: { "src_file_id": "...", "dst_actions": ["acne", ...] }
///              → result.task_id
///
///   Step 3.  GET /s2s/v2.0/task/skin-analysis/{task_id}
///              poll result.task_status until "success" | "error"
///              results in result.output.{concern}.score (0–100)
///
/// Valid SD dst_actions include: acne, wrinkle, pore, texture, age_spot, moisture
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
        case pigmentation = "age_spot"
        case hydration    = "moisture"

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
        let overlayMaskURL: String? // API mask image URL for this condition

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
        let overlayBaseImageURL: String? // optional API-resized face image URL
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
            throw APIError.uploadFailed("[Step 1] \(e.localizedDescription)")
        }

        // ── Step 2: Create analysis task ───────────────────────────────────────
        let taskID: String
        do {
            taskID = try await createTask(fileID: fileID, apiKey: apiKey)
        } catch let e as APIError {
            throw APIError.taskCreationFailed("[Step 2] \(e.localizedDescription)")
        }

        // ── Step 3: Poll for result ────────────────────────────────────────────
        let raw: TaskResultResponse
        do {
            raw = try await pollTask(taskID: taskID, apiKey: apiKey)
        } catch let e as APIError {
            throw APIError.taskCreationFailed("[Step 3] \(e.localizedDescription)")
        }

        return mapResult(raw, timestamp: Date())
    }

    // MARK: Step 1a — Create file entry → get upload_url + file_id

    // POST /s2s/v2.0/file/skin-analysis
    // body: { "files": [{ "file_name": "selfie.jpg", "content_type": "image/jpeg", "file_size": 12345 }] }
    // Response: { "status": 200, "data"|"result": { "files": [{ "file_id": "...", "upload_url": "..." | "requests":[...] }] } }
    private struct FileCreateRequest: Encodable {
        let files: [FileEntry]
        struct FileEntry: Encodable {
            let fileName: String    // → "file_name"
            let contentType: String // → "content_type"
            let fileSize: Int       // → "file_size"
        }
    }

    /// Some PerfectCorp endpoints return payload under `data`, others under `result`.
    private struct APIEnvelope<T: Decodable>: Decodable {
        let payload: T

        private enum CodingKeys: String, CodingKey {
            case data
            case result
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let data = try container.decodeIfPresent(T.self, forKey: .data) {
                payload = data
                return
            }
            if let result = try container.decodeIfPresent(T.self, forKey: .result) {
                payload = result
                return
            }
            throw DecodingError.dataCorruptedError(
                forKey: .data,
                in: container,
                debugDescription: "Expected top-level 'data' or 'result'."
            )
        }
    }

    private struct FileCreateResponse: Decodable {
        let files: [FileEntry]

        struct FileEntry: Decodable {
            let fileId: String
            let uploadUrl: String
            let headers: [String: String]?

            private enum CodingKeys: String, CodingKey {
                case fileId
                case uploadUrl
                case headers
                case requests
            }

            private struct SignedRequest: Decodable {
                let method: String?
                let url: String
                let headers: [String: String]?
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                fileId = try container.decode(String.self, forKey: .fileId)

                if let directUploadURL = try container.decodeIfPresent(String.self, forKey: .uploadUrl) {
                    uploadUrl = directUploadURL
                    headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
                    return
                }

                let requests = try container.decode([SignedRequest].self, forKey: .requests)
                guard let signedPUT = requests.first(where: { ($0.method ?? "").uppercased() == "PUT" }) ?? requests.first else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .requests,
                        in: container,
                        debugDescription: "No upload request found."
                    )
                }
                uploadUrl = signedPUT.url
                headers = signedPUT.headers
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
        createReq.httpBody = try encoder.encode(FileCreateRequest(files: [
            .init(
                fileName: "selfie.jpg",
                contentType: "image/jpeg",
                fileSize: jpeg.count
            )
        ]))
        createReq.timeoutInterval = 15

        let (createData, createResponse) = try await URLSession.shared.data(for: createReq)
        let createBody = String(data: createData, encoding: .utf8) ?? "<binary>"
        print("[PerfectCorp] Step 1a status=\((createResponse as? HTTPURLResponse)?.statusCode ?? 0) body=\(createBody)")
        try checkHTTP(createResponse, data: createData)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let fileInfo = try decoder.decode(APIEnvelope<FileCreateResponse>.self, from: createData)

        guard let firstFile = fileInfo.payload.files.first else {
            throw APIError.uploadFailed("API returned empty files array")
        }

        // 1b: PUT raw bytes to the presigned URL
        guard let uploadURL = URL(string: firstFile.uploadUrl) else {
            throw APIError.uploadFailed("Invalid upload_url returned: \(firstFile.uploadUrl)")
        }
        var putReq = URLRequest(url: uploadURL)
        putReq.httpMethod = "PUT"
        if let signedHeaders = firstFile.headers {
            for (key, value) in signedHeaders {
                putReq.setValue(value, forHTTPHeaderField: key)
            }
        }
        if putReq.value(forHTTPHeaderField: "Content-Type") == nil {
            putReq.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        }
        if putReq.value(forHTTPHeaderField: "Content-Length") == nil {
            putReq.setValue("\(jpeg.count)", forHTTPHeaderField: "Content-Length")
        }
        putReq.httpBody = jpeg
        putReq.timeoutInterval = 30

        let (_, putResponse) = try await URLSession.shared.data(for: putReq)
        print("[PerfectCorp] Step 1b PUT status=\((putResponse as? HTTPURLResponse)?.statusCode ?? 0)")
        try checkHTTP(putResponse, data: Data())

        return firstFile.fileId
    }

    // MARK: Step 2 — Create analysis task

    // POST /s2s/v2.0/task/skin-analysis
    // body: { "src_file_id": "...", "dst_actions": ["acne", "wrinkle", ...] }
    // Response: { "status": 200, "result": { "task_id": "..." } }
    private struct TaskCreateRequest: Encodable {
        let srcFileId: String       // → "src_file_id"
        let dstActions: [String]    // → "dst_actions"
        let format: String          // → "format" ("json" | "zip")
    }

    private struct TaskCreateResponse: Decodable {
        let taskId: String   // "task_id"
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
            srcFileId: fileID,
            dstActions: SkinConditionType.requestedConcerns.map(\.rawValue),
            format: "json"
        ))

        let (data, response) = try await URLSession.shared.data(for: req)
        let body = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[PerfectCorp] Step 2 status=\((response as? HTTPURLResponse)?.statusCode ?? 0) body=\(body)")
        try checkHTTP(response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let parsed = try decoder.decode(APIEnvelope<TaskCreateResponse>.self, from: data)
        return parsed.payload.taskId
    }

    // MARK: Step 3 — Poll

    // GET /s2s/v2.0/task/skin-analysis/{task_id}
    // Response (variants):
    // 1) { ..., "task_status": "...", "output": { "acne": { "score": 45, ... }, ... } }
    // 2) { ..., "task_status": "...", "results": { "output": [{ "type":"acne", "ui_score":45, ... }] } }
    private struct TaskResultResponse: Decodable {
        let taskStatus: String          // "task_status"
        let output: [String: ConcernOutput]

        struct ConcernOutput: Decodable {
            let score: Double?              // score from API (scale varies by endpoint variant)
            let uiScore: Double?            // "ui_score" (often 0–100, sometimes 0–5)
            let rawScore: Double?           // "raw_score" (can be 0–1)
            let resultImageUrl: String?     // "result_image_url" (optional, we don't use it)
            let maskImageUrls: [String]?    // "mask_urls"

            var effectiveScore: Int? {
                let candidate = uiScore ?? score ?? rawScore
                guard var value = candidate else { return nil }
                // Normalize common score scales into 0...100 for UI consistency.
                if value <= 1.0 {
                    value *= 100.0
                } else if value <= 5.0 {
                    value *= 20.0
                }
                value = min(max(value, 0.0), 100.0)
                return Int(value.rounded())
            }
        }

        private struct ResultsBlock: Decodable {
            let output: [OutputEntry]?
        }

        private struct OutputEntry: Decodable {
            let type: String
            let score: Double?
            let uiScore: Double?
            let rawScore: Double?
            let resultImageUrl: String?
            let maskUrls: [String]?
        }

        private enum CodingKeys: String, CodingKey {
            case taskStatus
            case output
            case results
        }

        init(taskStatus: String, output: [String: ConcernOutput]) {
            self.taskStatus = taskStatus
            self.output = output
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            taskStatus = try container.decode(String.self, forKey: .taskStatus)

            if let dictOutput = try container.decodeIfPresent([String: ConcernOutput].self, forKey: .output) {
                output = dictOutput
                return
            }

            if let resultsBlock = try container.decodeIfPresent(ResultsBlock.self, forKey: .results),
               let arrayOutput = resultsBlock.output {
                var normalized: [String: ConcernOutput] = [:]
                for item in arrayOutput {
                    let resolvedImage = item.resultImageUrl ?? item.maskUrls?.first
                    normalized[item.type] = ConcernOutput(
                        score: item.score,
                        uiScore: item.uiScore,
                        rawScore: item.rawScore,
                        resultImageUrl: resolvedImage,
                        maskImageUrls: item.maskUrls
                    )
                }
                output = normalized
                return
            }

            output = [:]
        }
    }

    private static func pollTask(taskID: String, apiKey: String) async throws -> TaskResultResponse {
        let encodedTaskID = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        guard let endpoint = URL(string: "\(base)/s2s/v2.0/task/skin-analysis/\(encodedTaskID)") else {
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

            let parsed = try decoder.decode(APIEnvelope<TaskResultResponse>.self, from: data)
            var taskResult = parsed.payload
            if taskResult.output.isEmpty {
                let fallbackOutput = extractConcernOutputs(from: data)
                if !fallbackOutput.isEmpty {
                    taskResult = TaskResultResponse(taskStatus: taskResult.taskStatus, output: fallbackOutput)
                }
            }

            switch taskResult.taskStatus {
            case "success":
                return taskResult
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
        let output = normalizeOutputKeys(raw.output)
        let overallFromAPI = output["all"]?.effectiveScore
        let overlayBaseImageURL = output["resize_image"]?.maskImageUrls?.first ?? output["resize_image"]?.resultImageUrl
        var conditions: [SkinCondition] = []

        for conditionType in SkinConditionType.requestedConcerns {
            guard let out = output[conditionType.rawValue],
                  let healthScore = out.effectiveScore else { continue }

            // PerfectCorp concern scores are quality-style in practice (higher is better).
            // Convert to issue severity for VITA UI where higher means worse condition.
            let issueScore = max(0, min(100, 100 - healthScore))
            if issueScore < 20 { continue } // hide negligible findings

            let severity = Double(issueScore) / 100.0
            let visualSeverity = max(severity, 0.22) // keep low but present concerns visible on heatmap
            let zones = defaultZones(for: conditionType)
            let heatmap = Dictionary(
                uniqueKeysWithValues: zones.map { ($0, min(1.0, visualSeverity * Double.random(in: 0.85...1.0))) }
            )

            conditions.append(SkinCondition(
                type: conditionType,
                score: issueScore,
                severity: severity,
                confidence: 0.88,
                affectedZones: zones,
                heatmapIntensity: heatmap,
                overlayMaskURL: out.maskImageUrls?.first ?? out.resultImageUrl
            ))
        }

        let overall: Int
        if let apiOverall = overallFromAPI {
            overall = min(max(apiOverall, 0), 100)
        } else {
            // Fallback when API doesn't provide aggregate score.
            let penalty = conditions.reduce(0.0) { $0 + $1.severity * 12.0 }
            overall = Int(min(max(100.0 - penalty, 20.0), 98.0))
        }

        return AnalysisResult(
            timestamp: timestamp,
            overallScore: overall,
            conditions: conditions,
            overlayBaseImageURL: overlayBaseImageURL,
            source: "perfectcorp"
        )
    }

    private static func normalizeOutputKeys(_ output: [String: TaskResultResponse.ConcernOutput]) -> [String: TaskResultResponse.ConcernOutput] {
        var normalized: [String: TaskResultResponse.ConcernOutput] = [:]
        for (rawKey, value) in output {
            let key = canonicalConcernKey(rawKey)
            if normalized[key] == nil {
                normalized[key] = value
            }
        }
        return normalized
    }

    private static func extractConcernOutputs(from data: Data) -> [String: TaskResultResponse.ConcernOutput] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        guard let payload = (json["data"] as? [String: Any]) ?? (json["result"] as? [String: Any]) else {
            return [:]
        }

        var extracted: [String: TaskResultResponse.ConcernOutput] = [:]

        // Variant 1: payload.output = { concern_key: { score/ui_score/raw_score... } }
        if let outputDict = payload["output"] as? [String: Any] {
            for (key, rawValue) in outputDict {
                if let concern = concernOutput(from: rawValue) {
                    extracted[key] = concern
                }
            }
        }

        // Variant 2: payload.results.output = [{ type, ui_score/raw_score/... }]
        if let results = payload["results"] as? [String: Any],
           let outputArray = results["output"] as? [[String: Any]] {
            for item in outputArray {
                guard let type = item["type"] as? String else { continue }
                let uiScore = anyDouble(item["ui_score"])
                let rawScore = anyDouble(item["raw_score"])
                let score = anyDouble(item["score"])
                let resultImageUrl = item["result_image_url"] as? String
                extracted[type] = TaskResultResponse.ConcernOutput(
                    score: score,
                    uiScore: uiScore,
                    rawScore: rawScore,
                    resultImageUrl: resultImageUrl,
                    maskImageUrls: item["mask_urls"] as? [String]
                )
            }
        }

        // Variant 3: payload.results.score_info or payload.score_info
        if let results = payload["results"] as? [String: Any],
           let scoreInfo = results["score_info"] as? [String: Any] {
            mergeScoreInfo(scoreInfo, into: &extracted)
        }
        if let scoreInfo = payload["score_info"] as? [String: Any] {
            mergeScoreInfo(scoreInfo, into: &extracted)
        }

        return extracted
    }

    private static func mergeScoreInfo(
        _ scoreInfo: [String: Any],
        into extracted: inout [String: TaskResultResponse.ConcernOutput]
    ) {
        for (key, value) in scoreInfo {
            guard SkinConditionType.requestedConcerns.map(\.rawValue).contains(canonicalConcernKey(key)) else { continue }
            guard let concern = concernOutput(from: value) else { continue }
            extracted[key] = concern
        }
    }

    private static func concernOutput(from value: Any) -> TaskResultResponse.ConcernOutput? {
        guard let dict = value as? [String: Any] else { return nil }
        return TaskResultResponse.ConcernOutput(
            score: anyDouble(dict["score"]),
            uiScore: anyDouble(dict["ui_score"]),
            rawScore: anyDouble(dict["raw_score"]),
            resultImageUrl: dict["result_image_url"] as? String,
            maskImageUrls: dict["mask_urls"] as? [String]
        )
    }

    private static func anyDouble(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    private static func canonicalConcernKey(_ key: String) -> String {
        var normalized = key.lowercased()
        if normalized.hasPrefix("hd_") {
            normalized.removeFirst(3)
        }
        switch normalized {
        case "pigmentation": return "age_spot"
        case "hydration": return "moisture"
        default: return normalized
        }
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
                ),
                overlayMaskURL: nil
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
        return AnalysisResult(
            timestamp: Date(),
            overallScore: overall,
            conditions: conditions,
            overlayBaseImageURL: nil,
            source: "demo"
        )
    }
}
