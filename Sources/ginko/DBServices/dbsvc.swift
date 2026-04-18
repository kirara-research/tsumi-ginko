import GRDB
import GRDBSQLite
import Vapor

struct StoryDBHandle {
    private(set) nonisolated(unsafe) static var instance: DatabaseQueue!

    let handle: DatabaseQueue

    static func config() -> Configuration {
        var cfg = Configuration()
        cfg.readonly = true
        cfg.prepareDatabase { db in
            sqlite3_enable_load_extension(db.sqliteConnection, 1)
            sqlite3_load_extension(db.sqliteConnection, "./tsumi/lib/libfts5_icu_legacy.so", nil, nil)
            sqlite3_enable_load_extension(db.sqliteConnection, 0)
        }
        return cfg
    }

    static func initialize(path: String) throws {
        StoryDBHandle.instance = try DatabaseQueue(path: path, configuration: StoryDBHandle.config())
    }
}

struct MasterDBHandle {
    private(set) nonisolated(unsafe) static var instance: DatabaseQueue!

    let handle: DatabaseQueue

    static func config() -> Configuration {
        var cfg = Configuration()
        cfg.readonly = true
        return cfg
    }

    static func initialize(path: String) throws {
        MasterDBHandle.instance = try DatabaseQueue(path: path, configuration: MasterDBHandle.config())
    }
}
