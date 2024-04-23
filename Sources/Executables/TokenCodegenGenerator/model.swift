import Foundation

struct ColorInfo: Decodable {
    let type: String
    var value: String

    var rgba: RGBA? {
        try? parseHex(value)
    }
}

struct RGBA: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
}

typealias ColorData = [String: [String: ColorInfo]]

struct NumberInfo: Decodable, Comparable {
    let type: String
    let value: Double

    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        let valueString = try container.decode(String.self, forKey: .value)
        self.value = try parseNumber(valueString)
    }

    static func < (lhs: NumberInfo, rhs: NumberInfo) -> Bool {
        lhs.value < rhs.value
    }
}

typealias NumberData = [String: NumberInfo]
