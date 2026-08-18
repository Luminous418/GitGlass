import SwiftUI

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
    @State private var loadState: LoadState = .loading

    enum LoadState {
        case loading, loaded, empty, failed(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
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
            errorView(message)
        case .empty:
            emptyView
        case .loaded:
            ScrollView {
                VStack(spacing: 16) {
                    GitHubCard {
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

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No hay repositorios")
                .font(.headline)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !GitHubService.shared.hasToken {
                Text("Configura el secret GITHUB_PAT y vuelve a compilar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Reintentar") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func openGitHub() {
        guard let url = URL(string: "https://github.com/Luminous418") else { return }
        openURL(url)
    }

    private func load() async {
        loadState = .loading
        do {
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
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func relativeDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        return date.formatted(.relative(presentation: .named))
    }
}

struct GitHubCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: "https://avatars.githubusercontent.com/u/107070993?v=4")) { image in
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
                        Text("Luminous418")
                            .font(.headline)
                        Text("Visita mi GitHub")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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
    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.pink)
                        Text("Favoritos")
                            .font(.title2.bold())
                        Text("Tus elementos guardados aparecerán aquí.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Favoritos")
        }
    }
}

struct SettingsView: View {
    @State private var notifications = true
    @State private var appearance = "Automático"

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassCard {
                            Toggle("Notificaciones", isOn: $notifications)
                        }
                        GlassCard {
                            Picker("Apariencia", selection: $appearance) {
                                Text("Clara").tag("Clara")
                                Text("Oscura").tag("Oscura")
                                Text("Automático").tag("Automático")
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

#Preview {
    ContentView()
}