import Foundation

struct HabitSymbolOption: Identifiable {
    let name: String
    let label: String

    var id: String { name }

    static let defaultSymbolName = "circle.fill"

    static let all: [HabitSymbolOption] = [
        HabitSymbolOption(name: "circle.fill", label: "Circle"),
        HabitSymbolOption(name: "star.fill", label: "Star"),
        HabitSymbolOption(name: "heart.fill", label: "Heart"),
        HabitSymbolOption(name: "bolt.fill", label: "Bolt"),
        HabitSymbolOption(name: "flame.fill", label: "Flame"),
        HabitSymbolOption(name: "leaf.fill", label: "Leaf"),
        HabitSymbolOption(name: "moon.fill", label: "Moon"),
        HabitSymbolOption(name: "sun.max.fill", label: "Sun"),
        HabitSymbolOption(name: "cloud.fill", label: "Cloud"),
        HabitSymbolOption(name: "drop.fill", label: "Drop"),
        HabitSymbolOption(name: "book.closed.fill", label: "Book"),
        HabitSymbolOption(name: "pencil.and.scribble", label: "Writing"),
        HabitSymbolOption(name: "graduationcap.fill", label: "Learning"),
        HabitSymbolOption(name: "brain.head.profile", label: "Meditation"),
        HabitSymbolOption(name: "figure.run", label: "Running"),
        HabitSymbolOption(name: "figure.walk", label: "Walking"),
        HabitSymbolOption(name: "figure.cooldown", label: "Cooldown"),
        HabitSymbolOption(name: "dumbbell.fill", label: "Strength"),
        HabitSymbolOption(name: "bicycle", label: "Cycling"),
        HabitSymbolOption(name: "figure.yoga", label: "Yoga"),
        HabitSymbolOption(name: "fork.knife", label: "Nutrition"),
        HabitSymbolOption(name: "cup.and.saucer.fill", label: "Coffee"),
        HabitSymbolOption(name: "waterbottle.fill", label: "Hydration"),
        HabitSymbolOption(name: "bed.double.fill", label: "Sleep"),
        HabitSymbolOption(name: "alarm.fill", label: "Alarm"),
        HabitSymbolOption(name: "timer", label: "Timer"),
        HabitSymbolOption(name: "calendar", label: "Calendar"),
        HabitSymbolOption(name: "checkmark.circle.fill", label: "Checkmark"),
        HabitSymbolOption(name: "target", label: "Target"),
        HabitSymbolOption(name: "chart.line.uptrend.xyaxis", label: "Growth"),
        HabitSymbolOption(name: "briefcase.fill", label: "Work"),
        HabitSymbolOption(name: "hammer.fill", label: "Build"),
        HabitSymbolOption(name: "paintbrush.fill", label: "Art"),
        HabitSymbolOption(name: "camera.fill", label: "Photo"),
        HabitSymbolOption(name: "music.note", label: "Music"),
        HabitSymbolOption(name: "guitars.fill", label: "Instrument"),
        HabitSymbolOption(name: "mic.fill", label: "Voice"),
        HabitSymbolOption(name: "airplane", label: "Travel"),
        HabitSymbolOption(name: "car.fill", label: "Driving"),
        HabitSymbolOption(name: "house.fill", label: "Home"),
        HabitSymbolOption(name: "pawprint.fill", label: "Pet"),
        HabitSymbolOption(name: "stethoscope", label: "Health"),
        HabitSymbolOption(name: "cross.case.fill", label: "Care"),
        HabitSymbolOption(name: "hands.clap.fill", label: "Celebrate"),
        HabitSymbolOption(name: "person.2.fill", label: "Social"),
        HabitSymbolOption(name: "message.fill", label: "Messages"),
        HabitSymbolOption(name: "phone.fill", label: "Calls"),
        HabitSymbolOption(name: "globe", label: "Explore"),
        HabitSymbolOption(name: "sparkles", label: "Reflect"),
        HabitSymbolOption(name: "tree.fill", label: "Nature"),
        HabitSymbolOption(name: "gamecontroller.fill", label: "Gaming"),
        HabitSymbolOption(name: "film.fill", label: "Film"),
        HabitSymbolOption(name: "shippingbox.fill", label: "Shipping"),
        HabitSymbolOption(name: "scissors", label: "Trim"),
        HabitSymbolOption(name: "trash.fill", label: "Cleanup")
    ]

    static func label(for symbolName: String) -> String {
        all.first(where: { $0.name == symbolName })?.label ?? symbolName
    }
}
