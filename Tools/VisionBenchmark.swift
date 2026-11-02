import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import Darwin

@main
struct VisionBenchmark {
    struct Sample: Codable {
        let id: String
        let image: String
        let expected: String
        let acceptedNames: [String]
        let crop: [Double]
        let sourceURL: String
    }

    struct Result: Codable {
        let id: String
        let expected: String
        let acceptedNames: [String]
        let candidates: [RecognitionCandidate]
        let matched: Bool
        let milliseconds: Double
        let error: String?
    }

    struct Report: Codable {
        let date: Date
        let operatingSystem: String
        let visionRevision: Int
        let manifestSHA256: String
        let requiredMatches: Int
        let matches: Int
        let total: Int
        let passed: Bool
        let results: [Result]
    }

    enum BenchmarkError: Error {
        case invalidArguments, invalidSampleCount, cannotReadImage(String)
    }

    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 4 else {
            print("Usage: vision-benchmark manifest.json image-root results.json")
            throw BenchmarkError.invalidArguments
        }
        let manifestData = try Data(contentsOf: URL(fileURLWithPath: args[1]))
        let samples = try JSONDecoder().decode([Sample].self, from: manifestData)
        guard samples.count == 30, Set(samples.map(\.image)).count == 30 else {
            throw BenchmarkError.invalidSampleCount
        }
        let service = RecognitionService()
        var results: [Result] = []
        for sample in samples {
            let start = ContinuousClock.now
            do {
                let url = URL(fileURLWithPath: args[2]).appendingPathComponent(sample.image)
                let data = try croppedImage(at: url, crop: sample.crop)
                let candidates = try await service.recognize(imageData: data)
                let accepted = Set(sample.acceptedNames.map(RecognitionCandidate.normalizedName))
                let matched = candidates.contains { accepted.contains($0.englishName) }
                let elapsed = start.duration(to: .now)
                let ms = Double(elapsed.components.seconds) * 1000
                    + Double(elapsed.components.attoseconds) / 1e15
                results.append(Result(id: sample.id, expected: sample.expected,
                                      acceptedNames: sample.acceptedNames, candidates: candidates,
                                      matched: matched, milliseconds: ms, error: nil))
                print("\(matched ? "PASS" : "MISS") \(sample.id) \(sample.expected): \(candidates.map(\.englishName).joined(separator: ", "))")
            } catch {
                results.append(Result(id: sample.id, expected: sample.expected,
                                      acceptedNames: sample.acceptedNames, candidates: [],
                                      matched: false, milliseconds: 0, error: String(describing: error)))
                print("ERROR \(sample.id): \(error)")
            }
        }
        let matches = results.filter(\.matched).count
        let report = Report(date: Date(), operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                            visionRevision: RecognitionService.revision,
                            manifestSHA256: SHA256.hash(data: manifestData).map { String(format: "%02x", $0) }.joined(),
                            requiredMatches: 24, matches: matches, total: samples.count,
                            passed: matches >= 24, results: results)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: URL(fileURLWithPath: args[3]), options: .atomic)
        print("Gate: \(matches)/\(samples.count), required 24/30 — \(report.passed ? "PASS" : "FAIL")")
        if !report.passed { exit(1) }
    }

    static func croppedImage(at url: URL, crop: [Double]) throws -> Data {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil), crop.count == 4 else {
            throw BenchmarkError.cannotReadImage(url.lastPathComponent)
        }
        let rect = CGRect(x: crop[0] * Double(image.width), y: crop[1] * Double(image.height),
                          width: crop[2] * Double(image.width), height: crop[3] * Double(image.height)).integral
        guard let cropped = image.cropping(to: rect) else {
            throw BenchmarkError.cannotReadImage(url.lastPathComponent)
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw BenchmarkError.cannotReadImage(url.lastPathComponent)
        }
        CGImageDestinationAddImage(destination, cropped, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw BenchmarkError.cannotReadImage(url.lastPathComponent)
        }
        return data as Data
    }
}
