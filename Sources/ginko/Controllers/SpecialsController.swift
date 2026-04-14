import Vapor

struct SpecialsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("specials.json", use: specialStoryList)
    }

    func specialStoryList(req: Request) async throws -> Response {
        let specialStories = try MasterDataService().listSpecialStories()

        return Response(status: .ok, headers: standardHeaders(),
            body: Response.Body(data: try! jsonEncoder().encode(specialStories)))
    }
}