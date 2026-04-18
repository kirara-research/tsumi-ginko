@testable import ginko
import Testing
import VaporTesting

@Suite("App Tests")
struct ginkoTests {
    @Test
    func `Hello World Route`() async throws {
        try await withApp(configure: configure) { app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            })
        }
    }
}
