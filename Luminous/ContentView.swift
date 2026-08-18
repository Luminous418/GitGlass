import SwiftUI
import PhotosUI

struct ContentView: View {
    var body: some View {
        TabView {
            CommitsView()
                .tabItem { Label("Commits", systemImage: "arrow.triangle.branch") }

            FavoritesView()
                .tabItem { Label("Favoritos", systemImage: "heart.fill") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
    }
}

enum LoadState {
    case loading, loaded, empty, failed(String)
}

struct MeshBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                .purple, .indigo, .cyan,
                .mint, .blue, .teal,
                .pink, .orange, .yellow
            ]
        )
        .ignoresSafeArea()
    }
}

enum BackgroundStore {
    static let key = "customBackgroundEnabled"
    static let filename = "customBackground.jpg"

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var fileURL: URL {
        documentsURL.appendingPathComponent(filename)
    }

    @discardableResult
    static func save(_ image: UIImage) -> Bool {
        guard let resized = resized(image),
              let data = resized.jpegData(compressionQuality: 0.8) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: fileURL.path)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func resized(_ image: UIImage) -> UIImage? {
        let maxDimension: CGFloat = 2000
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct AppBackground: View {
    @AppStorage(BackgroundStore.key) private var customBackgroundEnabled = false
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if customBackgroundEnabled, let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                MeshBackground()
            }
        }
        .onAppear {
            if customBackgroundEnabled {
                image = BackgroundStore.load()
            }
        }
        .onChange(of: customBackgroundEnabled) { _, enabled in
            image = enabled ? BackgroundStore.load() : nil
        }
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat
    var content: Content

    init(cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

struct CommitsView: View {
    @Environment(\.openURL) private var openURL
    @State private var repos: [Repo] = []
    @State private var commitsByRepo: [String: [CommitItem]] = [:]
    @State private var user: GitHubUser?
    @State private var loadState: LoadState = .loading

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle("Commits")
            .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView("Cargando repositorios...")
        case .failed(let message):
            ErrorView(message: message) {
                Task { await load() }
            }
        case .empty:
            EmptyStateView(
                icon: "tray",
                title: "No hay repositorios",
                subtitle: nil
            )
        case .loaded:
            ScrollView {
                VStack(spacing: 16) {
                    GitHubCard(user: user) {
                        openGitHub()
                    }
                    ForEach(repos) { repo in
                        RepoCard(
                            repo: repo,
                            commits: commitsByRepo[repo.fullName] ?? [],
                            onOpenRepo: {
                                if let url = URL(string: repo.htmlURL) {
                                    openURL(url)
                                }
                            },
                            onOpenCommit: { commit in
                                if let url = URL(string: commit.htmlURL) {
                                    openURL(url)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .refreshable { await load() }
        }
    }

    private func openGitHub() {
        guard let url = URL(string: user?.htmlURL ?? "https://github.com/Luminous418") else { return }
        openURL(url)
    }

    private func load() async {
        loadState = .loading
        do {
            user = (try? await GitHubService.shared.fetchUser())
            let repos = try await GitHubService.shared.fetchRepos()
            guard !repos.isEmpty else {
                loadState = .empty
                return
            }

            var commitsByRepo: [String: [CommitItem]] = [:]
            await withTaskGroup(of: (String, [CommitItem]).self) { group in
                for repo in repos {
                    group.addTask {
                        let commits = (try? await GitHubService.shared.fetchCommits(for: repo)) ?? []
                        return (repo.fullName, commits)
                    }
                }
                for await (fullName, commits) in group {
                    commitsByRepo[fullName] = commits
                }
            }

            self.repos = repos
            self.commitsByRepo = commitsByRepo
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

struct RepoCard: View {
    let repo: Repo
    let commits: [CommitItem]
    let onOpenRepo: () -> Void
    let onOpenCommit: (CommitItem) -> Void

    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onOpenRepo) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repo.name)
                                .font(.headline)
                            if let description = repo.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            if let language = repo.language {
                                Text(language)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if commits.isEmpty {
                    Text("Sin commits recientes")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Divider()
                    ForEach(commits) { commit in
                        Button {
                            onOpenCommit(commit)
                        } label: {
                            CommitRowView(commit: commit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CommitRowView: View {
    let commit: CommitItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(commit.authorName) · \(relativeDate(commit.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func relativeDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(.relative(presentation: .named))
    }
}

struct GitHubCard: View {
    let user: GitHubUser?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 16) {
                    if let user {
                        AsyncImage(url: URL(string: user.avatarURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.login)
                                .font(.headline)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tu perfil")
                                .font(.headline)
                            Text("Configura tu token en Ajustes")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct FavoritesView: View {
    @AppStorage("favoriteRepos") private var favoriteReposData = Data()
    @State private var repos: [Repo] = []
    @State private var loadState: LoadState = .loading

    private var favoriteNames: [String] {
        (try? JSONDecoder().decode([String].self, from: favoriteReposData)) ?? []
    }

    private var favorites: [Repo] {
        repos.filter { favoriteNames.contains($0.fullName) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                content
            }
            .navigationTitle("Favoritos")
            .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView("Cargando repositorios...")
        case .failed(let message):
            ErrorView(message: message) {
                Task { await load() }
            }
        case .empty:
            EmptyStateView(
                icon: "tray",
                title: "No hay repositorios",
                subtitle: nil
            )
        case .loaded:
            ScrollView {
                VStack(spacing: 16) {
                    if favorites.isEmpty {
                        EmptyStateView(
                            icon: "heart",
                            title: "Sin favoritos todavía",
                            subtitle: "Toca el corazón de un repo para guardarlo y ver su historial de commits."
                        )
                    } else {
                        Text("Guardados")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(favorites) { repo in
                            FavoriteRepoCard(repo: repo) {
                                toggleFavorite(repo)
                            }
                        }
                    }

                    Text("Todos tus repos")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(repos) { repo in
                        RepoSelectionCard(
                            repo: repo,
                            isFavorite: favoriteNames.contains(repo.fullName)
                        ) {
                            toggleFavorite(repo)
                        }
                    }
                }
                .padding()
            }
            .refreshable { await load() }
        }
    }

    private func toggleFavorite(_ repo: Repo) {
        var names = favoriteNames
        if let index = names.firstIndex(of: repo.fullName) {
            names.remove(at: index)
        } else {
            names.append(repo.fullName)
        }
        favoriteReposData = (try? JSONEncoder().encode(names)) ?? Data()
    }

    private func load() async {
        loadState = .loading
        do {
            let repos = try await GitHubService.shared.fetchRepos()
            guard !repos.isEmpty else {
                loadState = .empty
                return
            }
            self.repos = repos
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

struct FavoriteRepoCard: View {
    let repo: Repo
    let onRemove: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 12) {
                NavigationLink {
                    RepoCommitsView(repo: repo)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repo.name)
                                .font(.subheadline.weight(.semibold))
                            Text("Ver historial de commits")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    Image(systemName: "heart.slash.fill")
                        .foregroundStyle(.pink)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RepoSelectionCard: View {
    let repo: Repo
    let isFavorite: Bool
    let onToggle: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.subheadline)
                    if let description = repo.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(action: onToggle) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? .pink : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RepoCommitsView: View {
    @Environment(\.openURL) private var openURL
    let repo: Repo
    @State private var commits: [CommitItem] = []
    @State private var loadState: LoadState = .loading

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .navigationTitle(repo.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView("Cargando commits...")
        case .failed(let message):
            ErrorView(message: message) {
                Task { await load() }
            }
        case .empty:
            EmptyStateView(
                icon: "doc.text",
                title: "Sin commits",
                subtitle: "Este repositorio no tiene commits."
            )
        case .loaded:
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard(cornerRadius: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(repo.name)
                                    .font(.headline)
                                Spacer()
                                if let language = repo.language {
                                    Text(language)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.2), in: Capsule())
                                }
                            }
                            if let description = repo.description, !description.isEmpty {
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Ver repo en GitHub") {
                                if let url = URL(string: repo.htmlURL) {
                                    openURL(url)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    ForEach(commits) { commit in
                        Button {
                            if let url = URL(string: commit.htmlURL) {
                                openURL(url)
                            }
                        } label: {
                            GlassCard(cornerRadius: 20) {
                                CommitRowView(commit: commit)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .refreshable { await load() }
        }
    }

    private func load() async {
        loadState = .loading
        do {
            let commits = try await GitHubService.shared.fetchCommits(for: repo, perPage: 30)
            guard !commits.isEmpty else {
                loadState = .empty
                return
            }
            self.commits = commits
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !GitHubService.shared.hasToken {
                Text("Pega tu token de GitHub en Ajustes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Reintentar", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @State private var pat = ""
    @State private var hasSavedPAT = false
    @State private var justSaved = false
    @AppStorage(BackgroundStore.key) private var customBackgroundEnabled = false
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Token de GitHub", systemImage: "key.fill")
                                    .font(.headline)

                                SecureField("Pega tu Personal Access Token", text: $pat)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                Text("Se guarda solo en este dispositivo (Keychain). No queda embebido en la app ni se sube a GitHub.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 12) {
                                    Button("Guardar") {
                                        GitHubAuth.token = pat
                                        hasSavedPAT = !pat.isEmpty
                                        justSaved = true
                                        Task {
                                            try? await Task.sleep(for: .seconds(2))
                                            justSaved = false
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(pat.isEmpty || pat == GitHubAuth.token)

                                    if hasSavedPAT {
                                        Button("Borrar", role: .destructive) {
                                            GitHubAuth.token = ""
                                            pat = ""
                                            hasSavedPAT = false
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Spacer()

                                    if justSaved {
                                        Label("Guardado", systemImage: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Fondo de la app", systemImage: "photo.on.rectangle.angled")
                                    .font(.headline)

                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    Label("Elegir foto de fondo", systemImage: "photo")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.borderedProminent)
                                .onChange(of: selectedItem) { _, item in
                                    guard let item else { return }
                                    Task {
                                        if let data = try? await item.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data),
                                           BackgroundStore.save(image) {
                                            customBackgroundEnabled = true
                                        }
                                    }
                                }

                                Button("Restaurar fondo predeterminado") {
                                    BackgroundStore.remove()
                                    customBackgroundEnabled = false
                                }
                                .buttonStyle(.bordered)
                                .disabled(!customBackgroundEnabled)

                                Text("El fondo elegido se guarda solo en este dispositivo.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    }
                    .padding()
                }
            }
            .navigationTitle("Ajustes")
            .task {
                pat = GitHubAuth.token
                hasSavedPAT = !pat.isEmpty
            }
        }
    }
}

#Preview {
    ContentView()
}
