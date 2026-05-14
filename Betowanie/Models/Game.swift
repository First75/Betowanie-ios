import Foundation

struct Game: Identifiable, Codable {
    let id: Int
    let homeTeamName: String
    let awayTeamName: String
    let homeTeamIcon: String
    let awayTeamIcon: String
    let fullTimeScore: Score?
    let regularTimeScore: Score?
    let stage: GameStage
    let status: GameStatus
    let timestamp: Double

    var date: Date {
        Date(timeIntervalSince1970: timestamp / 1000)
    }

    var isUpcoming: Bool {
        status == .timed || status == .scheduled
    }

    var isFinished: Bool {
        status == .finished
    }

    var isLive: Bool {
        status == .inPlay || status == .live || status == .paused
    }

    var displayScore: String {
        guard let score = fullTimeScore else { return "– : –" }
        return "\(score.home) - \(score.away)"
    }

    var winner: WinnerResult? {
        fullTimeScore?.winner
    }
}

struct Score: Codable {
    let home: Int
    let away: Int
    let winner: WinnerResult?
}

enum GameStage: String, Codable, CaseIterable {
    case regularSeason = "REGULAR_SEASON"
    case groupStage = "GROUP_STAGE"
    case roundOf16 = "LAST_16"
    case quarterFinals = "QUARTER_FINALS"
    case semiFinals = "SEMI_FINALS"
    case final_ = "FINAL"

    // Custom decoding to handle "FINALS" alias from bets data
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if raw == "FINALS" {
            self = .final_
        } else if let stage = GameStage(rawValue: raw) {
            self = stage
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown stage: \(raw)")
            )
        }
    }

    var displayName: String {
        switch self {
        case .regularSeason: return "Sezon zasadniczy"
        case .groupStage: return "Faza grupowa"
        case .roundOf16: return "1/8 finału"
        case .quarterFinals: return "Ćwierćfinał"
        case .semiFinals: return "Półfinał"
        case .final_: return "Finał"
        }
    }

    var pointMultiplier: Int {
        // Currently all stages have the same multiplier.
        // Adjust per-stage if the rules change in the future.
        1
    }
}

enum GameStatus: String, Codable {
    case timed = "TIMED"
    case scheduled = "SCHEDULED"
    case live = "LIVE"
    case inPlay = "IN_PLAY"
    case paused = "PAUSED"
    case finished = "FINISHED"
    case postponed = "POSTPONED"
    case suspended = "SUSPENDED"
    case cancelled = "CANCELLED"
}

enum WinnerResult: String, Codable {
    case homeTeam = "HOME_TEAM"
    case awayTeam = "AWAY_TEAM"
    case draw = "DRAW"

    func displayName(homeTeamName: String, awayTeamName: String) -> String {
        switch self {
        case .homeTeam: return homeTeamName
        case .awayTeam: return awayTeamName
        case .draw: return "Remis"
        }
    }
}
