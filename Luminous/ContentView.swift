import SwiftUI

struct ContentView: View {
    @State private var showSettings = false
    @State private var showFavorites = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Luminous")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tu app base está lista")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [.purple, .indigo, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Luminous")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showFavorites = true
                    } label: {
                        Label("Favoritos", systemImage: "heart")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                    Button {
                        showShare = true
                    } label: {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                VStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)
                    Text("Ajustes")
                        .font(.title2.bold())
                    Text("Aquí irá la configuración de Luminous.")
                        .foregroundStyle(.secondary)
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showFavorites) {
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.pink)
                    Text("Favoritos")
                        .font(.title2.bold())
                    Text("Tus elementos guardados aparecerán aquí.")
                        .foregroundStyle(.secondary)
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("Compartir Luminous", isPresented: $showShare, titleVisibility: .visible) {
                Button("Copiar enlace") {
                    UIPasteboard.general.string = "https://luminous.app"
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
