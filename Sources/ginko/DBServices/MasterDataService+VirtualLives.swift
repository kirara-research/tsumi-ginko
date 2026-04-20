import Foundation
import GRDB

extension MasterDataService /* Virtual Live */ {
    func listIndependentVirtualLives() throws -> [VirtualLiveSetlist] {
        var vlsets = try dbQueue.read { db in
            let rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT DISTINCT virtualLives.id, virtualLives.assetbundleName,
                    virtualLives.startAt
                FROM virtualLives_virtualLiveSetlists
                LEFT JOIN virtualLives ON virtualLives.id = virtualLives_virtualLiveSetlists.virtualLiveId
                LEFT JOIN events ON virtualLives.id = events.virtualLiveId
                WHERE virtualLives_virtualLiveSetlists.virtualLiveSetlistType 
                    IN ('mc', 'mc_timeline', 'virtual_message') 
                    AND events.id IS NULL
                ORDER BY virtualLives.startAt
            """))

            return rows.map { row in
                VirtualLiveSetlist(id: row["id"],
                                   name: [:],
                                   description: [:],
                                   resource_name: row["assetbundleName"],
                                   release_date: Date(timeIntervalSince1970: row["startAt"] / 1000),
                                   episodes: [])
            }
        }

        let haveIds = vlsets.map(\.id)
        let names = try stringService.getGroupTitles(forEntities: haveIds, inDomain: "vlive")
        vlsets.applyGroupTitles(names)
        return vlsets
    }

    func getSetlist(forVirtualLive id: Int) throws -> VirtualLiveSetlist? {
        var needBroadcastMusicCharacters: [Int: [MusicPerformance]] = [:]
        var needBroadcastMusicTitles: [Int: [MusicPerformance]] = [:]

        let setlist = try dbQueue.read { db -> VirtualLiveSetlist? in
            let rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT virtualLives.id, virtualLives.assetbundleName AS banner, virtualLiveSetlistType, 
                    virtualLives_virtualLiveSetlists.assetbundleName AS epSId,
                    musicId, musicVocalId, virtualLives_virtualLiveSetlists.seq,
                    virtualLives.startAt
                FROM virtualLives
                LEFT JOIN virtualLives_virtualLiveSetlists ON virtualLives.id = virtualLives_virtualLiveSetlists.virtualLiveId
                WHERE virtualLives.id = \(id)
                ORDER BY virtualLives_virtualLiveSetlists.seq
            """))

            guard !rows.isEmpty else {
                return nil
            }

            let rowFirst = rows[0]
            let group = VirtualLiveSetlist(id: rowFirst["id"],
                                           name: [:],
                                           description: [:],
                                           resource_name: rowFirst["banner"],
                                           release_date: Date(timeIntervalSince1970: rowFirst["startAt"] / 1000),
                                           episodes: [])

            group.episodes = rows.map { row in
                if ["mc", "mc_timeline", "virtual_message"].contains(row["virtualLiveSetlistType"]) {
                    return .script(Episode(id: 0, script: row["epSId"], name: [:], seqno: row["seq"], characters: [], voice_bnd: "vlmc/\(row["epSId"]!)", se_bnd: nil))
                } else {
                    let t = MusicPerformance(id: 0, music_group: row["musicId"], music_vocal: row["musicVocalId"], seqno: row["seq"])
                    needBroadcastMusicTitles[row["musicId"], default: []].append(t)
                    needBroadcastMusicCharacters[row["musicVocalId"], default: []].append(t)
                    return .music(t)
                }
            }
            
            if !needBroadcastMusicCharacters.isEmpty {
                let characters = try Row.fetchAll(db.makeStatement(literal: """
                    SELECT musicVocals.id, musicVocals.musicId, musicVocalType, 
                        json_group_array(json_object('id', characterId, 'unit', 0)) AS charbnd
                    FROM musicVocals
                    LEFT JOIN musicVocals_characters ON (musicVocals.characters = musicVocals_characters._link)
                    WHERE musicVocals.id IN \(needBroadcastMusicCharacters.keys) AND characterType='game_character'
                    GROUP BY musicVocals.id
                """))

                for row in characters {
                    let cl = try! JSONDecoder().decode([UnitAssociatedCharacter].self, from: row["charbnd"])
                    for p in needBroadcastMusicCharacters[row["id"], default: []] {
                        p.characters = cl
                    }
                }
            }

            return group
        }

        guard var setlist else {
            return nil
        }

        let names = try stringService.getGroupTitles(forEntity: setlist.id, inDomain: "vlive")
        setlist = setlist.applyGroupTitles(names)

        for (key, value) in try stringService.getGroupTitles(forEntities: [Int](needBroadcastMusicTitles.keys), inDomain: "music") {
            for p in needBroadcastMusicTitles[key, default: []] {
                p.music_title = value.name
                for (lang, fp) in value.description {
                    guard let fp else {
                        continue
                    }

                    let brk = fp.components(separatedBy: "\u{e067}")
                    p.music_lyricist[lang] = brk[0]
                    p.music_composer[lang] = brk[1]
                    p.music_arranger[lang] = brk[2]
                }
            }
        }

        return setlist
    }
}
