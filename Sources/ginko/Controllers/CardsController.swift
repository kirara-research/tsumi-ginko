import Vapor

struct CardListResponse: Codable {
    let cards: [CardStoryGroup]
    let page_id: CardID?
}

struct CardsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("cards.json", use: cardList)
        pfx.get("cards", ":id", use: cardSingle)
    }

    func cardList(req: Request) async throws -> Response {
        var filter = CardFilter()
        
        if let unit: String = req.query["unit"] {
            if let unit = CardUnit(rawValue: unit) {
                filter.unit = unit
            } else {
                return error("unit is invalid", status: .badRequest)
            } 
        }

        if let attribute: [CardAttribute] = req.query.getCommaSeparatedValues(forKey: "attribute")?.compactMap({ CardAttribute(rawValue: $0) }) {
            filter.attribute = .fromArray(attribute)
        }

        if let rarity: [CardRarity] = req.query.getCommaSeparatedValues(forKey: "rarity")?.compactMap({ CardRarity(rawValue: $0) }) {
            filter.rarity = .fromArray(rarity)
        }

        if let availability: [CardClass] = req.query.getCommaSeparatedValues(forKey: "availability")?.compactMap({ CardClass(rawValue: $0) }) {
            filter.availability = .fromArray(availability)
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

        let (cards, hasMore) = try MasterDataService().listCards(
            matching: filter, after: req.query["after"], maxCount: count)
        let overallPageID = hasMore ? cards.min { $0.id < $1.id }.flatMap { $0.id } : nil

        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(CardListResponse(cards: cards, page_id: overallPageID))))
    }

    func cardSingle(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }

        guard let cardID = Int(param.removing(suffix: ".json")) else {
            return error("invalid card ID", status: .notFound)
        }

        let cards = try MasterDataService().getCards(matchingIDs: [cardID], includingEventInfo: true)
        guard !cards.isEmpty else {
            return error("Not found", status: .notFound)
        }
    
        return Response(status: .ok, headers: standardHeaders(), body: Response.Body(
            data: try! jsonEncoder().encode(cards[0])))
    }
}