import SwiftUI

struct UsuarioTabView: View {
    @Binding var selectedTab: Int
    @Binding var scrollOffset: CGFloat
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab, scrollOffset: $scrollOffset)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            SpotsView()
                .tabItem { Label("Spots", systemImage: "square.grid.3x3.fill") }
                .tag(1)
            
            SDNavigationView()
                .tabItem { Label("Navigation", systemImage: "paperplane.fill") }
                .tag(2)
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

#Preview("Usuario Normal") {
    UsuarioTabView(selectedTab: .constant(0), scrollOffset: .constant(0))
        .environmentObject(ParkingViewModel())
        .environmentObject(AuthViewModel())
}
