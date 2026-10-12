
import Foundation

enum BookMetadataSource {
    case openLibrary
    case nationalLibrary

    var displayName: String {
        switch self {
        case .openLibrary:
            return "Open Library"
        case .nationalLibrary:
            return "Nasjonalbiblioteket"
        }
    }
}

struct BookLookupResult {
    let metadata: BookMetadata
    let source: BookMetadataSource
}

enum BookLookupError: LocalizedError {
    case bookNotFound
    case fallbackUnavailable

    var errorDescription: String? {
        switch self {
        case .bookNotFound:
            return """
            This ISBN was not found in either catalog.
            You can enter the book details manually.
            """
        case .fallbackUnavailable:
            return """
            Open Library did not find the book, and the
            National Library could not be reached.
            You can enter the details manually.
            """
        }
    }
}

struct BookLookupService {

    private let openLibrary = OpenLibraryService()
    private let nationalLibrary = NationalLibraryService()

    func lookupISBN(
        _ input: String
    ) async throws -> BookLookupResult {

        let isbn = OpenLibraryService.normalizeISBN(
            input
        )

        guard OpenLibraryService.isValidISBN(isbn) else {
            throw OpenLibraryError.invalidISBN
        }

        // 1. Try Open Library first.
        do {
            let metadata = try await openLibrary.lookupISBN(
                isbn
            )

            return BookLookupResult(
                metadata: metadata,
                source: .openLibrary
            )

        } catch OpenLibraryError.bookNotFound {
            // Continue to the National Library.
        }

        // 2. Try Nasjonalbiblioteket.
        do {
            let metadata = try await nationalLibrary.lookupISBN(
                isbn
            )

            return BookLookupResult(
                metadata: metadata,
                source: .nationalLibrary
            )

        } catch NationalLibraryError.bookNotFound {
            throw BookLookupError.bookNotFound

        } catch {
            throw BookLookupError.fallbackUnavailable
        }
    }
}
