import Foundation
import GRDB

extension MasterDataService {
    func listSpecialStories() throws -> [SpecialStoryGroup] {
        var storyRecords = try dbQueue.read { db in
            var groups = [Int: SpecialStoryGroup]()

            for row in try Row.fetchAll(db.makeStatement(literal: """
                SELECT specialStoryId, episodeNo, scenarioId
                FROM specialStories_episodes
                ORDER BY specialStoryId DESC, episodeNo
            """)) {
                if groups[row["specialStoryId"]] == nil {
                    groups[row["specialStoryId"]] = SpecialStoryGroup(
                        id: row["specialStoryId"],
                        name: [:],
                        episodes: [],
                    )
                }

                groups[row["specialStoryId"]]!.episodes.append(Episode(id: 0,
                                                                       script: row["scenarioId"],
                                                                       name: [:],
                                                                       seqno: row["episodeNo"],
                                                                       characters: [], // unused by tsumi, and left empty here
                                                                       voice_bnd: "scenario/\(row["scenarioId"]!)",
                                                                       se_bnd: nil))
            }

            return [SpecialStoryGroup](groups.values.sorted { $0.id >= $1.id })
        }

        let names = try stringService.getGroupTitles(inDomain: "special_story")
        storyRecords.applyGroupTitles(names)

        let episodeNames = try stringService.getChapterTitles(inDomain: "special_story")
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
