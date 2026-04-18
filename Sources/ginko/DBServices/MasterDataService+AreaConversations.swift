import Foundation
import GRDB

struct AreaConversationFilter: Codable {
    var character_ids: [CanonID]?
    var area: Int?
    var secret: Bool?
    var only_region: String?
}

extension AreaConversation: Hashable {
    static func == (lhs: AreaConversation, rhs: AreaConversation) -> Bool {
        lhs.id == rhs.id && lhs.script == rhs.script
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(script)
    }
}

extension MasterDataService /* ActionSets */ {
    func listAreaConversations(matching filter: AreaConversationFilter, after page: Int?, maxCount: Int = 20) throws -> ([AreaConversation], Bool) {
        var offset = page
        if offset == nil {
            if let only_region = filter.only_region {
                if only_region != CanonicalLang {
                    offset = try stringService.latestTranslatedEntity(forLang: only_region, inDomain: "area") + 1
                } else {
                    offset = 999_999_999
                }
            } else {
                offset = 999_999_999
            }
        }

        var extraJoin = SQL("")
        var clauses: [SQL] = [
            "actionSets.id < \(offset)", "actionSets.scenarioId NOT NULL",
        ]

        if let characterIDs = filter.character_ids {
            if characterIDs.count == 2 {
                clauses.append("ccj1.characterId = \(characterIDs[0]) AND ccj2.characterId = \(characterIDs[1])")
                extraJoin = """
                    LEFT JOIN actionSets_characterIds AS cj2 ON (actionSets.characterIds = cj2._link)
                    INNER JOIN character2ds as ccj2 ON (cj2.value = ccj2.id AND ccj1.id < ccj2.id)
                """
            } else {
                clauses.append("ccj1.characterId = \(characterIDs[0])")
            }
        }

        if let areaID = filter.area {
            clauses.append("actionSets.areaId = \(areaID)")
        }

        if filter.secret == true {
            clauses.append("actionSets.archiveDisplayType = 'none'")
        }

        let (actionSetIDs, hasMore) = try dbQueue.read { db in
            var ids: [Int] = try Row.fetchAll(db.makeStatement(literal: """
                SELECT actionSets.id
                FROM actionSets
                LEFT JOIN actionSets_characterIds AS cj1 ON actionSets.characterIds = cj1._link
                LEFT JOIN character2ds as ccj1 ON (cj1.value = ccj1.id)
                \(extraJoin)
                WHERE \(clauses.joined(operator: .and))
                GROUP BY actionSets.id
                ORDER BY actionSets.id DESC
                LIMIT \(maxCount + 1)
            """)).map { $0["id"] }

            var hasMore = false
            if ids.count > maxCount {
                _ = ids.popLast()
                hasMore = true
            }

            return (ids, hasMore)
        }

        let actionSets = try getAreaConversations(matching: actionSetIDs)
        return (actionSets, hasMore)
    }

    func getAreaConversations(relatedTo id: Int) throws -> (AreaConversation, [AreaConversation])? {
        let row = try dbQueue.read { db in
            try Row.fetchOne(db.makeStatement(literal: """
                SELECT areaId, scenarioId, releaseConditionId FROM actionSets
                WHERE id=\(id) AND scenarioId NOT NULL
            """))
        }

        guard let row else {
            return nil
        }

        let area: Int = row["areaId"]
        let rc: Int = row["releaseConditionId"]
        let script: String = row["scenarioId"]
        var prefix = script

        if let m = script.firstMatch(of: /^(.*)_([0-9a-z]+)$/) {
            prefix = "\(m.1)%"
        }

        let relatedIDs = try dbQueue.read { db in
            try Row.fetchAll(db.makeStatement(literal: """
                SELECT id FROM actionSets
                WHERE id != \(id) AND (releaseConditionId = \(rc) OR areaId = \(area)) AND scenarioId LIKE \(prefix)
                ORDER BY (scenarioId > \(script)) DESC, id
                LIMIT 10
            """)).map { row -> Int in row["id"] }
        }

        var allSets = try getAreaConversations(matching: [id] + relatedIDs)
        if let i = allSets.firstIndex(where: { $0.id == id }) {
            let main = allSets.remove(at: i)
            return (main, allSets)
        }
        return nil
    }

    func getAreaConversations(matching ids: [Int]) throws -> [AreaConversation] {
        let convs = try dbQueue.read { db in
            let rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT actionSets.id, actionSets.areaId, scenarioId
                FROM actionSets
                WHERE actionSets.id IN \(ids)
                ORDER BY actionSets.id DESC
            """))

            return rows.map { row in
                AreaConversation(
                    id: row["id"],
                    script: row["scenarioId"],
                    name: [:],
                    seqno: 1,
                    characters: [],
                    voice_bnd: "actionset/\(row["scenarioId"]!)",
                    se_bnd: nil,
                    location: row["areaId"],
                    primary_character: 0,
                    primary_group: 0,
                )
            }
        }

        let titles = try stringService.getGroupTitles(forEntities: ids, inDomain: "area")
        let characters = try associatedEntityService.getCharacters(forEntities: ids, inDomain: "area")
        var needLocalCharacters: [Int: Set<AreaConversation>] = [:]

        for ac in convs {
            if let gt = titles[ac.id] {
                ac.name = gt.name
                if let chIDs = gt.description[CanonicalLang],
                   let chIDs, let chID = Int(chIDs)
                {
                    needLocalCharacters[chID, default: Set()].insert(ac)
                }
            }
            if let charList = characters[ac.id] {
                ac.characters = charList[0].characters
            }
        }

        let canonCharacters = try associatedEntityService.getCanonCharacters(
            forLocalIDs: [Int](needLocalCharacters.keys),
            inDomain: "ch_2d",
        )

        for (lid, ch) in canonCharacters {
            if let acs = needLocalCharacters[lid] {
                for ac in acs {
                    ac.primary_character = ch.id
                    ac.primary_group = ch.unit
                }
            }
        }

        return convs
    }
}
