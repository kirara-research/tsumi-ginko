import Vapor
extension RouteCollection {
    func standardHeaders() -> HTTPHeaders {
        return [
            "Content-Type": "application/json; charset=utf-8",
            "Tsumi-Master-Version": MasterDataService().getVersion(),
        ]
    }

    func error(_ message: String, status: HTTPStatus = .internalServerError) -> Response {
        let genericError = ["message": message]
        return Response(status: status, body: Response.Body(data: try! jsonEncoder().encode(genericError)))
    }

    func jsonEncoder() -> JSONEncoder {
        let coder = JSONEncoder()
        coder.dateEncodingStrategy = .iso8601
        coder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return coder
    }
}

extension String {
    func removing(suffix: String) -> String {
        if !self.hasSuffix(suffix) {
            return self
        }
        return String(self[...self.index(self.endIndex, offsetBy: -(suffix.count + 1))])
    }
}

protocol FromString {
    init?(_ string: String)
}
extension Int: FromString {}
extension String: FromString {}
extension URLQueryContainer {
    func getCommaSeparatedValues<T: FromString>(forKey key: String) -> [T]? {
        guard let v: String = self[key] else {
            return nil
        }

        let arr: [T?] = v.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { T($0) }
        return arr.compactMap { $0 }
    }
}