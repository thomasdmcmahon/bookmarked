import Foundation
import SwiftData

@Model
final class Book {
    var title: String
    var author: String
    var genre: String
    var summary: String
    var publisher: String
    var publicationYear: Int?
    var isbn: String
    var personalNote: String
    var dateAdded: Date
    
    // Open Library metadata
    var openLibraryKey: String?
    var coverID: Int?
    var editionKey: String?
    var firstPublishYear: Int?
    var themes: [String] = []
    
    init(
        title: String,
        author: String,
        genre: String = "",
        summary: String = "",
        publisher: String = "",
        publicationYear: Int? = nil,
        isbn: String = "",
        personalNote: String = "",
        openLibraryKey: String? = nil,
        coverID: Int? = nil,
        editionKey: String? = nil,
        firstPublishYear: Int? = nil,
        themes: [String] = []
    ) {
        self.title = title
        self.author = author
        self.genre = genre
        self.summary = summary
        self.publisher = publisher
        self.publicationYear = publicationYear
        self.isbn = isbn
        self.personalNote = personalNote
        self.dateAdded = Date()
        
        self.openLibraryKey = openLibraryKey
        self.coverID = coverID
        self.editionKey = editionKey
        self.firstPublishYear = firstPublishYear
        self.themes = themes
    }
    
    var coverURL: URL? {
        guard let coverID else { return nil }
        
        return URL(
            string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        )
    }
}
