import Foundation

typealias CanonID = Int
/* note: no inheritance allowed here due to Codable shenanigans */

struct UnitAssociatedCharacter: Codable {
    let id: CanonID
    let unit: Int

    static func fromPacked(_ packed: Int) -> UnitAssociatedCharacter {
        let unit = (packed >> 24) & 0xFF
        let cmid = packed & 0xFFFFFF
        return UnitAssociatedCharacter(id: cmid, unit: unit)
    }
}

enum EpisodeType: Int, Codable {
    case script = 1
    case music = 2
}

class Episode: Codable, GroupTitleAccepting {
    var id: Int
    var script: String
    var name: LocalizedString
    var seqno: Int
    var type: EpisodeType = .script
    var characters: [UnitAssociatedCharacter]
    var voice_bnd: String?
    var se_bnd: String?

    init(
        id: Int,
        script: String,
        name: LocalizedString,
        seqno: Int,
        characters: [UnitAssociatedCharacter],
        voice_bnd: String?,
        se_bnd: String?,
    ) {
        self.id = id
        self.script = script
        self.name = name
        self.seqno = seqno
        self.characters = characters
        self.voice_bnd = voice_bnd
        self.se_bnd = se_bnd
    }
}

class AreaConversation: Codable {
    var id: Int
    var script: String
    var name: LocalizedString
    var seqno: Int
    var type: EpisodeType = .script
    var characters: [UnitAssociatedCharacter]
    var voice_bnd: String?
    var se_bnd: String?

    var location: Int
    var primary_character: CanonID
    var primary_group: Int

    init(
        id: Int,
        script: String,
        name: LocalizedString,
        seqno: Int,
        characters: [UnitAssociatedCharacter],
        voice_bnd: String?,
        se_bnd: String?,
        location: Int,
        primary_character: CanonID,
        primary_group: Int,
    ) {
        self.id = id
        self.script = script
        self.name = name
        self.seqno = seqno
        self.characters = characters
        self.voice_bnd = voice_bnd
        self.se_bnd = se_bnd
        self.location = location
        self.primary_character = primary_character
        self.primary_group = primary_group
    }
}

class MusicPerformance: Codable {
    var id: Int
    var music_group: Int
    var music_vocal: Int
    var seqno: Int
    var type: EpisodeType = .music

    var music_title: LocalizedString
    var music_lyricist: LocalizedString
    var music_composer: LocalizedString
    var music_arranger: LocalizedString
    var characters: [UnitAssociatedCharacter]

    init(
        id: Int,
        music_group: Int,
        music_vocal: Int,
        seqno: Int,
    ) {
        self.id = id
        self.music_group = music_group
        self.music_vocal = music_vocal
        self.seqno = seqno

        music_title = [:]
        music_lyricist = [:]
        music_composer = [:]
        music_arranger = [:]
        characters = []
    }
}

class MySEKAITalk: Codable, GroupTitleAccepting {
    struct Furniture: Codable {
        var id: Int
        var type: Int
        var icon: String
    }

    struct Conditions: Codable {
        var furniture: [Furniture]
        var weather: [Int]
        var visit_count: Int?
    }

    var id: Int
    var script: String
    var name: LocalizedString
    var seqno: Int
    var type: EpisodeType = .script
    var characters: [UnitAssociatedCharacter]
    var voice_bnd: String?
    var se_bnd: String?

    var event_id: EventID?
    var snippet: LocalizedString?
    var conditions: Conditions
    var event_title: LocalizedString?

    init(
        id: Int,
        script: String,
        name: LocalizedString,
        seqno: Int,
        type: EpisodeType = .script,
        characters: [UnitAssociatedCharacter],
        voice_bnd: String?,
        se_bnd: String?,
        event_id: EventID?,
        snippet: LocalizedString?,
        conditions: Conditions,
        event_title: LocalizedString?,
    ) {
        self.id = id
        self.script = script
        self.name = name
        self.seqno = seqno
        self.type = type
        self.characters = characters
        self.voice_bnd = voice_bnd
        self.se_bnd = se_bnd
        self.event_id = event_id
        self.snippet = snippet
        self.conditions = conditions
        self.event_title = event_title
    }
}

enum RelevanceType: String, Codable {
    case key = "main"
    case side = "sub"
}

class UnitStoryGroup: Codable, GroupTitleAndDescriptionAccepting {
    var id: Int
    var name: LocalizedString
    var description: LocalizedString
    var episodes: [Episode]
    var group_relevance: [String: RelevanceType]

    init(
        id: Int,
        name: LocalizedString,
        description: LocalizedString,
        episodes: [Episode],
        group_relevance: [String: RelevanceType],
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.episodes = episodes
        self.group_relevance = group_relevance
    }
}

class SpecialStoryGroup: Codable, GroupTitleAccepting {
    var id: Int
    var name: LocalizedString
    var episodes: [Episode]

    init(
        id: Int,
        name: LocalizedString,
        episodes: [Episode],
    ) {
        self.id = id
        self.name = name
        self.episodes = episodes
    }
}

typealias EventID = Int
class EventStoryGroup: Codable, GroupTitleAndDescriptionAccepting {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case resource_name = "banner"
        case release_date = "event_date"
        case episodes
        case group_relevance
        case assoc_cards
    }

    var id: EventID
    var name: LocalizedString
    var description: LocalizedString
    var resource_name: String
    var release_date: Date
    var episodes: [Episode]
    var group_relevance: [String: RelevanceType]
    var assoc_cards: [CardStoryGroup]

    init(
        id: EventID,
        name: LocalizedString,
        description: LocalizedString,
        resource_name: String,
        release_date: Date,
        episodes: [Episode],
        group_relevance: [String: RelevanceType],
        assoc_cards: [CardStoryGroup],
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.resource_name = resource_name
        self.release_date = release_date
        self.episodes = episodes
        self.group_relevance = group_relevance
        self.assoc_cards = assoc_cards
    }
}

enum IdolizationType: Int, Codable {
    case idolizable = 1
    case notIdolizable = 2
    case preIdolized = 3
}

typealias CardID = Int
class CardStoryGroup: Codable, GroupTitleAccepting {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case resource_name = "banner"
        case release_date = "event_date"
        case episodes
        case character_id
        case rarity
        case attribute
        case vs_affinity
        case idolization
        case event_id
        case event_title
    }

    let id: CardID
    var name: LocalizedString
    var resource_name: String
    var release_date: Date
    var episodes: [Episode]

    var character_id: CanonID
    var rarity: CardRarity
    var attribute: CardAttribute
    var vs_affinity: CardUnit?
    var idolization: IdolizationType

    var event_id: EventID?
    var event_title: LocalizedString?

    init(
        id: CardID,
        name: LocalizedString,
        resource_name: String,
        release_date: Date,
        episodes: [Episode],
        character_id: CanonID,
        rarity: CardRarity,
        attribute: CardAttribute,
        vs_affinity: CardUnit?,
        idolization: IdolizationType,
        event_id: EventID?,
        event_title: LocalizedString?,
    ) {
        self.id = id
        self.name = name
        self.resource_name = resource_name
        self.release_date = release_date
        self.episodes = episodes
        self.character_id = character_id
        self.rarity = rarity
        self.attribute = attribute
        self.vs_affinity = vs_affinity
        self.idolization = idolization
        self.event_id = event_id
        self.event_title = event_title
    }
}

enum VirtualLiveSegment: Codable {
    enum _PeekCodingKeys: String, CodingKey {
        case type
    }

    case music(MusicPerformance)
    case script(Episode)

    init(from decoder: any Decoder) throws {
        let peek = try decoder.container(keyedBy: _PeekCodingKeys.self)
        let type = try peek.decode(Int.self, forKey: .type)

        guard let type = EpisodeType(rawValue: type) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "wrong type id"))
        }

        switch type {
        case .music:
            self = try .music(MusicPerformance(from: decoder))
        case .script:
            self = try .script(Episode(from: decoder))
        }
    }

    func encode(to encoder: any Encoder) throws {
        switch self {
        case let .music(val):
            try val.encode(to: encoder)
        case let .script(val):
            try val.encode(to: encoder)
        }
    }
}

class VirtualLiveSetlist: Codable, GroupTitleAccepting {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case resource_name = "banner"
        case release_date = "event_date"
        case episodes
        case group_relevance
    }

    var id: Int
    var name: LocalizedString
    var description: LocalizedString
    var resource_name: String
    var release_date: Date
    var episodes: [VirtualLiveSegment]
    /// to be removed, but check whether tsumi requires a dict to exist here first
    var group_relevance: [String: RelevanceType] = [:]

    init(
        id: Int,
        name: LocalizedString,
        description: LocalizedString,
        resource_name: String,
        release_date: Date,
        episodes: [VirtualLiveSegment],
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.resource_name = resource_name
        self.release_date = release_date
        self.episodes = episodes
    }
}

struct EventCollection: Codable {
    var event_id: Int
    var event: EventStoryGroup
    var cards: [CardStoryGroup]
    var virtual_live: VirtualLiveSetlist? = nil
    var area_conversations: [AreaConversation]
}
