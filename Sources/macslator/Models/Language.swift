import Foundation

enum Language: String, Codable, CaseIterable, Identifiable, Equatable {
    case spanish = "es"
    case english = "en"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case hindi = "hi"
    case polish = "pl"
    case turkish = "tr"
    case swedish = "sv"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: return "Spanish"
        case .english: return "English"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .dutch: return "Dutch"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .swedish: return "Swedish"
        }
    }

    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .english: return "🇬🇧"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .dutch: return "🇳🇱"
        case .russian: return "🇷🇺"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .swedish: return "🇸🇪"
        }
    }
}

extension Language {
    /// Languages supported by Apple's native Translation framework (macOS 15+).
    /// This is a subset of the languages Apple supports.
    static var nativeSupportedLanguages: [Language] {
        [.arabic, .chinese, .dutch, .english, .french, .german, .hindi, .italian, .japanese, .korean, .polish, .portuguese, .russian, .spanish, .turkish]
    }
}
