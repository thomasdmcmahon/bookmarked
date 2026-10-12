
import SwiftUI

struct BookDetailView: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Cover
                HStack {
                    Spacer()

                    AsyncImage(url: book.coverURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Image(systemName: "book.closed")
                            .font(.system(size: 55))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 180, height: 270)

                    Spacer()
                }

                // Title and author
                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.largeTitle)
                        .bold()

                    Text(book.author)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if !book.genre.isEmpty {
                        Label(
                            book.genre,
                            systemImage: "tag"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                // Description
                if !book.summary.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("About the Book")
                            .font(.headline)

                        Text(book.summary)
                            .font(.body)
                    }
                }

                // Themes
                if !book.themes.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Themes & Subjects")
                            .font(.headline)

                        ForEach(book.themes, id: \.self) { theme in
                            Label(
                                theme,
                                systemImage: "tag"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Personal notes
                if !book.personalNote.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("My Notes")
                            .font(.headline)

                        Text(book.personalNote)
                    }
                }

                // Publication details
                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Publication Details")
                        .font(.headline)

                    if !book.publisher.isEmpty {
                        LabeledContent(
                            "Publisher",
                            value: book.publisher
                        )
                    }

                    if let year = book.publicationYear {
                        LabeledContent(
                            "Edition Year",
                            value: String(year)
                        )
                    }

                    if let year = book.firstPublishYear {
                        LabeledContent(
                            "First Published",
                            value: String(year)
                        )
                    }

                    if !book.isbn.isEmpty {
                        LabeledContent(
                            "ISBN",
                            value: book.isbn
                        )
                    }

                    LabeledContent(
                        "Date Added",
                        value: book.dateAdded,
                        format: .dateTime.day().month().year()
                    )
                }

                // Open Library links
                if let key = book.editionKey ??
                    book.openLibraryKey,
                   let url = URL(
                    string: "https://openlibrary.org\(key)"
                   ) {
                    Link(
                        "View on Open Library",
                        destination: url
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
