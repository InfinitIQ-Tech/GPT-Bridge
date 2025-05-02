import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

/// Handles image generation via OpenAI's /v1/images/generations endpoint
public class ImageGenerationHandler {
    public enum Error: Swift.Error {
        case badResponse
        case noImageData
    }

    struct GenerationRequest: Codable {
        let prompt: String
        let quality: String?
        let size: String?
        let background: String?
        let model: String?
        let n: Int?
    }

    /// The URL of the generated image (if available)
    public private(set) var imageURL: URL?
    /// The prompt used for generation
    public let prompt: String
    /// The model used
    public let model: ImageModel
    /// The quality requested
    public let quality: ImageQuality
    /// The size requested
    public let size: ImageSize
    /// The background requested
    public let background: String?

    private init(imageURL: URL?, prompt: String, model: ImageModel, quality: ImageQuality, size: ImageSize, background: String?) {
        self.imageURL = imageURL
        self.prompt = prompt
        self.model = model
        self.quality = quality
        self.size = size
        self.background = background
    }

    /// Generates an image and returns an ImageGenerationHandler instance
    /// - Parameters:
    ///   - prompt: The prompt for the image
    ///   - quality: The quality of the image (default: .high)
    ///   - size: The size of the image (default: .square)
    ///   - background: The background color (default: "white")
    ///   - model: The image model (default: .dalle3)
    ///   - n: Number of images (default: 1)
    /// - Returns: An ImageGenerationHandler instance with the image URL
    @discardableResult
    public static func generateImage(prompt: String, quality: ImageQuality = .high, size: ImageSize = .square, background: String? = "white", model: ImageModel = .dalle3, n: Int = 1) async throws -> ImageGenerationHandler {
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
            print("bad response when generating image: \(String(data: data, encoding: .utf8) ?? "no data")" )
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
        return ImageGenerationHandler(imageURL: outputURL, prompt: prompt, model: model, quality: quality, size: size, background: background)
    }

    /// Download the image data from the generated image URL
    /// - Parameter stream: If true, stream the image data (default: true). If false, download all at once.
    /// - Returns: The image data
    public func downloadImageData(stream: Bool = true) async throws -> Data {
        guard let imageURL = self.imageURL else {
            throw Error.noImageData
        }
        var data = Data()
        if stream {
            let (inputStream, _) = try await URLSession.shared.bytes(for: URLRequest(url: imageURL))
            for try await chunk in inputStream {
                data.append(chunk)
            }
        } else {
            data = try Data(contentsOf: imageURL)
        }
        return data
    }
    /// Convert image data to a SwiftUI.Image
    /// - Parameter data: The image data to convert
    /// - Returns: A SwiftUI.Image if conversion succeeds, else nil
    public func image(from data: Data) -> Image? {
        Image(data: data)
    }
}

extension Image {
    /// Initializes a SwiftUI `Image` from data.
    init?(data: Data) {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            self.init(uiImage: uiImage)
        } else {
            return nil
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }
}
