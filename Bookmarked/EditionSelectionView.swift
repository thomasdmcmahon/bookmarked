import SwiftUI

struct EditionSelectionView: View {
    let work: OpenLibraryBook
    let onSelect: (BookMetadata) -> Void
    
    @State private var editions: [OpenLibraryEdition] = []
    @State private var isLoading = true
    @State private var isSelecting = false
    @State private var errorMessage: String?
    
    private let service = OpenLibraryService()
    
    var body: some View {
            List {
                Section {
                    Button {
                        Task {
                            await selectEdition(nil)
                        }
                    } label: {
                        Label(
                            "Save without selecting an edition",
                            systemImage: "book"
                        )
                    }
                    .disabled(isSelecting)
                } footer: {
                    Text(
                        "Save the general work if you don't need a specific edition."
                    )
                }

                Section("Available Editions") {
                    if isLoading {
                        ProgressView("Loading editions...")
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    } else if editions.isEmpty {
                        Text("No editions found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(editions) { edition in
                            Button {
                                Task {
                                    await selectEdition(edition)
                                }
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 6
                                ) {
                                    Text(edition.title ?? work.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if !edition.publisher.isEmpty {
                                        Text(edition.publisher)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let date = edition.publishDate {
                                        Text(date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if !edition.isbn.isEmpty {
                                        Text("ISBN: \(edition.isbn)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                            .disabled(isSelecting)
                        }
                    }
                }
            }
            .navigationTitle("Choose Edition")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isSelecting {
                    ProgressView("Fetching book details...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await loadEditions()
            }
        }
    
    @MainActor
    private func loadEditions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            editions = try await service.fetchEditions(
                workKey: work.key
            )
        } catch {
            errorMessage = "Unable to load editions."
        }
    }
    
    @MainActor
    private func selectEdition(
        _ edition: OpenLibraryEdition?
    ) async {
        guard !isSelecting else { return }
        
        isSelecting = true
        
        let metadata = await service.fetchMetadata(
            for: work,
            edition: edition
        )
        
        onSelect(metadata)
        isSelecting = false
    }
}
