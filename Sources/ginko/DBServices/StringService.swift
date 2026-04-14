import GRDB

typealias EntityID = Int
typealias LocalizedString = [String: String?]

struct GroupTitle: Codable {
    var name: LocalizedString
    var description: LocalizedString
}

protocol GroupTitleAccepting {
    var id: EntityID { get }
    var name: LocalizedString { get set }
}

protocol GroupTitleAndDescriptionAccepting {
    var id: EntityID { get }
    var name: LocalizedString { get set }
    var description: LocalizedString { get set }
}

extension GroupTitleAccepting {
    func applyGroupTitles(_ gts: [EntityID: GroupTitle]) -> Self {
        if let gt = gts[self.id] {
            var n = self
            n.name = gt.name
            return n
        }
        return self
    }
}

extension GroupTitleAndDescriptionAccepting {
    func applyGroupTitles(_ gts: [EntityID: GroupTitle]) -> Self {
        if let gt = gts[self.id] {
            var n = self
            n.name = gt.name
            n.description = gt.description
            return n
        }
        return self
    }
}

extension Array where Element: GroupTitleAccepting {
    mutating func applyGroupTitles(_ gts: [EntityID: GroupTitle]) {
        for (i, _) in self.enumerated() {
            self[i] = self[i].applyGroupTitles(gts)
        }
    }
}

extension Array where Element: GroupTitleAndDescriptionAccepting {
    mutating func applyGroupTitles(_ gts: [EntityID: GroupTitle]) {
        for (i, _) in self.enumerated() {
            self[i] = self[i].applyGroupTitles(gts)
        }
    }
}

class StringService {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = StoryDBHandle.instance) {
        self.dbQueue = dbQueue
    }

    func latestTranslatedEntity(forLang lang: String, inDomain domain: String) throws -> EntityID {
        let row = try dbQueue.read { db in
            try Row.fetchOne(db.makeStatement(
                literal: "SELECT MAX(id) AS id FROM group_title_v1 WHERE domain=\(domain) AND lang=\(lang)"))
        }
        if let row = row {
            return row["id"]
        }
        return 0
    }

    // TODO: replace with grdb literal sql
    private static func paramList(count: Int) -> String {
        return [String](repeating: "?", count: count).joined(separator: ", ")
    }

    private func buildGroupTitleResult(from rows: [Row]) -> [EntityID: GroupTitle] {
        var result: [EntityID: GroupTitle] = [:]
        for row in rows {
            let id: EntityID = row["id"]
            if result[id] == nil {
                result[id] = GroupTitle(name: [:], description: [:])
            }

            result[id]!.name[row["lang"]] = row["title"]
            result[id]!.description[row["lang"]] = row["description"]
        }
        return result
    }

    func getGroupTitles(inDomain domain: String) throws -> [EntityID: GroupTitle] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, lang, title, description FROM group_title_v1 WHERE domain=? ORDER BY id, lang
                """,
                arguments: [domain]
            )
            return buildGroupTitleResult(from: rows)
        }
    }

    func getGroupTitles(forEntity id: Int, inDomain domain: String) throws -> [EntityID: GroupTitle] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, lang, title, description FROM group_title_v1 WHERE domain=? AND id=? ORDER BY id, lang
                """,
                arguments: [domain, id]
            )
            return buildGroupTitleResult(from: rows)
        }
    }

    func getGroupTitles(forEntities ids: [Int], inDomain domain: String) throws -> [EntityID: GroupTitle] {
        try dbQueue.read { db in
            var params: [any DatabaseValueConvertible] = [domain]
            params.append(contentsOf: ids)
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, lang, title, description FROM group_title_v1 
                    WHERE domain=? AND id IN (\(StringService.paramList(count: ids.count))) ORDER BY id, lang
                """,
                arguments: StatementArguments(params)
            )
            return buildGroupTitleResult(from: rows)
        }
    }

    private func buildChapterTitleResult(from rows: [Row]) -> [String: LocalizedString] {
        var result: [String: LocalizedString] = [:]
        for row in rows {
            let id: String = row["id"]
            if result[id] == nil {
                result[id] = [:]
            }
            result[id]![row["lang"]] = row["title"]
        }
        return result
    }

    func getChapterTitles(inDomain domain: String) throws -> [String: LocalizedString] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT script.id, lang, title FROM chapter_title_v1 
                    LEFT JOIN script ON chapter_title_v1.script_grp_id = script.ref 
                    WHERE domain=? ORDER BY script.ref
                """,
                arguments: [domain]
            )
            return buildChapterTitleResult(from: rows)
        }
    }

    func getChapterTitles(forEntity id: String, inDomain domain: String) throws -> [String: LocalizedString] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT script.id, lang, title FROM chapter_title_v1 
                    LEFT JOIN script ON chapter_title_v1.script_grp_id = script.ref 
                    WHERE domain=? AND script.id=? ORDER BY script.ref, lang
                """,
                arguments: [domain, id]
            )
            return buildChapterTitleResult(from: rows)
        }
    }

    func getChapterTitles(forEntities ids: [String], inDomain domain: String) throws -> [String: LocalizedString] {
        try dbQueue.read { db in
            var params: [any DatabaseValueConvertible] = [domain]
            params.append(contentsOf: ids)
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT script.id, lang, title FROM chapter_title_v1 
                    LEFT JOIN script ON chapter_title_v1.script_grp_id = script.ref 
                    WHERE domain=? AND script.id IN (\(StringService.paramList(count: ids.count)))
                    ORDER BY script.ref, lang
                """,
                arguments: StatementArguments(params)
            )
            return buildChapterTitleResult(from: rows)
        }
    }
}