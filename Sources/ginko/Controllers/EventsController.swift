import Vapor

struct EventsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("events.json", use: eventList)
        pfx.get("events", ":id", use: eventCollection)
    }

    func eventList(req: Request) async throws -> Response {
        let eventStories = try MasterDataService().listEventStories()

        return Response(status: .ok, headers: standardHeaders(),
            body: Response.Body(data: try! jsonEncoder().encode(eventStories)))
    }

    func eventCollection(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }

        guard let eventID = Int(param.removing(suffix: ".json")) else {
            return error("invalid event ID", status: .notFound)
        }

        let eventCollection = try MasterDataService().collection(forEvent: eventID)
        guard let eventCollection = eventCollection else {
            return error("Not found", status: .notFound)
        }
    
        return Response(status: .ok, headers: standardHeaders(), 
            body: Response.Body(data: try! jsonEncoder().encode(eventCollection)))
    }
}