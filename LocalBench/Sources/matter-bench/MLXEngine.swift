import Foundation
import FoundationModels
import HuggingFace
import MLXFoundationModels
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

/// An open model run on the Mac's graphics chip with MLX, behind Apple's own session: the same
/// answer shape as Apple's model, held to it the same way while it is written.
@available(macOS 27.0, *)
struct MLXEngine: LocalEngine {
    let name: String
    let model: MLXLanguageModel

    init() {
        name = "Qwen 3 8B (MLX, 4-bit)"
        model = #huggingFaceLanguageModel(configuration: LLMRegistry.qwen3_8b_4bit, capabilities: [.guidedGeneration])
    }

    func read(instructions: String, prompt: String) async throws -> LocalAnswer {
        // Qwen 3 thinks aloud first unless told not to; the answer is what is wanted here.
        let session = LanguageModelSession(model: model, instructions: instructions + " /no_think")
        let answer = try await session.respond(to: prompt, generating: AppleEngine.Answer.self, options: GenerationOptions(sampling: .greedy)).content
        return AppleEngine.convert(answer)
    }
}
