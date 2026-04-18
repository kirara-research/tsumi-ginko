import Foundation
import GRDB

class MasterDataService {
    let dbQueue: DatabaseQueue
    let stringService = StringService()
    let associatedEntityService = AssociatedEntityService()

    init(dbQueue: DatabaseQueue = MasterDBHandle.instance) {
        self.dbQueue = dbQueue
    }

    func getVersion() -> String {
        do {
            let ver = try dbQueue.read { db in
                let row = try Row.fetchOne(db.makeStatement(literal: """
                    SELECT version FROM _version
                """))
                if let row {
                    return String(row["version"])
                } else {
                    return "(unknown)"
                }
            }
            return "\(ver) @ ginko"
        } catch {
            return "(unknown) @ ginko"
        }
    }

    func remapUnitCodes(_ gr: [String: RelevanceType]) -> [String: RelevanceType] {
        var n: [String: RelevanceType] = [:]
        for key in gr.keys {
            if let remappedCode = CardUnit.fromMasterRepresentation(key) {
                n[remappedCode.rawValue] = gr[key]
            }
        }
        return n
    }
}
