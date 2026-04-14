import GRDB
import Foundation

extension MasterDataService /* Events */ {
    func listEventStories() throws -> [EventStoryGroup] {
        var stories = try dbQueue.read { db in
            let rows = try Row.fetchAll(try db.makeStatement(literal: """
                SELECT eventStories.id, events.assetbundleName, events.startAt,
                    json_group_object(eventStoryUnits.unit, eventStoryUnits.eventStoryUnitRelation) AS grel
                FROM eventStories
                LEFT JOIN events ON eventStories.eventId = events.id
                LEFT JOIN eventStoryUnits ON (eventStories.id = eventStoryUnits.eventStoryId)
                GROUP BY eventStories.id
                ORDER BY eventStories.id
            """))

            
            return rows.map { row in 
                var gr: [String: RelevanceType]? = nil
                if let groupRelevance: Data = row["grel"] {
                    gr = remapUnitCodes(try! JSONDecoder().decode([String: RelevanceType].self, from: groupRelevance))
                }

                return EventStoryGroup(id: row["id"], 
                    name: [:], 
                    description: [:], 
                    resource_name: row["assetbundleName"], 
                    release_date: Date(timeIntervalSince1970: row["startAt"] / 1000), 
                    episodes: [], 
                    group_relevance: gr ?? [:], 
                    assoc_cards: [])
            }
        }

        let names = try stringService.getGroupTitles(inDomain: "event")
        stories.applyGroupTitles(names)
        return stories
    }

    func getStoryGroup(forEvent id: EventID) throws -> EventStoryGroup? {
        let eventStory = try dbQueue.read { db -> EventStoryGroup? in
            let row = try Row.fetchOne(try db.makeStatement(literal: """
                SELECT eventStories.id, events.assetbundleName, events.startAt,
                    json_group_object(eventStoryUnits.unit, eventStoryUnits.eventStoryUnitRelation) AS grel
                FROM eventStories
                LEFT JOIN events ON eventStories.eventId = events.id
                LEFT JOIN eventStoryUnits ON (eventStories.id = eventStoryUnits.eventStoryId)
                WHERE eventStories.id=\(id)
                GROUP BY eventStories.id
            """))

            guard let row = row else {
                return nil
            }
            
            var gr: [String: RelevanceType]? = nil
            if let groupRelevance: Data = row["grel"] {
                gr = remapUnitCodes(try! JSONDecoder().decode([String: RelevanceType].self, from: groupRelevance))
            }

            let group = EventStoryGroup(id: row["id"], 
                name: [:], 
                description: [:], 
                resource_name: row["assetbundleName"], 
                release_date: Date(timeIntervalSince1970: row["startAt"] / 1000), 
                episodes: [], 
                group_relevance: gr ?? [:], 
                assoc_cards: [])
            
            let episodes = try Row.fetchAll(try db.makeStatement(literal: """
                SELECT scenarioId, title, episodeNo
                FROM eventStories_eventStoryEpisodes
                WHERE eventStoryId=\(id)
                ORDER BY eventStoryId, episodeNo
            """)).map { row in
                Episode(id: 0, 
                    script: row["scenarioId"], 
                    name: [:], 
                    seqno: row["episodeNo"], 
                    characters: [], // unused by tsumi, and left empty here
                    voice_bnd: "scenario/\(row["scenarioId"]!)", 
                    se_bnd: "eventsebnd/\(group.resource_name)")
            }
            group.episodes.append(contentsOf: episodes)
            return group
        }

        guard var eventStory = eventStory else {
            return nil
        }

        let names = try stringService.getGroupTitles(forEntity: eventStory.id, inDomain: "event")
        eventStory = eventStory.applyGroupTitles(names)

        let episodeNames = try stringService.getChapterTitles(forEntities: eventStory.episodes.map { $0.script }, inDomain: "event")
        for episode in eventStory.episodes {
            if let ls = episodeNames[episode.script] {
                episode.name = ls
            }
        }

        return eventStory
    }

    func collection(forEvent id: EventID) throws -> EventCollection? {
        guard let eventStory = try getStoryGroup(forEvent: id) else {
            return nil
        }

        var collection = EventCollection(event_id: id, event: eventStory, cards: [], area_conversations: [])
        var setlist: VirtualLiveSetlist? = nil
        var areaConversationIDs = [Int]()
        var cardIDs = [CardID]()

        for entity in try associatedEntityService.getEntities(associatedWithEvent: id) {
            if entity.domain == "card" {
                cardIDs.append(entity.id)
            } else if entity.domain == "area" {
                areaConversationIDs.append(entity.id)
            } else if entity.domain == "vlive" {
                setlist = try getSetlist(forVirtualLive: entity.id)
            }
        }

        collection.cards = try getCards(matchingIDs: cardIDs, includingEventInfo: true)
        collection.virtual_live = setlist
        collection.area_conversations = try getAreaConversations(matching: areaConversationIDs)
        return collection
    }
}
