func createMasterRepresentationMap<T: CaseIterable>(_ type: T.Type) -> [String: T] {
    [String: T](uniqueKeysWithValues: type.allCases.map { (String(describing: $0), $0) })
}

protocol ConvertibleFromMasterRepresentation: CaseIterable {
    associatedtype MasterRepresentation: Hashable
    static var masterRepresentationMap: [MasterRepresentation: Self] { get }
}

extension ConvertibleFromMasterRepresentation {
    static func fromMasterRepresentation(_ mr: MasterRepresentation) -> Self! {
        masterRepresentationMap[mr]!
    }
}

enum CardRarity: Int, Codable, ConvertibleFromMasterRepresentation {
    typealias MasterRepresentation = String
    static let masterRepresentationMap: [String: Self] = createMasterRepresentationMap(Self.self)

    case rarity_1 = 1
    case rarity_2 = 2
    case rarity_3 = 3
    case rarity_4 = 4
    case rarity_birthday = 5
}

enum CardAttribute: Int, Codable, ConvertibleFromMasterRepresentation {
    typealias MasterRepresentation = String
    static let masterRepresentationMap: [String: Self] = createMasterRepresentationMap(Self.self)

    case cute = 1
    case cool = 2
    case pure = 3
    case happy = 4
    case mysterious = 5
}

enum CardUnit: String, Codable, ConvertibleFromMasterRepresentation {
    typealias MasterRepresentation = String
    static let masterRepresentationMap: [String: Self] = createMasterRepresentationMap(Self.self)

    case light_sound = "leo"
    case idol = "mmj"
    case street = "vbs"
    case theme_park = "wxs"
    case school_refusal = "n25"
    case piapro = "vs"
    case none

    func toMasterRepresentation() -> MasterRepresentation {
        switch self {
        case .light_sound: "light_sound"
        case .idol: "idol"
        case .street: "street"
        case .theme_park: "theme_park"
        case .school_refusal: "school_refusal"
        case .piapro: "piapro"
        case .none: "none"
        }
    }
}

enum CardUnitNumeric: Int, Codable, ConvertibleFromMasterRepresentation {
    typealias MasterRepresentation = String
    static let masterRepresentationMap: [String: Self] = createMasterRepresentationMap(Self.self)

    case light_sound = 2
    case idol = 3
    case street = 4
    case theme_park = 5
    case school_refusal = 6
    case piapro = 1
    case none = 0
}

enum CardClass: Int, Codable {
    case normal = 1
    case birthday = 2
    case limited = 3
    case colorfes = 4
    case bloomfes = 5
    case world_link = 6
    case collab = 7
}
