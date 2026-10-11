
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var genre = ""
    @State private var personalNote = ""

    @State private var publicationYear: Int?
    @State private var openLibraryKey: String?
    @State private var coverID: Int?

    @State private var showingSearch = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingSearch = true
                    } label: {
                        Label(
                            "Search Open Library",
                            systemImage: "magnifyingglass"
                        )
                    }
                } footer: {
                    Text(
                        "Find a book automatically or enter its details manually."
                    )
                }

                Section("Book Information") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Genre", text: $genre)

                    if let publicationYear {
                        LabeledContent(
                            "First published",
                            value: String(publicationYear)
                        )
                    }
                }

                Section("Personal Notes") {
                    TextField(
                        "Why did this book catch your attention?",
                        text: $personalNote,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(
                        title.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
            .sheet(isPresented: $showingSearch) {
                SearchBooksView { selectedBook in
                    populateFields(from: selectedBook)
                }
            }
            .alert(
                "Could not save book",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func populateFields(from book: OpenLibraryBook) {
        title = book.title
        author = book.author
        publicationYear = book.firstPublishYear
        openLibraryKey = book.key
        coverID = book.coverID

        genre = book.subjects?.first ?? ""
    }

    private func saveBook() {
        let book = Book(
            title: title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            author: author.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            genre: genre.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            publicationYear: publicationYear,
            personalNote: personalNote,
            openLibraryKey: openLibraryKey,
            coverID: coverID
        )

        modelContext.insert(book)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(book)
            saveError = error.localizedDescription
        }
    }
}
