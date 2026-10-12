
import Foundation

// MARK: - Search Models

struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryBook]
}

struct OpenLibraryBook: Decodable, Identifiable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverID: Int?
    let subjects: [String]?

    var id: String { key }

    var author: String {
        authorName?.joined(separator: ", ") ?? "Unknown author"
    }

    var coverURL: URL? {
        guard let coverID else { return nil }
        return URL(
            string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        )
    }

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case subjects = "subject"
    }
}

// MARK: - Flexible Description

struct OpenLibraryDescription: Decodable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            text = value
            return
        }

        let object = try decoder.container(
            keyedBy: CodingKeys.self
        )

        text = try object.decode(String.self, forKey: .value)
    }
}

// MARK: - Common References

struct OpenLibraryReference: Decodable {
    let key: String
}

struct OpenLibraryWorkAuthor: Decodable {
    let author: OpenLibraryReference
}

struct OpenLibraryAuthor: Decodable {
    let name: String
}

// MARK: - Work

struct OpenLibraryWork: Decodable {
    let title: String?
    let description: OpenLibraryDescription?
    let subjects: [String]?
    let covers: [Int]?
    let authors: [OpenLibraryWorkAuthor]?
    let firstPublishDate: String?

    enum CodingKeys: String, CodingKey {
        case title, description, subjects, covers, authors
        case firstPublishDate = "first_publish_date"
    }
}

// MARK: - Edition

struct OpenLibraryEdition: Decodable, Identifiable {
    let key: String
    let title: String?
    let publishers: [String]?
    let publishDate: String?
    let isbn13: [String]?
    let isbn10: [String]?
    let covers: [Int]?
    let description: OpenLibraryDescription?
    let languages: [OpenLibraryReference]?
    let works: [OpenLibraryReference]?

    var id: String { key }

    var publisher: String {
        publishers?.joined(separator: ", ") ?? ""
    }

    var isbn: String {
        isbn13?.first ?? isbn10?.first ?? ""
    }

    var publicationYear: Int? {
        guard let publishDate else { return nil }

        let pattern = #"\b(?:1[5-9]\d{2}|20\d{2}|21\d{2})\b"#

        guard let range = publishDate.range(
            of: pattern,
            options: .regularExpression
        ) else {
            return nil
        }

        return Int(publishDate[range])
    }

    var languageCodes: [String] {
        languages?.compactMap {
            $0.key.split(separator: "/").last.map(String.init)
        } ?? []
    }

    var languageDisplay: String {
        let names: [String: String] = [
            "eng": "English",
            "nor": "Norwegian",
            "nob": "Norwegian Bokmål",
            "nno": "Norwegian Nynorsk",
            "fre": "French",
            "fra": "French",
            "ger": "German",
            "deu": "German",
            "spa": "Spanish",
            "swe": "Swedish",
            "dan": "Danish"
        ]

        let result = languageCodes.map {
            names[$0] ?? $0.uppercased()
        }

        return result.isEmpty
            ? "Unknown language"
            : result.joined(separator: ", ")
    }

    var coverURL: URL? {
        guard let coverID = covers?.first else { return nil }

        return URL(
            string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        )
    }

    enum CodingKeys: String, CodingKey {
        case key, title, publishers, covers
        case description, languages, works
        case publishDate = "publish_date"
        case isbn13 = "isbn_13"
        case isbn10 = "isbn_10"
    }
}

// MARK: - Paginated Edition Response

struct OpenLibraryEditionsResponse: Decodable {
    let size: Int
    let entries: [OpenLibraryEdition]
}

struct EditionPage {
    let editions: [OpenLibraryEdition]
    let totalCount: Int
}

// MARK: - Combined Metadata

struct BookMetadata {
    let title: String
    let author: String
    let summary: String
    let themes: [String]
    let publisher: String
    let publicationYear: Int?
    let firstPublishYear: Int?
    let isbn: String
    let workKey: String
    let editionKey: String?
    let coverID: Int?
}

// MARK: - Errors

enum OpenLibraryError: LocalizedError {
    case invalidISBN
    case bookNotFound
    case missingWork
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidISBN:
            return "Enter a valid ISBN-10 or ISBN-13."
        case .bookNotFound:
            return "No edition was found for this ISBN."
        case .missingWork:
            return "This edition has no linked work in Open Library."
        case .invalidURL:
            return "The request URL is invalid."
        case .serverError(let status):
            return "Open Library returned HTTP \(status)."
        }
    }
}

// MARK: - Service

struct OpenLibraryService {
    private let baseURL = "https://openlibrary.org"

    private func fetch<T: Decodable>(
        from url: URL
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Bookmarked/0.1 (personal iOS book library)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 404 {
            throw OpenLibraryError.bookNotFound
        }

        guard (200...299).contains(http.statusCode) else {
            throw OpenLibraryError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func resourceURL(
        key: String,
        prefix: String
    ) throws -> URL {
        let identifier = String(key.dropFirst(prefix.count))

        guard key.hasPrefix(prefix),
              !identifier.isEmpty,
              identifier.range(
                of: #"^[A-Za-z0-9]+$"#,
                options: .regularExpression
              ) != nil,
              let url = URL(string: "\(baseURL)\(key).json") else {
            throw OpenLibraryError.invalidURL
        }

        return url
    }

    // MARK: Search

    func searchBooks(
        query: String
    ) async throws -> [OpenLibraryBook] {
        let cleaned = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else { return [] }

        var components = URLComponents(
            string: "\(baseURL)/search.json"
        )!

        components.queryItems = [
            URLQueryItem(name: "q", value: cleaned),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(
                name: "fields",
                value: "key,title,author_name,first_publish_year,cover_i,subject"
            )
        ]

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        let response: OpenLibraryResponse =
            try await fetch(from: url)

        return response.docs
    }

    // MARK: Work

    func fetchWork(
        key: String
    ) async throws -> OpenLibraryWork {
        try await fetch(
            from: resourceURL(key: key, prefix: "/works/")
        )
    }

    private func fetchAuthor(
        key: String
    ) async throws -> OpenLibraryAuthor {
        try await fetch(
            from: resourceURL(key: key, prefix: "/authors/")
        )
    }

    // MARK: Editions with Pagination

    func fetchEditions(
        workKey: String,
        offset: Int = 0,
        limit: Int = 25
    ) async throws -> EditionPage {
        guard workKey.hasPrefix("/works/") else {
            throw OpenLibraryError.invalidURL
        }

        let base = try resourceURL(
            key: workKey,
            prefix: "/works/"
        )

        var components = URLComponents(
            url: base,
            resolvingAgainstBaseURL: false
        )!

        // /works/{id}/editions.json
        components.path = base.path.replacingOccurrences(
            of: ".json",
            with: "/editions.json"
        )

        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        let response: OpenLibraryEditionsResponse =
            try await fetch(from: url)

        return EditionPage(
            editions: response.entries,
            totalCount: response.size
        )
    }

    func fetchEdition(
        key: String
    ) async throws -> OpenLibraryEdition {
        try await fetch(
            from: resourceURL(key: key, prefix: "/books/")
        )
    }

    // MARK: ISBN Lookup

    static func normalizeISBN(_ input: String) -> String {
        input.uppercased().filter {
            $0.isNumber || $0 == "X"
        }
    }

    static func isValidISBN(_ input: String) -> Bool {
        let isbn = normalizeISBN(input)
        let characters = Array(isbn)

        if characters.count == 10 {
            var sum = 0

            for (index, character) in characters.enumerated() {
                let value: Int

                if index == 9 && character == "X" {
                    value = 10
                } else if let digit = character.wholeNumberValue {
                    value = digit
                } else {
                    return false
                }

                sum += (10 - index) * value
            }

            return sum % 11 == 0
        }

        if characters.count == 13 {
            guard characters.allSatisfy({
                $0.wholeNumberValue != nil
            }) else {
                return false
            }

            let sum = characters.enumerated().reduce(0) {
                result, item in
                let digit = item.element.wholeNumberValue!
                return result + digit * (item.offset.isMultiple(of: 2) ? 1 : 3)
            }

            return sum % 10 == 0
        }

        return false
    }

    func lookupISBN(
        _ input: String
    ) async throws -> BookMetadata {
        let isbn = Self.normalizeISBN(input)

        guard Self.isValidISBN(isbn) else {
            throw OpenLibraryError.invalidISBN
        }

        guard let url = URL(
            string: "\(baseURL)/isbn/\(isbn).json"
        ) else {
            throw OpenLibraryError.invalidURL
        }

        let edition: OpenLibraryEdition =
            try await fetch(from: url)

        guard let workKey = edition.works?.first?.key else {
            throw OpenLibraryError.missingWork
        }

        let work = try? await fetchWork(key: workKey)

        let authorNames: [String]

        if let references = work?.authors {
            var names: [String] = []

            for reference in references.prefix(5) {
                if let author = try? await fetchAuthor(
                    key: reference.author.key
                ) {
                    names.append(author.name)
                }
            }

            authorNames = names
        } else {
            authorNames = []
        }

        return BookMetadata(
            title: edition.title ?? work?.title ?? "Untitled",
            author: authorNames.isEmpty
                ? "Unknown author"
                : authorNames.joined(separator: ", "),
            summary: edition.description?.text ??
                work?.description?.text ?? "",
            themes: Array((work?.subjects ?? []).prefix(10)),
            publisher: edition.publisher,
            publicationYear: edition.publicationYear,
            firstPublishYear: yearFrom(
                work?.firstPublishDate
            ),
            isbn: edition.isbn.isEmpty ? isbn : edition.isbn,
            workKey: workKey,
            editionKey: edition.key,
            coverID: edition.covers?.first ??
                work?.covers?.first
        )
    }

    // MARK: Combine Work and Edition

    func fetchMetadata(
        for searchResult: OpenLibraryBook,
        edition: OpenLibraryEdition?
    ) async -> BookMetadata {
        let work = try? await fetchWork(
            key: searchResult.key
        )

        var selectedEdition = edition

        if let edition {
            selectedEdition = (
                try? await fetchEdition(key: edition.key)
            ) ?? edition
        }

        return BookMetadata(
            title: selectedEdition?.title ?? searchResult.title,
            author: searchResult.author,
            summary: selectedEdition?.description?.text ??
                work?.description?.text ?? "",
            themes: Array(
                (work?.subjects ?? searchResult.subjects ?? [])
                    .prefix(10)
            ),
            publisher: selectedEdition?.publisher ?? "",
            publicationYear: selectedEdition?.publicationYear,
            firstPublishYear: searchResult.firstPublishYear,
            isbn: selectedEdition?.isbn ?? "",
            workKey: searchResult.key,
            editionKey: selectedEdition?.key,
            coverID: selectedEdition?.covers?.first ??
                searchResult.coverID ??
                work?.covers?.first
        )
    }

    private func yearFrom(_ text: String?) -> Int? {
        guard let text else { return nil }

        let pattern = #"\b(?:1[5-9]\d{2}|20\d{2}|21\d{2})\b"#

        guard let range = text.range(
            of: pattern,
            options: .regularExpression
        ) else {
            return nil
        }

        return Int(text[range])
    }
}
