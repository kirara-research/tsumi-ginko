import Vapor

struct PyProxyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // let pfx = routes.grouped("api", "v1", "story")

    }

    func proxy(req: Request) async throws -> Response {
        var url: String
        if let qs = req.url.query {
            url = "http://127.0.0.1:5000\(req.url.path)?\(qs)"
        } else {
            url = "http://127.0.0.1:5000\(req.url.path)"
        }

        print("URL forwarded to Python: \(url)")
        let resp = try await req.client.get(URI(string: url))
        return try await resp.encodeResponse(for: req)
    }
}