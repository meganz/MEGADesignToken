import Foundation

let arguments = ProcessInfo().arguments

guard arguments.count == 3 else {
    print("Error: wrong arguments")
    abort(.wrongArguments)
}

let (input, output) = (arguments[1], arguments[2])

guard output.hasSuffix(".swift") else {
    print("Error: output file must be a .swift file")
    abort(.outputFileIsNotSwift)
}

do {
    let tokensURL = try parseInput(input)

    let tokensJSONObject = try extractJSON(from: tokensURL)

    let coreJSONObject = try extractJSONObject(from: tokensJSONObject, with: TopLevelTokenKeys.core)

    let coreColorMap = try generateCoreColorMap(with: coreJSONObject)

    let spacingInput = try generateSpacingInput(with: coreJSONObject)

    let radiusInput = try generateRadiusInput(with: coreJSONObject)

    let semanticDarkJSONObject = try extractJSONObject(from: tokensJSONObject, with: TopLevelTokenKeys.semanticDark)

    let semanticDarkInput = try generateSemanticInput(with: semanticDarkJSONObject, using: coreColorMap, isDark: true)

    let semanticLightJSONObject = try extractJSONObject(from: tokensJSONObject, with: TopLevelTokenKeys.semanticLight)

    let semanticLightInput = try generateSemanticInput(with: semanticLightJSONObject, using: coreColorMap, isDark: false)

    let codegenInput: CodegenInput = .init(dark: semanticDarkInput, light: semanticLightInput, spacing: spacingInput, radius: radiusInput)

    let generatedCode = try generateCode(with: codegenInput)

    let outputURL = URL(fileURLWithPath: output)

    try generatedCode.write(to: outputURL, atomically: true, encoding: .utf8)

} catch {
    print("Error: failed to execute TokenCodegenGenerator with Error(\(String(describing: error)))")
    abort(.other)
}

enum AbortReason: Int32 {
    case wrongArguments = 1
    case outputFileIsNotSwift = 2
    case badInputJSON = 3
    case other = 4
}

enum TopLevelTokenKeys: String, JSONKey {
    case core = "Core/Main"
    case semanticLight = "Semantic tokens/Light"
    case semanticDark = "Semantic tokens/Dark"
}

enum CoreTokensKey: String, JSONKey {
    case colors = "Colors"
    case spacing = "Spacing"
    case radius = "Radius"
}

enum ExpectedInput: String {
    case tokens = "tokens.json"

    static var description: String {
        "[\(tokens.rawValue)]"
    }
}

private func abort(_ reason: AbortReason) -> Never {
    print("Usage: TokenCodegenGenerator \(ExpectedInput.description) output.swift")
    exit(reason.rawValue)
}

private func extractJSON(from url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)

    guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
        print("Error: couldn't serialize .json core input into jsonObject")
        abort(.badInputJSON)
    }

    return jsonObject
}

private func extractJSONObject(from parentJSONObject: [String: Any], with key: any JSONKey) throws -> [String: Any] {
    guard let jsonObject = parentJSONObject[key.rawValue] as? [String: Any] else {
        print("Error: couldn't find '\(key.rawValue)' key in input")
        abort(.badInputJSON)
    }

    return jsonObject
}

private func generateCoreColorMap(with coreJSONObject: [String: Any]) throws -> [String: ColorInfo] {
    let coreColorsJSONObject = try extractJSONObject(from: coreJSONObject, with: CoreTokensKey.colors)
    let data = try extractFlatColorData(from: coreColorsJSONObject)

    return data
}

private func generateSemanticInput(with jsonObject: [String: Any], using map: [String: ColorInfo], isDark: Bool) throws -> SemanticInput {
    let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
    let data = try extractColorData(from: jsonData, using: map)

    return isDark ? .dark(data) : .light(data)
}

private func generateSpacingInput(with coreJSONObject: [String: Any]) throws -> NumberInput {
    let spacingJSONObject = try extractJSONObject(from: coreJSONObject, with: CoreTokensKey.spacing)
    let data = try extractNumberInfo(from: spacingJSONObject)

    return .spacing(data)
}

private func generateRadiusInput(with coreJSONObject: [String: Any]) throws -> NumberInput {
    let radiusJSONObject = try extractJSONObject(from: coreJSONObject, with: CoreTokensKey.radius)
    let data = try extractNumberInfo(from: radiusJSONObject)

    return .radius(data)
}
