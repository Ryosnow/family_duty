import Foundation

enum ScoreValidationError: Error, Equatable, LocalizedError {
    case invalidScore

    var errorDescription: String? {
        switch self {
        case .invalidScore:
            return "得分必须是大于等于 1 的整数"
        }
    }
}

enum ScoreValidationService {
    static func validate(score: Int) throws {
        guard score >= 1 else { throw ScoreValidationError.invalidScore }
    }
}
