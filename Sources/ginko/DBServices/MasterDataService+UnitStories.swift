import Foundation
import GRDB

extension MasterDataService {
    func listUnitStories() throws -> [UnitStoryGroup] {
        var storyRecords = try dbQueue.read { db in
            let rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT unitStoryEpisodeGroups.id, assetbundleName,
                    unitStoryEpisodeGroups.unit, unitStoryEpisodeGroups.unitEpisodeCategory
                FROM unitStoryEpisodeGroups
                LEFT JOIN unitProfiles ON unitStoryEpisodeGroups.unit = unitProfiles.unit
                ORDER BY unitProfiles.seq, unitStoryEpisodeGroups.id
            """))

            let groups = [Int: UnitStoryGroup](uniqueKeysWithValues: rows.map { row in
                var gr: [String: RelevanceType] = [:]
                if let u = CardUnit.fromMasterRepresentation(row["unit"]) {
                    gr[u.rawValue] = .key
                }
                if let u = CardUnit.fromMasterRepresentation(row["unitEpisodeCategory"]) {
                    if u != .none {
                        gr[u.rawValue] = .key
                    }
                }

                let group = UnitStoryGroup(id: row["id"],
                                           name: [:],
                                           description: [:],
                                           episodes: [],
                                           group_relevance: gr)
                return (row["id"], group)
            })

            for row in try Row.fetchAll(db.makeStatement(literal: """
                SELECT unitStoryEpisodeGroupId, scenarioId, episodeNo
                FROM unitStories_chapters_episodes
                ORDER BY unitStoryEpisodeGroupId, episodeNo
            """)) {
                guard let grp = groups[row["unitStoryEpisodeGroupId"]] else {
                    continue
                }
                grp.episodes.append(Episode(id: 0,
                                            script: row["scenarioId"],
                                            name: [:],
                                            seqno: row["episodeNo"],
                                            characters: [], // unused by tsumi, and left empty here
                                            voice_bnd: "scenario/\(row["scenarioId"]!)",
                                            se_bnd: nil))
            }

            return [UnitStoryGroup](groups.values.sorted { $0.id < $1.id })
        }

        let names = try stringService.getGroupTitles(forEntities: storyRecords.map(\.id), inDomain: "unit")
        storyRecords.applyGroupTitles(names)
        let allScripts = storyRecords.flatMap { $0.episodes.map(\.script) }

        let episodeNames = try stringService.getChapterTitles(forEntities: allScripts, inDomain: "unit")
        for rec in storyRecords {
            for episode in rec.episodes {
                if let ls = episodeNames[episode.script] {
                    episode.name = ls
                }
            }
        }

        return storyRecords
    }
}
