
import Foundation

// MARK: - Search

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

// MARK: - Flexible descriptions

struct OpenLibraryDescription: Decodable {
    let text: String

    enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            text = string
            return
        }

        let object = try decoder.container(
            keyedBy: CodingKeys.self
        )

        text = try object.decode(String.self, forKey: .value)
    }
}

// MARK: - Work details

struct OpenLibraryWork: Decodable {
    let description: OpenLibraryDescription?
    let subjects: [String]?
    let covers: [Int]?
}

// MARK: - Editions

struct OpenLibraryEditionsResponse: Decodable {
    let entries: [OpenLibraryEdition]
}

struct OpenLibraryEdition: Decodable, Identifiable {
    let key: String
    let title: String?
    let publishers: [String]?
    let publishDate: String?
    let isbn13: [String]?
    let isbn10: [String]?
    let covers: [Int]?
    let description: OpenLibraryDescription?

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

    enum CodingKeys: String, CodingKey {
        case key, title, publishers, covers, description
        case publishDate = "publish_date"
        case isbn13 = "isbn_13"
        case isbn10 = "isbn_10"
    }
}

// MARK: - Combined metadata

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

// MARK: - API Service

struct OpenLibraryService {

    private let baseURL = "https://openlibrary.org"

    private func fetch<T: Decodable>(
        from url: URL
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func apiURL(for key: String) throws -> URL {
        guard key.hasPrefix("/works/") ||
              key.hasPrefix("/books/"),
              !key.contains(".."),
              !key.contains("?"),
              !key.contains("#"),
              let url = URL(string: "\(baseURL)\(key).json") else {
            throw URLError(.badURL)
        }

        return url
    }

    // Search for works by title, author or ISBN

    func searchBooks(
        query: String
    ) async throws -> [OpenLibraryBook] {

        let cleanedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedQuery.isEmpty else { return [] }

        var components = URLComponents(
            string: "\(baseURL)/search.json"
        )!

        components.queryItems = [
            URLQueryItem(name: "q", value: cleanedQuery),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(
                name: "fields",
                value: "key,title,author_name,first_publish_year,cover_i,subject"
            )
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let response: OpenLibraryResponse = try await fetch(
            from: url
        )

        return response.docs
    }

    // Fetch description and subjects for a work

    func fetchWork(
        key: String
    ) async throws -> OpenLibraryWork {

        guard key.hasPrefix("/works/") else {
            throw URLError(.badURL)
        }

        return try await fetch(from: apiURL(for: key))
    }

    // Fetch available editions of a work

    func fetchEditions(
        workKey: String
    ) async throws -> [OpenLibraryEdition] {

        guard workKey.hasPrefix("/works/") else {
            throw URLError(.badURL)
        }

        let urlString = "\(baseURL)\(workKey)/editions.json?limit=30"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let response: OpenLibraryEditionsResponse =
            try await fetch(from: url)

        return response.entries
    }

    // Fetch full metadata for one particular edition

    func fetchEdition(
        key: String
    ) async throws -> OpenLibraryEdition {

        guard key.hasPrefix("/books/") else {
            throw URLError(.badURL)
        }

        return try await fetch(from: apiURL(for: key))
    }

    // Combine Work + Edition into one BookMetadata object

    func fetchMetadata(
        for searchResult: OpenLibraryBook,
        edition: OpenLibraryEdition?
    ) async -> BookMetadata {

        // Work information is optional if the request fails
        let work = try? await fetchWork(key: searchResult.key)

        // Try to fetch more complete edition information
        var selectedEdition = edition

        if let edition {
            selectedEdition = (
                try? await fetchEdition(key: edition.key)
            ) ?? edition
        }

        let description =
            selectedEdition?.description?.text ??
            work?.description?.text ??
            ""

        let subjects =
            work?.subjects ??
            searchResult.subjects ??
            []

        let themes = Array(
            subjects
                .filter { !$0.isEmpty }
                .prefix(10)
        )

        return BookMetadata(
            title: selectedEdition?.title ?? searchResult.title,
            author: searchResult.author,
            summary: description,
            themes: themes,
            publisher: selectedEdition?.publisher ?? "",
            publicationYear: selectedEdition?.publicationYear,
            firstPublishYear: searchResult.firstPublishYear,
            isbn: selectedEdition?.isbn ?? "",
            workKey: searchResult.key,
            editionKey: selectedEdition?.key,
            coverID:
                selectedEdition?.covers?.first ??
                searchResult.coverID ??
                work?.covers?.first
        )
    }
}
