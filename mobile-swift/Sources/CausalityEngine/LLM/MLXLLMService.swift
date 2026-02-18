import Foundation
#if canImport(MLXLLM) && canImport(Metal)
import MLXLLM
import MLXLMCommon

/// On-device LLM inference using MLX Swift with Metal acceleration.
/// Loads Llama 3.2 1B Instruct (4-bit, ~700 MB) on first use, caches to Documents/models/.
public actor MLXLLMService: LocalLLMService {
    private static let modelID = "mlx-community/Llama-3.2-1B-Instruct-4bit"
    private static let defaultTemperature: Float = 0.3

    private var container: ModelContainer?
    private var _isReady = false

    public nonisolated var isReady: Bool {
        // Conservative: callers should call loadModel() first
        false
    }

    public init() {}

    public func loadModel() async throws {
        guard container == nil else { return }

        let config = ModelConfiguration(id: Self.modelID) {
            prompt in prompt // Identity transform — chat template handled by PromptTemplates
        }

        let modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { progress in
            #if DEBUG
            print("[MLXLLMService] Download progress: \(Int(progress.fractionCompleted * 100))%")
            #endif
        }

        self.container = modelContainer
        self._isReady = true
    }

    public func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard let container else {
            throw LLMError.modelNotLoaded
        }

        var output = ""

        let parameters = GenerateParameters(
            maxTokens: maxTokens,
            temperature: Self.defaultTemperature
        )

        // Prepare UserInput → LMInput, then stream generation
        let userInput = UserInput(prompt: prompt)
        let lmInput = try await container.prepare(input: userInput)
        let stream = try await container.generate(
            input: lmInput,
            parameters: parameters
        )

        for await generation in stream {
            if let chunk = generation.chunk {
                output += chunk
            }
        }

        return output
    }
}

#endif
