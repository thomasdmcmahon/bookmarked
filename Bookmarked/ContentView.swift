import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Book.dateAdded, order: .reverse)
    private var books: [Book]
    
    @State private var showingAddBook = false
    
    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView(
                        "Your library is empty",
                        systemImage: "books.vertical",
                        description: Text(
                            "Discover a book you like? Save it here!"
                        )
                    )
                } else {
                    List {
                        ForEach(books) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(book.title)
                                        .font(.headline)

                                    Text(book.author)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if !book.genre.isEmpty {
                                        Text(book.genre)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .onDelete(perform: deleteBooks)
                    }
                }
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(books[index])
        }
        
        try? modelContext.save()
    }
}
