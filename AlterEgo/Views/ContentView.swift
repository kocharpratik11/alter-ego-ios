import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(selectedTab: $selectedTab)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)

            GroceryView()
                .tabItem { Label("Grocery", systemImage: "cart.fill") }
                .tag(1)

            BabyTrackerView()
                .tabItem { Label("Baby", systemImage: "figure.and.child.holdinghands") }
                .tag(2)

            MealsView()
                .tabItem { Label("Meals", systemImage: "fork.knife") }
                .tag(3)

            TodosView()
                .tabItem { Label("Todos", systemImage: "checklist") }
                .tag(4)
        }
        .tint(Color(red: 74/255, green: 155/255, blue: 127/255))
    }
}
