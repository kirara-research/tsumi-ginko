import Vapor

struct VirtualLivesController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")

        pfx.get("virtual_lives.json", use: virtualLiveList)
        pfx.get("virtual_lives", ":id", use: virtualLiveSingle)
    }

    func virtualLiveList(req _: Request) async throws -> Response {
        let vll = try MasterDataService().listIndependentVirtualLives()

        return Response(status: .ok, headers: standardHeaders(),
                        body: Response.Body(data: try! jsonEncoder().encode(vll)))
    }

    func virtualLiveSingle(req: Request) async throws -> Response {
        let param = req.parameters.get("id")!
        if !param.hasSuffix(".json") {
            return error("Not found", status: .notFound)
        }

        guard let vliveID = Int(param.removing(suffix: ".json")) else {
            return error("invalid vlive ID", status: .notFound)
        }

        guard let vll = try MasterDataService().getSetlist(forVirtualLive: vliveID) else {
            return error("not found", status: .notFound)
        }

        return Response(status: .ok, headers: standardHeaders(),
                        body: Response.Body(data: try! jsonEncoder().encode(vll)))
    }
}
