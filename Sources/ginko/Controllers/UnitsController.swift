import Vapor

struct UnitsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("units.json", use: unitStoryList)
    }

    func unitStoryList(req: Request) async throws -> Response {
        let unitStories = try MasterDataService().listUnitStories()

        return Response(status: .ok, headers: standardHeaders(),
            body: Response.Body(data: try! jsonEncoder().encode(unitStories)))
    }
}