
import SwiftUI

struct BookDetailView: View {
    let book: Book

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Book cover
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

                VStack(alignment: .leading, spacing: 8) {
                    Text(book.title)
                        .font(.largeTitle)
                        .bold()

                    Text(book.author)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if !book.genre.isEmpty {
                    Label(book.genre, systemImage: "tag")
                        .foregroundStyle(.secondary)
                }

                if !book.summary.isEmpty {
                    Divider()

                    Text("About the Book")
                        .font(.headline)

                    Text(book.summary)
                }

                if !book.personalNote.isEmpty {
                    Divider()

                    Text("My Notes")
                        .font(.headline)

                    Text(book.personalNote)
                }

                Divider()

                LabeledContent(
                    "Date Added",
                    value: book.dateAdded,
                    format: .dateTime.day().month().year()
                )

                if let year = book.publicationYear {
                    LabeledContent(
                        "First Published",
                        value: String(year)
                    )
                }

                if !book.publisher.isEmpty {
                    LabeledContent(
                        "Publisher",
                        value: book.publisher
                    )
                }

                if !book.isbn.isEmpty {
                    LabeledContent(
                        "ISBN",
                        value: book.isbn
                    )
                }

                if let key = book.openLibraryKey,
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
