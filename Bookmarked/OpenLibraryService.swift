import Foundation

// MARK: – API Response

struct OpenLibraryResponse: Decodable {
    let docs: [OpenLibraryBook]
}

// MARK: – Book Search Result

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
        case key
        case title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_i"
        case subjects = "subject"
    }
}

// MARK: – Open Library Service

struct OpenLibraryService {
    
    func searchBooks(query: String) async throws -> [OpenLibraryBook] {
        let cleanedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !cleanedQuery.isEmpty else {
            return []
        }
        
        var components = URLComponents(
            string: "https://openlibrary.org/search.json"
        )!
        
        components.queryItems = [
            URLQueryItem(name: "q", value:cleanedQuery),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(
                name: "fields",
                value: "key,title,author_name,first_publish_year,cover_i,subject"
            )
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decodedResponse = try JSONDecoder().decode(
            OpenLibraryResponse.self,
            from: data
        )
        
        return decodedResponse.docs
    }
}
