import Vapor
import Dispatch 

final class DatabaseInits: LifecycleHandler {
    nonisolated(unsafe) var signalSource: (any DispatchSourceSignal)? = nil

    func installSigHandler(_ code: Int32) {        
        let source = DispatchSource.makeSignalSource(signal: code, queue: DispatchQueue.main)
        source.setEventHandler {
            print("Reloading databases...")
            if let dataRoot = Environment.get("DATA_ROOT") {
                try! StoryDBHandle.initialize(path: "\(dataRoot)/story.db")
                try! MasterDBHandle.initialize(path: "\(dataRoot)/master.db")
            } else {
                try! StoryDBHandle.initialize(path: "./_data/story.db")
                try! MasterDBHandle.initialize(path: "./_data/master.db")
            }
        }
        source.resume()
        signalSource = source
    }

    // Called before application boots.
    func willBoot(_ app: Application) throws {
        if let dataRoot = Environment.get("DATA_ROOT") {
            try StoryDBHandle.initialize(path: "\(dataRoot)/story.db")
            try MasterDBHandle.initialize(path: "\(dataRoot)/master.db")
        } else {
            try StoryDBHandle.initialize(path: "./_data/story.db")
            try MasterDBHandle.initialize(path: "./_data/master.db")
        }

        installSigHandler(SIGHUP)
    }

    func shutdown(_ application: Application) {
        signalSource?.cancel()
    }
}

// configures your application
public func configure(_ app: Application) async throws {
    app.lifecycle.use(DatabaseInits())
    // uncomment to serve files from /Public folder
    //app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let origins = (Environment.get("TSUMI_ALLOWED_ORIGINS") ?? "*").components(separatedBy: ",")

    app.middleware.use(TsumiCORSMiddleware(patterns: origins), at: .beginning)

    // register routes
    try app.register(collection: PyProxyController())
    try app.register(collection: MySEKAITalkController())
    try app.register(collection: AreaConversationsController())
    try app.register(collection: VirtualLivesController())
    try app.register(collection: SpecialsController())
    try app.register(collection: UnitsController())
    try app.register(collection: EventsController())
    try app.register(collection: CardsController())
    try app.register(collection: DictionaryController())
    try app.register(collection: ScriptController())
    try routes(app)
}
