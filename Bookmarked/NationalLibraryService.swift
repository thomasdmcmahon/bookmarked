
import Foundation

enum NationalLibraryError: LocalizedError {
    case bookNotFound
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            return "ISBN not found in the National Library."
        case .invalidResponse:
            return "Unable to read National Library data."
        case .serverError(let code):
            return "National Library returned HTTP \(code)."
        }
    }
}

struct NationalLibraryService {

    private let baseURL =
        "https://api.nb.no/catalog/v1/items"

    // MARK: - ISBN Lookup

    func lookupISBN(
        _ isbn: String
    ) async throws -> BookMetadata {

        let normalizedISBN =
            OpenLibraryService.normalizeISBN(isbn)

        guard OpenLibraryService.isValidISBN(normalizedISBN) else {
            throw OpenLibraryError.invalidISBN
        }

        var components = URLComponents(
            string: baseURL
        )!

        components.queryItems = [
            URLQueryItem(
                name: "q",
                value: "isbn:\(normalizedISBN)"
            ),
            URLQueryItem(
                name: "filter",
                value: "mediatype:bøker"
            ),
            URLQueryItem(
                name: "size",
                value: "10"
            )
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse else {
            throw NationalLibraryError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw NationalLibraryError.serverError(
                http.statusCode
            )
        }

        let json = try JSONSerialization.jsonObject(
            with: data
        )

        guard
            let root = json as? [String: Any],
            let embedded = root["_embedded"] as? [String: Any],
            let items = embedded["items"] as? [[String: Any]]
        else {
            throw NationalLibraryError.invalidResponse
        }

        // Never accept a fuzzy or unrelated catalog result.
        for item in items {
            guard let metadata =
                item["metadata"] as? [String: Any]
            else {
                continue
            }

            guard matchesISBN(
                metadata,
                expected: normalizedISBN
            ) else {
                continue
            }

            return makeBookMetadata(
                from: metadata,
                isbn: normalizedISBN
            )
        }

        throw NationalLibraryError.bookNotFound
    }

    // MARK: - ISBN Verification

    private func matchesISBN(
        _ metadata: [String: Any],
        expected: String
    ) -> Bool {

        var candidates: [String] = []

        if let identifiers =
            metadata["identifiers"] as? [String: Any] {

            for (key, value) in identifiers {
                if key.lowercased().contains("isbn") {
                    candidates += strings(from: value)
                }
            }
        }

        for (key, value) in metadata {
            if key.lowercased().contains("isbn") {
                candidates += strings(from: value)
            }
        }

        return candidates.contains {
            OpenLibraryService.normalizeISBN($0)
                == expected
        }
    }

    // MARK: - Metadata Conversion

    private func makeBookMetadata(
        from metadata: [String: Any],
        isbn: String
    ) -> BookMetadata {

        let origin =
            metadata["originInfo"] as? [String: Any] ?? [:]

        let title =
            string(from: metadata["title"]) ??
            "Untitled"

        let creators = strings(
            from: metadata["creators"]
        )

        let publisher =
            string(from: origin["publisher"]) ?? ""

        let issued =
            string(from: origin["issued"])

        let subjects = extractSubjects(
            from: metadata
        )

        return BookMetadata(
            title: title,
            author: creators.isEmpty
                ? "Unknown author"
                : creators.joined(separator: ", "),
            summary: "",
            themes: Array(subjects.prefix(10)),
            publisher: publisher,
            publicationYear: extractYear(issued),
            firstPublishYear: nil,
            isbn: isbn,
            workKey: "",
            editionKey: nil,
            coverID: nil
        )
    }

    // MARK: - Helpers

    private func string(from value: Any?) -> String? {
        guard let value else { return nil }

        if let text = value as? String {
            return text
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    private func strings(from value: Any?) -> [String] {
        guard let value else { return [] }

        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap { strings(from: $0) }
        }

        return []
    }

    private func extractYear(_ value: String?) -> Int? {
        guard let value else { return nil }

        let pattern = #"\b(?:1[5-9]\d{2}|20\d{2}|21\d{2})\b"#

        guard let range = value.range(
            of: pattern,
            options: .regularExpression
        ) else {
            return nil
        }

        return Int(value[range])
    }

    private func extractSubjects(
        from metadata: [String: Any]
    ) -> [String] {

        let possibleKeys = [
            "subjects",
            "subject",
            "subjectTerms"
        ]

        var subjects: [String] = []

        for key in possibleKeys {
            subjects += strings(from: metadata[key])
        }

        return Array(Set(subjects)).sorted()
    }
}
