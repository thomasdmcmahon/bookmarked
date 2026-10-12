
import SwiftUI

struct SearchBooksView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (BookMetadata) -> Void

    @State private var searchText = ""
    @State private var results: [OpenLibraryBook] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = OpenLibraryService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching books...")
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Search failed",
                        systemImage: "wifi.exclamationmark",
                        description: Text(errorMessage)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "Find a Book",
                        systemImage: "books.vertical",
                        description: Text(
                            "Search for a title, author or ISBN."
                        )
                    )
                } else {
                    List(results) { book in
                        NavigationLink {
                            EditionSelectionView(
                                work: book,
                                onSelect: onSelect
                            )
                        } label: {
                            HStack(spacing: 14) {
                                AsyncImage(
                                    url: book.coverURL
                                ) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Image(systemName: "book.closed")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 55, height: 80)

                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {
                                    Text(book.title)
                                        .font(.headline)

                                    Text(book.author)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if let year = book.firstPublishYear {
                                        Text("First published \(year)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Find a Book")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                prompt: "Title, author or ISBN"
            )
            .onSubmit(of: .search) {
                Task {
                    await search()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func search() async {
        isLoading = true
        errorMessage = nil
        results = []

        defer { isLoading = false }

        do {
            results = try await service.searchBooks(
                query: searchText
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
