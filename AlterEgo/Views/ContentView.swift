import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }

            GroceryView()
                .tabItem {
                    Label("Grocery", systemImage: "cart.fill")
                }

            BabyTrackerView()
                .tabItem {
                    Label("Baby", systemImage: "figure.and.child.holdinghands")
                }

            MealsView()
                .tabItem {
                    Label("Meals", systemImage: "fork.knife")
                }

            TodosView()
                .tabItem {
                    Label("Todos", systemImage: "checklist")
                }
        }
        .tint(Color(red: 74/255, green: 155/255, blue: 127/255))
    }
}
