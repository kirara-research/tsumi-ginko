import Vapor

let CanonicalLang = "jp"

struct SearchResponse: Codable {
    let results: [SearchResult]
    let page_id: SearchResult.PageID
    let has_more: Bool
}

struct IncomingSearchQuery: Decodable {
    let lang: String
    let story_type: SingleOrArray<String>?
    let script_name_pattern: String?
    let speaker_name: String?
    let speaker: Speaker?
    let canon_id: Int?
    let text_query: String?
    let after_page_id: SearchResult.PageID?

    struct Speaker: Decodable {
        let idspace: String
        let id: Int

        init(from decoder: any Decoder) throws {
            var adec = try decoder.unkeyedContainer()
            let idspace = try adec.decode(String.self)
            let id = try adec.decode(Int.self)

            self.idspace = idspace
            self.id = id
        }
    }
}

struct ScriptController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")
        
        pfx.group("script") { script in 
            script.group(":id") { id in 
                id.get("languages.json", use: readScriptLanguages)
            }
            script.get(":id", use: readScript)
        }

        pfx.group("search") { search in
            search.on(.OPTIONS, "results.json") { req in
                Response(status: .noContent, headers: [
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type",
                    "Access-Control-Max-Age": "3600",
                ], body: .empty)
            }
            search.post("results.json", use: performSearch)            
        }
    }

    func readScript(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }
        let scriptId = param.removing(suffix: ".json")
        let langID: String = req.query["lang"] ?? CanonicalLang
        if langID.range(of: "^[a-z]+$", options: .regularExpression) == nil {
            return error("Invalid language ID.", status: .badRequest)
        }

        let script = try ScriptService().readScript(id: String(scriptId), fromRegion: langID)
        if script.lang == nil {
            return error("Could not find script for this language", status: .notFound)
        }

        let pl = try jsonEncoder().encode(script)
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(data: pl))
    }

    func readScriptLanguages(req: Request) async throws -> Response {
        let langids = try ScriptService().listScriptLangIDs(forScript: req.parameters.get("id")!)
        let pl = try jsonEncoder().encode(langids)
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(data: pl))
    }

    func performSearch(req: Request) async throws -> Response {
        guard let data = req.body.data else {
            return error("Body must be a JSON object.", status: .badRequest)
        }

        let decoder = JSONDecoder()
        guard let params = try? decoder.decode(IncomingSearchQuery.self, from: data) else {
            return error("Body must be a JSON object.", status: .badRequest)
        }

        var queryParams = SearchQuery(lang: "", story_type: nil, speaker_name: nil, speaker: nil, canon_id: nil, text_query: nil, after_page_id: nil, script_name_pattern: nil)
        var isQueryNarrowEnough = false

        guard params.lang.firstMatch(of: /^[a-z]+$/) != nil else {
            return error("Invalid language ID.", status: .badRequest)
        }
        queryParams.lang = params.lang

        if let storyType = params.story_type {
            switch (storyType) {
                case .array(let strings):
                    if strings.count > 0 {
                        queryParams.story_type = strings
                    }
                case .single(let string):
                    queryParams.story_type = [string]
            }
        }

        if let pattern = params.script_name_pattern {
            guard pattern.firstMatch(of: /^[\*a-z0-9_-]+$/) != nil else {
                return error("'script_name_pattern' is not valid", status: .badRequest)
            }
            
            guard pattern.firstMatch(of: /\*{2,}/) != nil else {
                return error("'script_name_pattern' is not valid", status: .badRequest)
            }
            
            queryParams.script_name_pattern = pattern
            isQueryNarrowEnough = true
        }

        if let speakerName = params.speaker_name {
            if !speakerName.isEmpty {
                queryParams.speaker_name = speakerName
                isQueryNarrowEnough = true
            }
        }

        if let speaker = params.speaker {
            queryParams.speaker = (speaker.idspace, speaker.id)
            isQueryNarrowEnough = true
        }

        if queryParams.speaker_name != nil && queryParams.speaker != nil {
            return error("'speaker' and 'speaker_name' cannot both be in the query", status: .badRequest)
        }

        if let canonId = params.canon_id {
            queryParams.canon_id = canonId
            isQueryNarrowEnough = true
        }

        if let textQuery = params.text_query, !textQuery.isEmpty {
            queryParams.text_query = textQuery
            isQueryNarrowEnough = true
        }

        if let afterPageId = params.after_page_id {
            queryParams.after_page_id = afterPageId
        }

        guard isQueryNarrowEnough else {
            return error("Query too broad. You must specify either a character or a text query.", status: .badRequest)
        }

        let scriptService = ScriptService()
        let (results, hasMore) = try scriptService.performSearch(queryParams)
        
        guard !results.isEmpty else {
            return error("No results.", status: .notFound)
        }

        let overallPageID = results.map { $0.page_id }.min()!
        let response = SearchResponse(results: results, page_id: overallPageID, has_more: hasMore)
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(data: try jsonEncoder().encode(response)))
    }
}