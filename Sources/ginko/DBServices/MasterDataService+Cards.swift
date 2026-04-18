import Foundation
import GRDB

struct CardFilter: Codable {
    var character_id: CanonID?
    var rarity: SingleOrArray<CardRarity>?
    var attribute: SingleOrArray<CardAttribute>?
    var unit: CardUnit?
    var availability: SingleOrArray<CardClass>?
    var only_region: String?
}

private struct _CardEpList: Codable {
    let script: String
    let seq: Int
}

extension MasterDataService /* Cards */ {
    func listCards(matching query: CardFilter, after page: Int?, maxCount: Int = 20) throws -> ([CardStoryGroup], Bool) {
        var offset = page
        if offset == nil {
            if let only_region = query.only_region {
                if only_region != CanonicalLang {
                    offset = try stringService.latestTranslatedEntity(forLang: only_region, inDomain: "card") + 1
                } else {
                    offset = 999_999_999
                }
            } else {
                offset = 999_999_999
            }
        }

        var clauses: [SQL] = [SQL("cards.id < \(offset)")]

        if let unit = query.unit {
            let u = String(describing: unit)
            clauses.append(SQL("(cards.supportUnit=\(u) OR gameCharacterUnits.unit=\(u))"))
        }

        if let attribute = query.attribute {
            switch attribute {
            case let .single(t):
                clauses.append(SQL("cards.attr = \(String(describing: t))"))
            case let .array(t):
                clauses.append(SQL("cards.attr IN \(t.map { String(describing: $0) })"))
            }
        }

        if let rarity = query.rarity {
            switch rarity {
            case let .single(t):
                clauses.append(SQL("cards.cardRarityType = \(String(describing: t))"))
            case let .array(t):
                clauses.append(SQL("cards.cardRarityType IN \(t.map { String(describing: $0) })"))
            }
        }

        if let availability = query.availability {
            switch availability {
            case let .single(t):
                clauses.append(SQL("cards.cardSupplyId = \(t.rawValue)"))
            case let .array(t):
                clauses.append(SQL("cards.cardSupplyId IN \(t.map(\.rawValue))"))
            }
        }

        if let cmid = query.character_id {
            clauses.append("cards.characterId = \(cmid)")
        }

        var (cardBundles, hasMore) = try dbQueue.read { db in
            var rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT cardEpisodes.cardId, json_group_array(json_object('script', cardEpisodes.scenarioId, 'seq', cardEpisodes.seq)) AS epBnd,
                cards.assetbundleName, cards.characterId, 
                cards.cardRarityType, cards.supportUnit, cards.attr, cards.releaseAt,
                (cards.specialTrainingCosts IS NULL) as hasSpecialIdlz, cards.initialSpecialTrainingStatus,
                eventStories.id AS evtStoryId
                FROM cardEpisodes
                LEFT JOIN cards ON cardEpisodes.cardId = cards.id
                LEFT JOIN gameCharacterUnits ON cards.characterId = gameCharacterUnits.id
                LEFT JOIN eventCards ON (cards.id = eventCards.cardId AND eventCards.isDisplayCardStory > 0)
                LEFT JOIN eventStories ON (eventCards.eventId = eventStories.eventId)
                WHERE \(clauses.joined(operator: .and))
                GROUP BY cardEpisodes.cardId
                ORDER BY cards.id DESC, cardEpisodes.seq
                LIMIT \(maxCount + 1)
            """))
            var hasMore = false
            if rows.count > maxCount {
                hasMore = true
                _ = rows.popLast()
            }

            return (rows.map { row in
                let eps = try! JSONDecoder().decode([_CardEpList].self, from: row["epBnd"])
                return CardStoryGroup(id: row["cardId"],
                                      name: LocalizedString(),
                                      resource_name: row["assetbundleName"],
                                      release_date: Date(timeIntervalSince1970: row["releaseAt"] / 1000),
                                      episodes: eps.map {
                                          Episode(id: 0,
                                                  script: $0.script,
                                                  name: [:],
                                                  seqno: $0.seq,
                                                  characters: [],
                                                  voice_bnd: "card_scenario/\($0.script)",
                                                  se_bnd: nil)
                                      },
                                      character_id: row["characterId"],
                                      rarity: .fromMasterRepresentation(row["cardRarityType"]),
                                      attribute: .fromMasterRepresentation(row["attr"]),
                                      vs_affinity: .fromMasterRepresentation(row["supportUnit"]),
                                      idolization: row["hasSpecialIdlz"]
                                          ? (row["initialSpecialTrainingStatus"] == "not_doing" ? .notIdolizable : .preIdolized)
                                          : .idolizable,
                                      event_id: row["evtStoryId"],
                                      event_title: [:])
            }, hasMore)
        }

        try insertExtraInfo(into: &cardBundles)
        return (cardBundles, hasMore)
    }

    func getCards(matchingIDs: [CardID], includingEventInfo _: Bool) throws -> [CardStoryGroup] {
        var cardBundles = try dbQueue.read { db in
            let rows = try Row.fetchAll(db.makeStatement(literal: """
                SELECT cardEpisodes.cardId, json_group_array(json_object('script', cardEpisodes.scenarioId, 'seq', cardEpisodes.seq)) AS epBnd,
                cards.assetbundleName, cards.characterId, 
                cards.cardRarityType, cards.supportUnit, cards.attr, cards.releaseAt,
                (cards.specialTrainingCosts IS NULL) as hasSpecialIdlz, cards.initialSpecialTrainingStatus,
                eventStories.id AS evtStoryId
                FROM cardEpisodes
                LEFT JOIN cards ON cardEpisodes.cardId = cards.id
                LEFT JOIN gameCharacterUnits ON cards.characterId = gameCharacterUnits.id
                LEFT JOIN eventCards ON (cards.id = eventCards.cardId AND eventCards.isDisplayCardStory > 0)
                LEFT JOIN eventStories ON (eventCards.eventId = eventStories.eventId)
                WHERE cardEpisodes.cardId IN \(matchingIDs)
                GROUP BY cardEpisodes.cardId
                ORDER BY cards.id, cardEpisodes.seq
            """))

            return rows.map { row in
                let eps = try! JSONDecoder().decode([_CardEpList].self, from: row["epBnd"])
                return CardStoryGroup(id: row["cardId"],
                                      name: LocalizedString(),
                                      resource_name: row["assetbundleName"],
                                      release_date: Date(timeIntervalSince1970: row["releaseAt"] / 1000),
                                      episodes: eps.map {
                                          Episode(id: 0,
                                                  script: $0.script,
                                                  name: [:],
                                                  seqno: $0.seq,
                                                  characters: [],
                                                  voice_bnd: "card_scenario/\($0.script)",
                                                  se_bnd: nil)
                                      },
                                      character_id: row["characterId"],
                                      rarity: .fromMasterRepresentation(row["cardRarityType"]),
                                      attribute: .fromMasterRepresentation(row["attr"]),
                                      vs_affinity: .fromMasterRepresentation(row["supportUnit"]),
                                      idolization: row["hasSpecialIdlz"]
                                          ? (row["initialSpecialTrainingStatus"] == "not_doing" ? .notIdolizable : .preIdolized)
                                          : .idolizable,
                                      event_id: row["evtStoryId"],
                                      event_title: [:])
            }
        }

        try insertExtraInfo(into: &cardBundles)
        return cardBundles
    }

    private func insertExtraInfo(into cardBundles: inout [CardStoryGroup]) throws {
        let haveCardIds = cardBundles.map(\.id)
        let names = try stringService.getGroupTitles(forEntities: haveCardIds, inDomain: "card")
        cardBundles.applyGroupTitles(names)

        let events = try associatedEntityService.getEvents(forEntities: haveCardIds, inDomain: "card")
        let episodeChars = try associatedEntityService.getCharacters(forEntities: haveCardIds, inDomain: "card")

        for card in cardBundles {
            for evt in events {
                if card.id == evt.id {
                    card.event_title = evt.eventName
                    break
                }
            }
            if let sl = episodeChars[card.id] {
                for jdx in 0 ..< card.episodes.count {
                    for s in sl {
                        if s.script == card.episodes[jdx].script {
                            card.episodes[jdx].characters = s.characters
                        }
                    }
                }
            }
        }
    }
}
