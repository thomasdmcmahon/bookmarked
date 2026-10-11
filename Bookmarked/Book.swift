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
        coverID: Int? = nil
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
    }
    
    var coverURL: URL? {
        guard let coverID else { return nil }
        
        return URL(
            string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
        )
    }
}
