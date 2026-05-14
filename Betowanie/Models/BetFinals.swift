import Foundation

struct TeamBet: Codable, Hashable {
    let teamId: String
    let teamName: String

    private enum CodingKeys: String, CodingKey {
        case teamId, teamName
    }

    init(teamId: String, teamName: String) {
        self.teamId = teamId
        self.teamName = teamName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamName = try container.decode(String.self, forKey: .teamName)

        if let stringId = try? container.decode(String.self, forKey: .teamId) {
            teamId = stringId
        } else if let intId = try? container.decode(Int.self, forKey: .teamId) {
            teamId = String(intId)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.teamId],
                    debugDescription: "Expected teamId as String or Int"
                )
            )
        }
    }
}

struct BetFinals: Codable, Identifiable {
    var id: String { "\(userId)_finals" }
    let userId: String
    let username: String
    let teamBet: [TeamBet]

    private enum CodingKeys: String, CodingKey {
        case userId, username, teamBet
    }
}
