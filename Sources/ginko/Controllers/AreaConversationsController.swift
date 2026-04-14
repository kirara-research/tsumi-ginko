import Vapor

struct AreaConversationListResponse: Codable {
    let area_conversations: [AreaConversation]
    let page_id: Int?
}
struct AreaConversationResponse: Codable {
    let area_conversation: AreaConversation
    let related_area_conversation: [AreaConversation]
}

struct AreaConversationsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("area_conversations.json", use: areaConvList)
        pfx.get("area_conversations", ":id", use: areaConvSingle)
    }

    func areaConvList(req: Request) async throws -> Response {
        var filter = AreaConversationFilter()

        if let characters: [Int] = req.query.getCommaSeparatedValues(forKey: "character_ids"), !characters.isEmpty {
            filter.character_ids = [CanonID](characters.prefix(2))
        }

        if let area: Int = req.query["area"] {
            filter.area = area
        }

        if let secret: Bool = req.query["secret"] {
            filter.secret = secret
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

        let (convs, hasMore) = try MasterDataService().listAreaConversations(
            matching: filter, after: req.query["after"], maxCount: count)
        let overallPageID = hasMore ? convs.min { $0.id < $1.id }.flatMap { $0.id } : nil

        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(AreaConversationListResponse(area_conversations: convs, page_id: overallPageID))))
    }

    func areaConvSingle(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }

        guard let convID = Int(param.removing(suffix: ".json")) else {
            return error("invalid conversation ID", status: .notFound)
        }

        guard let (primary, related) = try MasterDataService().getAreaConversations(relatedTo: convID) else {
            return error("Not found", status: .notFound)
        }
    
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(AreaConversationResponse(area_conversation: primary, related_area_conversation: related))))
    }
}