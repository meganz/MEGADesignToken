import Foundation

enum ParseInputError: Equatable, Error {
    case wrongArguments
}

/// Parses a pseudo-array formatted string to extract and validate the file path for the tokens.
///
/// The function expects the input string to be formatted as a pseudo-array containing a single path like so:
/// "[Path/To/tokens.json]"
///
/// - Parameter input: The input string formatted as a pseudo-array.
/// - Returns: A `URL` containing the parsed and validated path.
/// - Throws: A `ParseInputError` if the number of arguments is incorrect or if the path does not contain the expected file name.
func parseInput(_ input: String) throws -> URL {
    let parsed = input
        .replacingOccurrences(of: "[\\[\\]]", with: "", options: .regularExpression, range: nil)
        .split(separator: ",")
        .map {
            String($0)
                .trimmingCharacters(in: .whitespaces)
        }

    guard parsed.count == 1, let tokensPath = parsed.first, tokensPath.contains(ExpectedInput.tokens.rawValue) else {
        throw ParseInputError.wrongArguments
    }

    return URL(fileURLWithPath: tokensPath)
}

enum HexDecodingError: Error {
    case invalidInputCharacters
    case invalidInputLength
}

/// Parses a given hexadecimal color string into a struct containing normalized RGBA values.
///
/// - Parameters:
///    - hexString: A string in one of the following formats: `#c4320a`, `c4320a`, `#c4320aff`, or `c4320aff`.
///
/// - Returns: A struct representing normalized RGBA values of type `RGBA`.
///
/// - Throws: `HexDecodingError.invalidInputCharacters` if the string contains invalid hexadecimal characters.
///           `HexDecodingError.invalidInputLength` if the string does not conform to expected length specifications (6 or 8 characters excluding the '#').
func parseHex(_ hexString: String) throws -> RGBA {
    var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    guard hexSanitized.rangeOfCharacter(from: hexSet.inverted) == nil else {
        throw HexDecodingError.invalidInputCharacters
    }

    guard hexSanitized.count == 6 || hexSanitized.count == 8 else {
        throw HexDecodingError.invalidInputLength
    }

    var rgba: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgba)

    let isAlphaChannelHex = hexSanitized.count == 8

    let red = CGFloat((rgba >> (isAlphaChannelHex ? 24 : 16)) & 0xff) / 255.0
    let green = CGFloat((rgba >> (isAlphaChannelHex ? 16 : 8)) & 0xff) / 255.0
    let blue = CGFloat((rgba >> (isAlphaChannelHex ? 8 : 0)) & 0xff) / 255.0
    let alpha = isAlphaChannelHex ? CGFloat(rgba & 0xff) / 255.0 : 1.0

    return RGBA(red: red, green: green, blue: blue, alpha: alpha)
}

enum NumberDecodingError: Error {
    case invalidInput
}

/// Parses a string containing a numerical value potentially suffixed with 'px' into a Double.
///
/// - Parameter numberString: The string to parse, e.g., '100px' or '100'.
/// - Returns: The numerical value as a Double.
/// - Throws: `NumberDecodingError.invalidInput` if the string cannot be converted to a Double.
func parseNumber(_ numberString: String) throws -> Double {
    let sanitized = numberString.replacingOccurrences(of: "px", with: "")

    guard let doubleValue = Double(sanitized) else {
        throw NumberDecodingError.invalidInput
    }

    return doubleValue
}

private let decoder = JSONDecoder()

/// Parses a given JSON dictionary to a flat structure containing color information.
///
/// - Parameters:
///   - colorsInformation: A dictionary with a string key and `Any` matching the expected `JSON` structure.
///     The JSON should resemble a nested key-value pair where the value can be either another dictionary,
///     or a dictionary containing color information (`ColorInfo`).
///
///     Example for the expected `JSON` structure - **NOTE**: It can be indefinitely nested.
/// ```
/// {
///     "Black opacity": {
///         "090": {
///             "type": "color",
///             "value": "#000000e6"
///         }
///      },
///     "Secondary": {
///         "Orange": {
///             "100": {
///                 "type": "color",
///                 "value": "#ffead5"
///             }
///         }
///     }
/// }
/// ```
///   - path: The current nested path as a string, used for recursion. Defaults to an empty string.
///
/// - Returns: A dictionary of type `[String: ColorInfo]` containing the flattened color information.
///
/// - Complexity: Let n be the total number of keys in the input JSON object, including all nested keys - O(n)
func extractFlatColorData(from jsonObject: [String: Any], path: String = "") throws -> [String: ColorInfo] {
    var flatMap: [String: ColorInfo] = [:]

    for (key, value) in jsonObject {
        let fullPath = (path.isEmpty ? key : "\(path).\(key)").lowercased()

        if let innerDict = value as? [String: Any],
           innerDict["type"] as? String != nil,
           innerDict["value"] as? String != nil {

            let jsonData = try JSONSerialization.data(withJSONObject: value, options: [])
            let colorInfo = try decoder.decode(ColorInfo.self, from: jsonData)
            flatMap[fullPath] = colorInfo

        } else if let innerDict = value as? [String: Any] {
            let nestedMap = try extractFlatColorData(from: innerDict, path: fullPath)
            flatMap.merge(nestedMap) { _, new in new }
        }
    }

    return try resolveNestedFlatColorData(in: flatMap)
}

private func resolveNestedFlatColorData(in map: [String: ColorInfo]) throws -> [String: ColorInfo] {
    var updatedMap = map
    for (key, colorInfo) in map {
        updatedMap[key] = try resolveColorInfo(for: colorInfo, from: updatedMap)
    }
    return updatedMap
}

private func resolveColorInfo(for colorInfo: ColorInfo, from map: [String: ColorInfo]) throws -> ColorInfo {
    guard colorInfo.rgba == nil, colorInfo.value.starts(with: "{Colors.") else { return colorInfo }

    let sourceColorKey = colorInfo.value
        .replacingOccurrences(of: "{Colors.", with: "")
        .replacingOccurrences(of: "}", with: "")
        .lowercased()

    guard let sourceColor = map[sourceColorKey] else { return colorInfo }

    return try resolveColorInfo(for: sourceColor, from: map)
}

enum ExtractColorDataError: Error {
    case inputIsWrong(reason: String)
}

/// Parses a given JSON dictionary to a nested structure containing semantic color information.
///
/// - Parameters:
///   - jsonData: A `Data` object matching the expected JSON structure.
///
///     Example for the expected `JSON` structure - **NOTE**: It can be only be nested one level.
/// ```
/// {
///     "Focus": {
///         "--color-focus": {
///             "type": "color",
///             "value": "{Colors.Secondary.Indigo.700}"
///         }
///     },
///     "Indicator": {
///         "--color-indicator-magenta": {
///             "type": "color",
///             "value": "{Colors.Secondary.Magenta.300}"
///         },
///         "--color-indicator-yellow": {
///             "type": "color",
///             "value": "{Colors.Warning.400}"
///         }
///     }
/// }
/// ```
///   - flatMap: The flat `[String: ColorInfo]` map used for O(1) lookups, containing core color information.
///
/// - Returns: A `ColorData` dictionary that contains the hierarchical structure of color categories and their corresponding color information.
///
/// - Complexity: Let m be the number of categories and n be the average number of semantic keys per category - O(mn)
func extractColorData(from jsonData: Data, using flatMap: [String: ColorInfo]) throws -> ColorData {
    var colorData = try decoder.decode(ColorData.self, from: jsonData)

    for (categoryKey, var categoryValue) in colorData {
        for (semanticKey, var semanticInfo) in categoryValue {
            let sanitizedValue = semanticInfo.value.sanitizeSemanticJSONKey()
            // O(1) lookup
            guard let coreColorInfo = flatMap[sanitizedValue] else {
                let reason = "Error: couldn't lookup ColorInfo for \(semanticKey) with value \(semanticInfo.value)"
                throw ExtractColorDataError.inputIsWrong(reason: reason)
            }
            semanticInfo.value = coreColorInfo.value
            categoryValue[semanticKey] = semanticInfo
        }
        colorData[categoryKey] = categoryValue
    }

    return colorData
}

/// Parses a given JSON dictionary to a `NumberData` structure containing number information.
///
/// - Parameters:
///   - jsonObject: A dictionary with a string key and `Any` matching the expected JSON structure.
///     The JSON should contain number information that `NumberData` can decode.
///
///     Example for the expected `JSON` structure:
/// ```
/// {
///     "--border-radius-circle": {
///         "type": "dimension",
///         "value": "0.5px"
///     },
///     "--border-radius-extra-small": {
///         "type": "dimension",
///         "value": "2px"
///      }
/// }
///  ```
/// - Throws:
///   - JSONSerialization errors: If the JSON object is not serializable.
///   - Decoding errors: If the JSON data can't be decoded into a `NumberData` object.
///
/// - Returns: A `NumberData` object containing the parsed number information.
func extractNumberInfo(from jsonObject: [String: Any]) throws -> NumberData {
    let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    return try decoder.decode(NumberData.self, from: jsonData)
}
