import FilenameMatcher
import Foundation
import Vapor

final class TsumiCORSMiddleware: Middleware, @unchecked Sendable {
    let patterns: [FilenameMatcher]

    init(patterns: [String]) {
        self.patterns = patterns.map {
            FilenameMatcher(pattern: $0, options: [])
        }
    }

    func respond(to request: Request, chainingTo next: any Responder) -> EventLoopFuture<Response> {
        next.respond(to: request).map { response in
            if let origin = request.headers.first(name: "Origin") {
                for pattern in self.patterns {
                    if pattern.match(filename: origin) {
                        response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: origin)
                        response.headers.replaceOrAdd(name: .accessControlExpose, value: "Tsumi-Master-Version, Tsumi-Omamori")
                        break
                    }
                }
            }

            response.headers.add(name: "Tsumi-Backend-ID", value: "ginko")
            return response
        }
    }
}
