
import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var genre = ""
    @State private var summary = ""
    @State private var publisher = ""
    @State private var isbn = ""
    @State private var themesText = ""
    @State private var personalNote = ""

    @State private var publicationYear: Int?
    @State private var firstPublishYear: Int?
    @State private var openLibraryKey: String?
    @State private var editionKey: String?
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
                }

                Section("Book Information") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Genre", text: $genre)
                }

                Section("Publication") {
                    TextField("Publisher", text: $publisher)

                    TextField("ISBN", text: $isbn)
                        .keyboardType(.numbersAndPunctuation)

                    if let year = publicationYear {
                        LabeledContent(
                            "Edition year",
                            value: String(year)
                        )
                    }

                    if let year = firstPublishYear {
                        LabeledContent(
                            "First published",
                            value: String(year)
                        )
                    }
                }

                Section("Description") {
                    TextField(
                        "Book description",
                        text: $summary,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
                }

                Section("Themes") {
                    TextField(
                        "Separate themes with commas",
                        text: $themesText,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
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
                SearchBooksView { metadata in
                    populateFields(from: metadata)
                    showingSearch = false
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

    private func populateFields(from metadata: BookMetadata) {
        title = metadata.title
        author = metadata.author
        summary = metadata.summary
        publisher = metadata.publisher
        isbn = metadata.isbn

        themesText = metadata.themes.joined(
            separator: ", "
        )

        // Genre requires separate classification
        genre = ""

        publicationYear = metadata.publicationYear
        firstPublishYear = metadata.firstPublishYear
        openLibraryKey = metadata.workKey
        editionKey = metadata.editionKey
        coverID = metadata.coverID
    }

    private func saveBook() {
        let themes = themesText
            .split(separator: ",")
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        let book = Book(
            title: title.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            author: author.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            genre: genre,
            summary: summary,
            publisher: publisher,
            publicationYear: publicationYear,
            isbn: isbn,
            personalNote: personalNote,
            openLibraryKey: openLibraryKey,
            coverID: coverID,
            editionKey: editionKey,
            firstPublishYear: firstPublishYear,
            themes: themes
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
