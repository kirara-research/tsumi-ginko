import Foundation
import GRDB

struct LangID: Codable, FetchableRecord {
    let lang: String
    let title: String?
}

struct Line: Codable, FetchableRecord {
    let line_no: Int
    let verse_no: VerseID
    let speaker: Int
    let speaker_idspace: String
    let speaker_name: String?
    let content: String
    let voice_ref: String?
    let canon_id: Int?
    let canon_group: Int?
    let canon_name: String?

    enum VerseID: Codable {
        case int(Int)
        case float(Float)

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()

            let i = try container.decode(Float.self)
            if i == Float(Int(i)) {
                self = .int(Int(i))
            } else {
                self = .float(i)
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case let .int(intValue):
                try container.encode(intValue)
            case let .float(floatValue):
                try container.encode(floatValue)
            }
        }
    }
}

struct Script: Codable {
    static func empty(id: String, langs: [String]) -> Script {
        Script(id: id, lang: nil, source: nil, lines: [], available_languages: langs)
    }

    let id: String
    let lang: String?
    let source: String?
    let lines: [Line]
    let available_languages: [String]
}

struct SearchResultLine: Codable {
    let verse: Line.VerseID
    let text: String
    let speaker_name: String?
    let canon_id: Int?
    let canon_name: String?
}

struct SearchResult: Codable {
    let script_id: String
    let lang: String
    let script_type: String
    let group_type: String
    let group_id: Int
    let group_title: String?
    let episode_title: String?
    let matches: [SearchResultLine]
    let script_extra_param: Int?
    let page_id: PageID

    struct PageID: Comparable, Codable {
        let general_order: Int
        let ref: Int

        init(general_order: Int, ref: Int) {
            self.general_order = general_order
            self.ref = ref
        }

        static func < (lhs: SearchResult.PageID, rhs: SearchResult.PageID) -> Bool {
            if lhs.general_order < rhs.general_order {
                return true
            }
            if lhs.general_order == rhs.general_order {
                return lhs.ref < rhs.ref
            }
            return false
        }

        static func == (lhs: SearchResult.PageID, rhs: SearchResult.PageID) -> Bool {
            lhs.general_order == rhs.general_order && lhs.ref == rhs.ref
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode("\(general_order),\(ref)")
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            let ints = s.components(separatedBy: ",").map { Int($0) }

            guard ints.count == 2, ints[0] != nil, ints[1] != nil else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected two numbers"))
            }

            self.init(general_order: ints[0]!, ref: ints[1]!)
        }
    }
}

struct SearchQuery {
    var lang: String
    var story_type: [String]?
    var speaker_name: String?
    var speaker: (String, Int)?
    var canon_id: Int?
    var text_query: String?
    var after_page_id: SearchResult.PageID?
    var script_name_pattern: String?
}

class ScriptService {
    static let SearchResultsPerPage = 50
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = StoryDBHandle.instance) {
        self.dbQueue = dbQueue
    }

    private static func SearchQueryBaseWithTextSearch(lang: String) -> String {
        let quotedLang = "'\(lang)'"
        return """
            SELECT script.ref, script.general_order, script.id, script.type, 
                script.group_idspace, script.group_id,
                json_group_array(json_object(
                    'verse', text_search_v1_\(lang).verse_no,
                    'speaker_name', lines_v3_\(lang).speaker_name,
                    'canon_id', canon_link_v1.canon_id,
                    'canon_name', ll_ch_name.title,
                    'text', text_search_v1_\(lang).content)) AS linesbnd,
                chapter_title_v1.title AS ep_title, ll_group_name.title AS ch_title,
                script.search_disambiguator
            FROM text_search_v1_\(lang)  
            LEFT JOIN lines_v3_\(lang) ON (text_search_v1_\(lang).rowid = lines_v3_\(lang).rowid)
            LEFT JOIN script ON (lines_v3_\(lang).script_ref = script.ref)
            LEFT JOIN canon_link_v1 USING (speaker, speaker_idspace)
            LEFT JOIN chapter_title_v1 ON (chapter_title_v1.script_grp_id = script.ref 
                AND chapter_title_v1.lang = \(quotedLang))
            LEFT JOIN group_title_v1 AS ll_group_name ON (ll_group_name.id = script.group_id 
                AND ll_group_name.lang = \(quotedLang) AND ll_group_name.domain = script.group_idspace)
            LEFT JOIN group_title_v1 AS ll_ch_name ON (canon_link_v1.canon_id = ll_ch_name.id 
                AND ll_ch_name.lang = \(quotedLang) AND ll_ch_name.domain = 'canon_character')
            WHERE ?params?
            GROUP BY text_search_v1_\(lang).script_ref
            ORDER BY script.general_order DESC, script.ref DESC
            LIMIT 51
        """
    }

    private static func SearchQueryBaseWithoutTextSearch(lang: String) -> String {
        let quotedLang = "'\(lang)'"
        return """
            SELECT script.ref, script.general_order, script.id, script.type, 
                script.group_idspace, script.group_id,
                json_group_array(json_object(
                    'verse', lines_v3_\(lang).verse_no,
                    'speaker_name', lines_v3_\(lang).speaker_name,
                    'canon_id', canon_link_v1.canon_id,
                    'canon_name', ll_ch_name.title,
                    'text', lines_v3_\(lang).content)) AS linesbnd,
                chapter_title_v1.title AS ep_title, ll_group_name.title AS ch_title,
                script.search_disambiguator
            FROM lines_v3_\(lang)
            LEFT JOIN script ON (lines_v3_\(lang).script_ref = script.ref)
            LEFT JOIN canon_link_v1 USING (speaker, speaker_idspace)
            LEFT JOIN chapter_title_v1 ON (chapter_title_v1.script_grp_id = script.ref 
                AND chapter_title_v1.lang = \(quotedLang))
            LEFT JOIN group_title_v1 AS ll_group_name ON (ll_group_name.id = script.group_id 
                AND ll_group_name.lang = \(quotedLang) AND ll_group_name.domain = script.group_idspace)
            LEFT JOIN group_title_v1 AS ll_ch_name ON (canon_link_v1.canon_id = ll_ch_name.id 
                AND ll_ch_name.lang = \(quotedLang) AND ll_ch_name.domain = 'canon_character')
            WHERE ?params?
            GROUP BY lines_v3_\(lang).script_ref
            ORDER BY script.general_order DESC, script.ref DESC
            LIMIT 51
        """
    }

    func listScriptLangIDs(forScript script_id: String) throws -> [LangID] {
        try dbQueue.read { db in
            try LangID.fetchAll(db, sql: """
                SELECT script_source_v1.lang, chapter_title_v1.title FROM script_source_v1
                LEFT JOIN script ON script_source_v1.script_grp_id = script.ref
                LEFT JOIN chapter_title_v1 ON script_source_v1.script_grp_id = chapter_title_v1.script_grp_id 
                    AND script_source_v1.lang=chapter_title_v1.lang
                WHERE script.id = ?
            """, arguments: [script_id])
        }
    }

    func readScript(id script_id: String, fromRegion lang_id: String) throws -> Script {
        let langs = try listScriptLangIDs(forScript: script_id).map(\.lang)

        if !langs.contains(lang_id) {
            return Script.empty(id: script_id, langs: langs)
        }

        let lines = try dbQueue.read { db in
            try Line.fetchAll(db, sql: """
                SELECT 
                    seq_no AS line_no, verse_no, speaker, speaker_idspace, speaker_name, 
                    content, voice_ref, canon_link_v1.canon_id AS canon_id,
                    canon_grp AS canon_group, group_title_v1.title AS canon_name
                FROM lines_v3_\(lang_id) 
                LEFT JOIN script ON (lines_v3_\(lang_id).script_ref = script.ref)
                LEFT JOIN canon_link_v1 USING (speaker, speaker_idspace)
                LEFT JOIN group_title_v1 ON (group_title_v1.id=canon_link_v1.canon_id 
                    AND group_title_v1.domain='canon_character' AND group_title_v1.lang=?)
                WHERE script.id = ? ORDER BY seq_no
            """, arguments: [lang_id, script_id])
        }

        return Script(id: script_id, lang: lang_id, source: "<ginko>", lines: lines, available_languages: langs)
    }

    private static func paramList(count: Int) -> String {
        [String](repeating: "?", count: count).joined(separator: ", ")
    }

    private static func reassembleQuoted(_ words: [String]) -> [String] {
        var buf = [String]()
        var qbuf = [String]()
        var quote = false

        for w in words {
            if quote {
                if w.hasSuffix("\"") {
                    qbuf.append(String(w.dropLast()))
                    buf.append(qbuf.joined(separator: " "))
                    qbuf = []
                    quote = false
                    continue
                }
                qbuf.append(w)
            } else {
                if w.hasPrefix("\"") {
                    qbuf.append(String(w.dropFirst()))
                    quote = true
                    continue
                }
                buf.append(w)
            }
        }

        if !qbuf.isEmpty {
            buf.append(qbuf.joined(separator: " "))
        }

        return buf
    }

    func performSearch(_ query: SearchQuery) throws -> ([SearchResult], Bool) {
        var usingFT = false

        var clauses = [String]()
        var bindings = [any DatabaseValueConvertible]()

        let langTable = "lines_v3_\(query.lang)"

        clauses.append("\(langTable).verse_no != 0")
        if let typ = query.story_type {
            if typ.count == 1 {
                clauses.append("script.group_idspace = ?")
                bindings.append(typ[0])
            } else {
                clauses.append("script.group_idspace IN (\(ScriptService.paramList(count: typ.count)))")
                bindings.append(contentsOf: typ)
            }
        }

        if let spkn = query.speaker_name {
            clauses.append("LOWER(\(langTable).speaker_name) = ?")
            bindings.append(spkn)
        }

        if let speaker = query.speaker {
            clauses.append(
                "\(langTable).speaker_idspace = ? AND \(langTable).speaker = ?",
            )
            bindings.append(speaker.0)
            bindings.append(speaker.1)
        }

        if let canon = query.canon_id {
            clauses.append("canon_link_v1.canon_id = ?")
            bindings.append(canon)
        }

        if let namepat = query.script_name_pattern {
            clauses.append("script.id LIKE ?")
            bindings.append(namepat.replacing("*", with: "%"))
        }

        if let nextpageid = query.after_page_id {
            clauses.append("(script.general_order, script.ref) < (?, ?)")
            bindings.append(nextpageid.general_order)
            bindings.append(nextpageid.ref)
        }

        if let ft = query.text_query {
            usingFT = true
            let words = ScriptService.reassembleQuoted(ft.components(separatedBy: " "))

            var ftsMatch: String
            if words.count > 10 {
                let phrase = words.joined(separator: " ").replacing("\"", with: "\"\"")
                ftsMatch = "\"\(phrase)\""
            } else if words.count > 1 {
                let words = words.map { "\"\($0.replacing("\"", with: "\"\""))\"" }
                ftsMatch = "NEAR(\(words.joined(separator: " ")))"
            } else {
                ftsMatch = "\"\(words[0].replacing("\"", with: "\"\""))\""
            }

            clauses.append("text_search_v1_\(query.lang).content MATCH ?")
            bindings.append(ftsMatch)
        }

        var hasNext = false
        var rows = try dbQueue.read { db in
            let query = usingFT ? ScriptService.SearchQueryBaseWithTextSearch(lang: query.lang)
                : ScriptService.SearchQueryBaseWithoutTextSearch(lang: query.lang)
            return try Row.fetchAll(db, sql: query.replacing("?params?", with: clauses.joined(by: " AND ")),
                                    arguments: StatementArguments(bindings))
        }

        if rows.count > ScriptService.SearchResultsPerPage {
            _ = rows.popLast()
            hasNext = true
        }

        return (rows.map { row in
            let d = try! JSONDecoder().decode([SearchResultLine].self, from: row["linesbnd"])
            return SearchResult(
                script_id: row["id"],
                lang: query.lang,
                script_type: row["type"],
                group_type: row["group_idspace"],
                group_id: row["group_id"],
                group_title: row["ch_title"],
                episode_title: row["ep_title"],
                matches: d,
                script_extra_param: row["search_disambiguator"],
                page_id: SearchResult.PageID(general_order: row["general_order"], ref: row["ref"]),
            )
        }, hasNext)
    }
}
