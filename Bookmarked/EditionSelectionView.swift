
import SwiftUI

struct EditionSelectionView: View {
    let work: OpenLibraryBook
    let onSelect: (BookMetadata) -> Void

    @State private var editions: [OpenLibraryEdition] = []
    @State private var searchText = ""
    @State private var selectedLanguage = "all"

    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isSelecting = false
    @State private var errorMessage: String?

    @State private var totalCount = 0
    @State private var offset = 0

    private let pageSize = 25
    private let service = OpenLibraryService()

    private let languages = [
        ("all", "All languages"),
        ("eng", "English"),
        ("nor", "Norwegian"),
        ("fre", "French"),
        ("ger", "German"),
        ("spa", "Spanish")
    ]

    private var filteredEditions: [OpenLibraryEdition] {
        editions.filter { edition in
            let matchesSearch: Bool

            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let searchable = [
                    edition.title ?? "",
                    edition.publisher,
                    edition.isbn,
                    edition.publishDate ?? ""
                ].joined(separator: " ")

                matchesSearch = searchable.localizedCaseInsensitiveContains(
                    searchText
                )
            }

            let codes = edition.languageCodes

            let matchesLanguage: Bool

            switch selectedLanguage {
            case "all":
                matchesLanguage = true
            case "nor":
                matchesLanguage = codes.contains {
                    ["nor", "nob", "nno"].contains($0)
                }
            case "fre":
                matchesLanguage = codes.contains {
                    ["fre", "fra"].contains($0)
                }
            case "ger":
                matchesLanguage = codes.contains {
                    ["ger", "deu"].contains($0)
                }
            default:
                matchesLanguage = codes.contains(selectedLanguage)
            }

            return matchesSearch && matchesLanguage
        }
    }

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
            }

            Section {
                Picker("Language", selection: $selectedLanguage) {
                    Text("All languages").tag("all")
                    Text("English").tag("eng")
                    Text("Norwegian").tag("nor")
                    Text("French").tag("fre")
                    Text("German").tag("ger")
                    Text("Spanish").tag("spa")
                }

                Text(
                    "\(filteredEditions.count) matching · \(editions.count) loaded · \(totalCount) total"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Available Editions") {
                if isLoading {
                    ProgressView("Loading editions...")
                } else {
                    ForEach(filteredEditions) { edition in
                        Button {
                            Task {
                                await selectEdition(edition)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                AsyncImage(
                                    url: edition.coverURL
                                ) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Image(systemName: "book.closed")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 60, height: 90)

                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {
                                    Text(edition.title ?? work.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if !edition.publisher.isEmpty {
                                        Text(edition.publisher)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(edition.languageDisplay)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

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

                                Spacer()
                            }
                            .padding(.vertical, 5)
                        }
                        .disabled(isSelecting)
                    }

                    if filteredEditions.isEmpty && !isLoadingMore {
                        Text(
                            "No matching editions among the loaded results."
                        )
                        .foregroundStyle(.secondary)
                    }

                    if offset < totalCount {
                        Button {
                            Task {
                                await loadMore()
                            }
                        } label: {
                            HStack {
                                Spacer()

                                if isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("Load More Editions")
                                }

                                Spacer()
                            }
                        }
                        .disabled(isLoadingMore || isSelecting)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Choose Edition")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Title, ISBN or publisher"
        )
        .overlay {
            if isSelecting {
                ProgressView("Fetching book details...")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12)
                    )
            }
        }
        .task {
            await loadMore()
        }
    }

    @MainActor
    private func loadMore() async {
        guard !isLoadingMore else { return }

        isLoadingMore = true
        isLoading = editions.isEmpty
        errorMessage = nil

        defer {
            isLoadingMore = false
            isLoading = false
        }

        do {
            let page = try await service.fetchEditions(
                workKey: work.key,
                offset: offset,
                limit: pageSize
            )

            editions.append(contentsOf: page.editions)
            offset += page.editions.count
            totalCount = page.totalCount

        } catch {
            errorMessage = error.localizedDescription
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
