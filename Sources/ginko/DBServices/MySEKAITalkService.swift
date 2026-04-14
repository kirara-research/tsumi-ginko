import GRDB
import Foundation

struct MySEKAITalkFilter {
    var character_id: CanonID?
    var fixture_type: Int?
    var fixture: Int?
    var event: EventID?
    var event_related: Bool?
    var weather_related: Bool?
    var visits_related: Bool?
    var only_region: String?
}

class MySEKAITalkService {
    let dbQueue: DatabaseQueue
    let stringService = StringService()
    let associatedEntityService = AssociatedEntityService()

    init(dbQueue: DatabaseQueue = StoryDBHandle.instance) {
        self.dbQueue = dbQueue
    }

    func listMySEKAITalk(matching filter: MySEKAITalkFilter, after: Int?, maxCount count: Int) throws
        -> ([MySEKAITalk], [Int:LocalizedString], Bool) {
        var clauses = [SQL]()
        var offset = after
        if offset == nil {
            if let only_region = filter.only_region {
                if only_region != CanonicalLang {
                    let path = "$.\(only_region)"
                    clauses.append("json_extract(mysekai_cache_v4.script_preview, \(path)) IS NOT NULL")
                } else {
                    offset = 999999999
                }
            } else {
                offset = 999999999
            }
        }

        if let offset = offset {
            clauses.append("mysekai_cache_v4.talk_id < \(offset)")
        }

        if let character_id = filter.character_id {
            clauses.append("(assoc_character_v2.assoc_canon_id & 0xffffff) = \(character_id)")
        }
        
        if let fixture_type = filter.fixture_type {
            clauses.append("mysekai_furniture_cache_v1.furniture_type = \(fixture_type)")
        } else if let fixture = filter.fixture {
            clauses.append("mysekai_furniture_cache_v1.furniture_id = \(fixture)")
        } else if let event = filter.event {
            clauses.append("mysekai_cache_v4.assoc_event = \(event)")
        }

        if filter.event_related ?? false {
            clauses.append("mysekai_cache_v4.assoc_event IS NOT NULL")
        }
        if filter.visits_related ?? false {
            clauses.append("mysekai_cache_v4.has_req_visit = 1")
        }
        if filter.weather_related ?? false {
            clauses.append("mysekai_cache_v4.has_req_weather = 1")
        }

        var (talks, hasMore) = try dbQueue.read { db in
            var rows = try Row.fetchAll(try db.makeStatement(literal: """
                WITH character_cache AS (
                    SELECT assoc_character_v2.entity_id, json_group_array(
                        json_object(
                            'id', assoc_character_v2.assoc_canon_id & 0xffffff,
                            'unit', (assoc_character_v2.assoc_canon_id >> 24) & 0xff
                        )) AS ccbnd
                    FROM assoc_character_v2
                    WHERE assoc_character_v2.entity_idspace = 'mysekai_cgid'
                    GROUP BY assoc_character_v2.entity_id
                )
                SELECT mysekai_cache_v4.talk_id, script.id,
                    mysekai_cache_v4.assoc_event, 
                    mysekai_cache_v4.condition_list,
                    mysekai_cache_v4.script_preview,
                    ccbnd
                FROM mysekai_cache_v4
                LEFT JOIN script ON mysekai_cache_v4.script_grp_id = script.ref
                LEFT JOIN assoc_character_v2 ON (assoc_character_v2.entity_idspace = 'mysekai_cgid' 
                    AND mysekai_cache_v4.cgroup = assoc_character_v2.entity_id)
                LEFT JOIN mysekai_furniture_cache_v1 ON (mysekai_furniture_cache_v1.talk_id = mysekai_cache_v4.talk_id)
                LEFT JOIN character_cache ON (mysekai_cache_v4.cgroup = character_cache.entity_id)
                WHERE \(clauses.joined(operator: .and))
                GROUP BY mysekai_cache_v4.talk_id
                ORDER BY mysekai_cache_v4.talk_id DESC
                LIMIT \(count + 1)
            """))
            var hasMore = false
            if rows.count > count {
                _ = rows.popLast()
                hasMore = true
            }

            let decoder = JSONDecoder()
            return (rows.map { row in
                var sn: LocalizedString? = nil 
                if let snippetbnd: Data = row["script_preview"] {
                    sn = try! decoder.decode(LocalizedString.self, from: snippetbnd)
                }
                return MySEKAITalk(id: row["talk_id"], 
                    script: row["id"], 
                    name: [:], 
                    seqno: 0, 
                    characters: try! decoder.decode([UnitAssociatedCharacter].self, from: row["ccbnd"]), 
                    voice_bnd: "mys/\(row["id"]!)", 
                    se_bnd: nil, 
                    event_id: row["assoc_event"], 
                    snippet: sn, 
                    conditions: try! decoder.decode(MySEKAITalk.Conditions.self, from: row["condition_list"]), 
                    event_title: nil)
            }, hasMore)
        }

        if (talks.isEmpty) {
            return ([], [:], false)
        }

        var fixIDs: Set<Int> = Set()
        for t in talks {
            fixIDs.formUnion(t.conditions.furniture.map { $0.id })
        }
        try insertExtraInfo(into: &talks)
        let fixNames = try stringService.getGroupTitles(forEntities: [Int](fixIDs), inDomain: "mysekai_fixture")
        return (talks, [Int: LocalizedString](uniqueKeysWithValues: fixNames.map { ($0, $1.name) }), hasMore)
    }

    func getMySEKAITalk(id: Int) throws -> (MySEKAITalk, [MySEKAITalk], [Int: LocalizedString])? {
        let main: MySEKAITalk? = try dbQueue.read { db -> MySEKAITalk? in 
            let row = try Row.fetchOne(try db.makeStatement(literal: """
                WITH character_cache AS (
                    SELECT assoc_character_v2.entity_id, json_group_array(
                        json_object(
                            'id', assoc_character_v2.assoc_canon_id & 0xffffff,
                            'unit', (assoc_character_v2.assoc_canon_id >> 24) & 0xff
                        )) AS ccbnd
                    FROM assoc_character_v2
                    WHERE assoc_character_v2.entity_idspace = 'mysekai_cgid'
                    GROUP BY assoc_character_v2.entity_id
                ), name_bnd_cache AS (
                    SELECT id, json_group_object(lang, title) AS namebnd
                    FROM group_title_v1 WHERE domain='event' GROUP BY id
                )
                SELECT mysekai_cache_v4.talk_id, script.id,
                    mysekai_cache_v4.assoc_event, 
                    mysekai_cache_v4.condition_list,
                    mysekai_cache_v4.script_preview,
                    ccbnd,
                    namebnd
                FROM mysekai_cache_v4
                LEFT JOIN script ON mysekai_cache_v4.script_grp_id = script.ref
                LEFT JOIN character_cache ON (mysekai_cache_v4.cgroup = character_cache.entity_id)
                LEFT JOIN name_bnd_cache ON (mysekai_cache_v4.assoc_event = name_bnd_cache.id)
                WHERE mysekai_cache_v4.talk_id = \(id)
            """))

            guard let row = row else {
                return nil
            }

            let decoder = JSONDecoder()

            var sn: LocalizedString? = nil 
            if let snippetbnd: Data = row["script_preview"] {
                sn = try! decoder.decode(LocalizedString.self, from: snippetbnd)
            }
            var et: LocalizedString? = nil
            if let namebnd: Data = row["namebnd"] {
                et = try! decoder.decode(LocalizedString.self, from: namebnd)
            }

            return MySEKAITalk(id: row["talk_id"], 
                script: row["id"], 
                name: [:], 
                seqno: 0, 
                characters: try! decoder.decode([UnitAssociatedCharacter].self, from: row["ccbnd"]), 
                voice_bnd: "mys/\(row["id"]!)", 
                se_bnd: nil, 
                event_id: row["assoc_event"], 
                snippet: sn, 
                conditions: try! decoder.decode(MySEKAITalk.Conditions.self, from: row["condition_list"]), 
                event_title: et)
        }

        guard let main = main else {
            return nil
        }

        var haveRelated = false
        var relatedFilter: MySEKAITalkFilter = MySEKAITalkFilter(
            character_id: nil, 
            fixture_type: nil, 
            fixture: nil,
            event: nil, 
            event_related: nil, 
            weather_related: nil, 
            visits_related: nil, 
            only_region: nil)
        if !main.conditions.furniture.isEmpty {
            relatedFilter.fixture = main.conditions.furniture.min { $0.id < $1.id }!.id
            haveRelated = true
        } else if main.event_id != nil {
            relatedFilter.event = main.event_id!
            haveRelated = true
        } else if !main.conditions.weather.isEmpty {
            relatedFilter.character_id = main.characters.first?.id
            relatedFilter.weather_related = true
            haveRelated = true
        } else if main.conditions.visit_count != nil {
            relatedFilter.character_id = main.characters.first?.id
            relatedFilter.visits_related = true
            haveRelated = true
        }

        var (related, fixNames, _) = haveRelated ? try listMySEKAITalk(matching: relatedFilter, after: nil, maxCount: 11) : ([], [:], false)
        if let i = related.firstIndex(where: { $0.id == main.id }) {
            related.remove(at: i)
        } else {
            let fixIDs: Set<Int> = Set(main.conditions.furniture.map { $0.id })
            let myFixNames = try stringService.getGroupTitles(forEntities: [Int](fixIDs), inDomain: "mysekai_fixture")
            for key in myFixNames.keys {
                fixNames[key] = myFixNames[key]?.name
            }
        }
        
        return (main, related, fixNames)
    }

    fileprivate func insertExtraInfo(into talks: inout [MySEKAITalk]) throws {
        let needEventIDs = talks.compactMap { $0.event_id }
        let etdict = try stringService.getGroupTitles(forEntities: needEventIDs, inDomain: "event")
        for t in talks {
            if let eid = t.event_id, let gt = etdict[eid] {
                t.event_title = gt.name
            }
        }
    }
}
