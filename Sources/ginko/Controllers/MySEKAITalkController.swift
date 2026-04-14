import Vapor

struct TalkListResponse: Codable {
    let talks: [MySEKAITalk]
    let furniture_names: [Int: LocalizedString]
    let page_id: Int?
}

struct TalkSingleResponse: Codable {
    let talk: MySEKAITalk
    let related_talks: [MySEKAITalk]
    let furniture_names: [Int: LocalizedString]
}

struct MySEKAITalkController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("mysekai_talks.json", use: talkList)
        pfx.get("mysekai_talks", ":id", use: talkSingle)
    }

    func talkList(req: Request) async throws -> Response {
        var filter = MySEKAITalkFilter()

        if let fixture: Int = req.query["fixture"] {
            filter.fixture = fixture
        } else if let fixture_type: Int = req.query["fixture_type"] {
            filter.fixture_type = fixture_type
        }

        if let event_related: Bool = req.query["event_related"] {
            filter.event_related = event_related
        }
        if let weather_related: Bool = req.query["weather_related"] {
            filter.weather_related = weather_related
        } 
        if let visits_related: Bool = req.query["visits_related"] {
            filter.visits_related = visits_related
        }

        if let character_id: Int = req.query["character_id"] {
            filter.character_id = character_id
        }

        if let only_region: String = req.query["only_region"] {
            filter.only_region = only_region
        }

        var count: Int
        if let reqCount: Int = req.query["count"] {
            count = min(reqCount, 24)
        } else {
            count = 24
        }

        let (talks, fixNames, hasMore) = try MySEKAITalkService().listMySEKAITalk(
            matching: filter, after: req.query["after"], maxCount: count)
        let overallPageID = hasMore ? talks.min { $0.id < $1.id }.flatMap { $0.id } : nil

        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(TalkListResponse(talks: talks, furniture_names: fixNames, page_id: overallPageID))))
    }

    func talkSingle(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }

        guard let talkID = Int(param.removing(suffix: ".json")) else {
            return error("invalid talk ID", status: .notFound)
        }

        let res = try MySEKAITalkService().getMySEKAITalk(id: talkID)
        guard let (main, related, fixNames) = res else {
            return error("Not found", status: .notFound)
        }
    
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(TalkSingleResponse(talk: main, related_talks: related, furniture_names: fixNames))))
    }
}