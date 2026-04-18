import Vapor

struct PyProxyController: RouteCollection {
    func boot(routes _: any RoutesBuilder) throws {
        // let pfx = routes.grouped("api", "v1", "story")
    }

    func proxy(req: Request) async throws -> Response {
        let url = if let qs = req.url.query {
            "http://127.0.0.1:5000\(req.url.path)?\(qs)"
        } else {
            "http://127.0.0.1:5000\(req.url.path)"
        }

        print("URL forwarded to Python: \(url)")
        let resp = try await req.client.get(URI(string: url))
        return try await resp.encodeResponse(for: req)
    }
}
