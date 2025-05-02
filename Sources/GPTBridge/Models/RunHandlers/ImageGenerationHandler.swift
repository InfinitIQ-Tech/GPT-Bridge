import Foundation

/// Handles image generation via OpenAI's /v1/images/generations endpoint
public class ImageGenerationHandler {
    enum Error: Swift.Error {
        case badResponse
        case noImageData
    }

    public enum ImageQuality: String {
        case low
        case medium
        case high
    }

    public enum ImageSize: String {
        case square = "1024x1024"
        case landsacape = "1536x1024"
        case portrait = "1024x1536"
        case auto
    }

    public enum ImageModel: String {
        case gptImage = "gpt-image-1"
        case dalle2 = "dall-e-2"
        case dalle3 = "dall-e-3"
    }

    struct GenerationRequest: Codable {
        let prompt: String
        let quality: String?
        let size: String?
        let background: String?
        let model: String?
        let n: Int?
    }

    /// Generates an image and returns the PNG file URL
    /// - Parameters:
    ///   - prompt: The prompt for the image
    ///   - quality: The quality of the image (default: "high")
    ///   - size: The size of the image (default: "1024x1024")
    ///   - background: The background color (default: "white")
    /// - Returns: The URL to the saved PNG file
    static func generateImage(prompt: String, quality: ImageQuality = .high, size: ImageSize = .auto, background: String = "transparent", model: ImageModel = .gptImage, numberOfImages n: Int = 1) async throws -> URL {
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(GPTSecretsConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        let payload = GenerationRequest(
            prompt: prompt,
            quality: quality.rawValue,
            size: size.rawValue,
            background: background,
            model: model.rawValue,
            n: n
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse,
              httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            throw Error.badResponse
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let b64String = dataArray.first?["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw Error.noImageData
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("generated_image_\(UUID().uuidString).png")
        try imageData.write(to: outputURL)
        return outputURL
    }
}
