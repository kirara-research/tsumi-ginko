import NIOFileSystem
import Vapor

struct DictionaryController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let pfx = routes.grouped("api", "v1", "story")
        pfx.get("dictionary", ":id", use: readDictionary)
    }

    private func error(_ message: String, status: HTTPStatus = .internalServerError) -> Response {
        let genericError = ["message": message]
        return Response(status: status, body: Response.Body(data: try! jsonEncoder().encode(genericError)))
    }

    func readDictionary(req: Request) async throws -> Response {
        guard req.parameters.get("id")!.firstMatch(of: /^([a-z_\-]+)\.json$/) != nil else {
            return error("Not found", status: .notFound)
        }

        let prefix = Environment.get("DATA_ROOT") ?? "./_data"
        let path = "\(prefix)/blobs/\(req.parameters.get("id")!)"
        if try await FileSystem.shared.info(forFileAt: FilePath(path)) != nil {
            return try await req.fileio.asyncStreamFile(at: "\(prefix)/blobs/\(req.parameters.get("id")!)", mediaType: .json)
        } else {
            return error("Not found", status: .notFound)
        }
    }
}
