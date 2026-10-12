
import SwiftUI
import SwiftData

// MARK: - Sheet Navigation

private enum AddBookSheet: String, Identifiable {
    case search
    case scanner

    var id: String { rawValue }
}

// MARK: - Add Book View

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Book information
    @State private var title = ""
    @State private var author = ""
    @State private var genre = ""
    @State private var summary = ""
    @State private var publisher = ""
    @State private var isbn = ""
    @State private var themesText = ""
    @State private var personalNote = ""

    // Publication information
    @State private var publicationYear: Int?
    @State private var firstPublishYear: Int?

    // Open Library metadata
    @State private var openLibraryKey: String?
    @State private var editionKey: String?
    @State private var coverID: Int?

    // ISBN lookup
    @State private var isbnInput = ""
    @State private var isLookingUpISBN = false
    @State private var lookupError: String?
    @State private var metadataSource: String?

    // Sheet navigation
    @State private var activeSheet: AddBookSheet?
    @State private var pendingScannedISBN: String?

    // Save state
    @State private var saveError: String?

    private let service = BookLookupService()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Search by title or author

                Section {
                    Button {
                        activeSheet = .search
                    } label: {
                        Label(
                            "Search Open Library",
                            systemImage: "magnifyingglass"
                        )
                    }
                } header: {
                    Text("Find by Title or Author")
                } footer: {
                    Text(
                        "Search for a book by title or author and select an edition."
                    )
                }

                // MARK: Find by ISBN

                Section {
                    HStack(spacing: 12) {
                        TextField(
                            "Enter ISBN-10 or ISBN-13",
                            text: $isbnInput
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.search)
                        .onSubmit {
                            Task {
                                await lookupISBN()
                            }
                        }

                        // Camera scanner
                        Button {
                            activeSheet = .scanner
                        } label: {
                            Image(
                                systemName: "camera.viewfinder"
                            )
                            .font(.title2)
                        }
                        .accessibilityLabel("Scan ISBN")

                        // Manual ISBN lookup
                        Button {
                            Task {
                                await lookupISBN()
                            }
                        } label: {
                            if isLookingUpISBN {
                                ProgressView()
                            } else {
                                Image(
                                    systemName: "arrow.right.circle.fill"
                                )
                                .font(.title2)
                            }
                        }
                        .disabled(
                            isbnInput.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || isLookingUpISBN
                        )
                        .accessibilityLabel("Look up ISBN")
                    }

                    if let lookupError {
                        Text(lookupError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let metadataSource {
                        Label(
                            "Metadata from \(metadataSource)",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.green)
                    }

                } header: {
                    Text("Find by ISBN")
                } footer: {
                    Text(
                        "Enter an ISBN manually or scan the barcode on the back of a book."
                    )
                }

                // MARK: Book information

                Section("Book Information") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Genre", text: $genre)
                }

                // MARK: Publication

                Section("Publication") {
                    TextField("Publisher", text: $publisher)

                    TextField("ISBN", text: $isbn)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if let publicationYear {
                        LabeledContent(
                            "Edition Year",
                            value: String(publicationYear)
                        )
                    }

                    if let firstPublishYear {
                        LabeledContent(
                            "First Published",
                            value: String(firstPublishYear)
                        )
                    }
                }

                // MARK: Description

                Section("Description") {
                    TextField(
                        "Book description",
                        text: $summary,
                        axis: .vertical
                    )
                    .lineLimit(4...10)
                }

                // MARK: Themes

                Section("Themes") {
                    TextField(
                        "Separate themes with commas",
                        text: $themesText,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                // MARK: Personal notes

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

            // MARK: Toolbar

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
                        ).isEmpty || isLookingUpISBN
                    )
                }
            }

            // MARK: Sheet Presentation

            .sheet(
                item: $activeSheet,
                onDismiss: {
                    guard let scannedISBN = pendingScannedISBN else {
                        return
                    }

                    pendingScannedISBN = nil
                    isbnInput = scannedISBN

                    Task {
                        await lookupISBN()
                    }
                }
            ) { sheet in
                switch sheet {

                case .search:
                    SearchBooksView { metadata in
                        populateFields(from: metadata)
                        metadataSource = "Open Library"
                        lookupError = nil
                        activeSheet = nil
                    }

                case .scanner:
                    ISBNScannerView { scannedISBN in
                        pendingScannedISBN = scannedISBN
                        activeSheet = nil
                    }
                }
            }

            // MARK: Save Error

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

    // MARK: - ISBN Lookup

    @MainActor
    private func lookupISBN() async {
        guard !isLookingUpISBN else {
            return
        }

        isLookingUpISBN = true
        lookupError = nil
        metadataSource = nil

        defer {
            isLookingUpISBN = false
        }

        let normalizedISBN = OpenLibraryService.normalizeISBN(
            isbnInput
        )

        do {
            let result = try await service.lookupISBN(
                normalizedISBN
            )

            populateFields(from: result.metadata)
            metadataSource = result.source.displayName

        } catch BookLookupError.bookNotFound {
            prepareManualEntry(for: normalizedISBN)

            lookupError = """
            This ISBN was not found in Open Library or
            Nasjonalbiblioteket. You can still save it manually.
            """

        } catch {
            lookupError = error.localizedDescription
        }
    }

    // MARK: - Manual Entry Fallback

    private func prepareManualEntry(for isbn: String) {
        title = ""
        author = ""
        genre = ""
        summary = ""
        publisher = ""
        themesText = ""

        publicationYear = nil
        firstPublishYear = nil

        openLibraryKey = nil
        editionKey = nil
        coverID = nil
        metadataSource = nil

        self.isbn = isbn

        // Preserve any existing personal note.
    }

    // MARK: - Populate Form

    private func populateFields(from metadata: BookMetadata) {
        title = metadata.title
        author = metadata.author
        summary = metadata.summary
        publisher = metadata.publisher
        isbn = metadata.isbn

        themesText = metadata.themes.joined(
            separator: ", "
        )

        genre = ""

        publicationYear = metadata.publicationYear
        firstPublishYear = metadata.firstPublishYear

        openLibraryKey = metadata.workKey.isEmpty
            ? nil
            : metadata.workKey

        editionKey = metadata.editionKey
        coverID = metadata.coverID
    }

    // MARK: - Save Book

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
