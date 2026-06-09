import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Gen-Z Greetings (shuffled on each launch)

    private static let genZGreetings: [String] = [
        "Heyyy",
        "Slay",
        "What's good",
        "Vibes",
        "Let's gooo",
        "No cap",
        "Bet",
        "Periodt",
        "It's giving",
        "Iconic",
        "Yas queen",
        "Main character",
        "Lowkey hi",
        "Highkey hi",
        "Big mood",
        "W day",
        "Sheesh",
        "Say less",
        "Real ones only",
        "IYKYK",
        "Bussin",
        "On point",
        "Oof let's go",
        "Ate that",
        "Snatched",
        "Fire vibes",
        "We move",
        "It's a vibe",
        "Understood",
        "Go off",
        "Living rent free",
        "That's a W",
        "Yeet",
        "No thoughts",
        "Chef's kiss",
        "Hits different",
        "Sending love",
        "Rent free era",
        "Unhinged energy",
        "Stan mode",
        "Manifest it",
        "Feral hours",
        "Core memory",
        "Soft launch",
        "Hard launch",
        "Hot take",
        "Valid",
        "You're valid",
        "Tea time",
        "It's a serve"
    ]

    /// Randomly picked Gen-Z greeting, fixed per ViewModel lifetime (i.e. per launch).
    let vibeGreeting: String = genZGreetings.randomElement() ?? "Heyyy"

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }

    var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}
