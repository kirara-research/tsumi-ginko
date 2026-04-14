import GRDB
import Foundation

class AssociatedEntityService {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = StoryDBHandle.instance) {
        self.dbQueue = dbQueue
    }

    class CharacterList: Codable {
        let script: String
        var characters: [UnitAssociatedCharacter]

        init(script: String) {
            self.script = script
            self.characters = []
        }
    }

    struct EventAssociatedEntity: Codable {
        let id: Int
        let domain: String
        let event: Int
    }

    struct EntityWithName: Codable {
        let id: Int
        let domain: String
        let event: Int
        let eventName: LocalizedString
    }

    func getCharacters(forEntities ids: [Int], inDomain domain: String) throws -> [Int: [CharacterList]] {
        let ret = try dbQueue.read { db in
            var ret: [Int: [CharacterList]] = [:]
            var sas: [String: CharacterList] = [:]
            let rows = try Row.fetchAll(try db.makeStatement(literal: """
                SELECT entity_id, script.id, assoc_canon_id FROM assoc_character_v2
                INNER JOIN script ON (script_id = script.ref)
                WHERE entity_idspace=\(domain) AND entity_id IN \(ids)
            """))

            for row in rows {
                let entity: Int = row["entity_id"]
                let script: String = row["id"]

                if ret[entity] == nil {
                    ret[entity] = []
                }
                if sas[script] == nil {
                    sas[script] = CharacterList(script: script)
                    ret[entity]!.append(sas[script]!)
                }

                sas[script]?.characters.append(UnitAssociatedCharacter.fromPacked(row["assoc_canon_id"]))
            }

            return ret
        }

        return ret
    }

    func getCharacters(forEntity id: Int, inDomain domain: String) throws -> [Int: [CharacterList]] {
        return try getCharacters(forEntities: [id], inDomain: domain)
    }

    func getCanonCharacters(forLocalIDs ids: [Int], inDomain domain: String) throws -> [Int: UnitAssociatedCharacter] {
        var ret: [Int: UnitAssociatedCharacter] = [:]

        try dbQueue.read { db in
            try Row.fetchAll(try db.makeStatement(literal: """
                SELECT speaker, canon_id, canon_grp FROM canon_link_v1
                WHERE speaker_idspace=\(domain) AND speaker IN \(ids)
            """)).forEach { row in
                ret[row["speaker"]] = UnitAssociatedCharacter(id: row["canon_id"], unit: row["canon_grp"] ?? 0)
            }
        }

        return ret
    }

    func getEntities(associatedWithEvent eventId: Int) throws -> [EventAssociatedEntity] {
        var result: [EventAssociatedEntity] = []

        try dbQueue.read { db in
            try Row.fetchAll(try db.makeStatement(literal: """
                SELECT entity_id, entity_idspace FROM assoc_event_v3
                WHERE assoc_event=\(eventId)
                ORDER BY entity_idspace, entity_id
            """)).forEach { row in 
                result.append(EventAssociatedEntity(
                    id: row["entity_id"], 
                    domain: row["entity_idspace"], 
                    event: eventId))
            }
        }

        return result
    }

    func getEvents(forEntities ids: [Int], inDomain domain: String) throws -> [EntityWithName] {
        let result = try dbQueue.read { db in
            let rows = try Row.fetchAll(try db.makeStatement(literal: """
                SELECT entity_id, assoc_event, json_group_object(group_title_v1.lang, group_title_v1.title) AS ls
                FROM assoc_event_v3
                LEFT JOIN group_title_v1 ON (group_title_v1.domain='event' AND assoc_event=group_title_v1.id)
                WHERE entity_id IN \(ids) AND entity_idspace=\(domain)
                GROUP BY entity_id, assoc_event
            """))

            return rows.map { row in
                EntityWithName(id: row["entity_id"], 
                    domain: domain,
                    event: row["assoc_event"], 
                    eventName: try! JSONDecoder().decode(LocalizedString.self, from: row["ls"]))
            }
        }

        return result
    }

    func getEvents(forEntity id: Int, inDomain domain: String) throws -> [EntityWithName] {
        return try getEvents(forEntities: [id], inDomain: domain)
    }
}