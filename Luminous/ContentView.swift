import SwiftUI

enum AppTab: Hashable {
    case home, favorites, settings
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }

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

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Luminous")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                Text("Tu app base con Liquid Glass")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        GitHubCard {
                            openGitHub()
                        }

                        HStack(spacing: 16) {
                            featureCard(icon: "bolt.fill", title: "Rápida", color: .yellow)
                            featureCard(icon: "shield.fill", title: "Segura", color: .green)
                        }

                        featureCard(icon: "sparkles", title: "Liquid Glass", color: .cyan)
                    }
                    .padding()
                }
            }
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .confirmationDialog("Compartir Luminous", isPresented: $showShare, titleVisibility: .visible) {
                Button("Copiar enlace") {
                    UIPasteboard.general.string = "https://luminous.app"
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    private func openGitHub() {
        guard let url = URL(string: "https://github.com/Luminous418") else { return }
        openURL(url)
    }

    private func featureCard(icon: String, title: String, color: Color) -> some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
        }
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