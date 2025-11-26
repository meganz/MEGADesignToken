@testable import TokenCodegenGenerator
import Foundation
import Testing

struct TokenCodegenGeneratorTests {
    // MARK: - Parser methods tests

    @Test func parseInput_whenGivenValidInput_returnsParseInputPayload() throws {
        let input = "[Path/To/tokens.json]"
        let parsed = try parseInput(input)

        #expect(parsed == URL(fileURLWithPath: "Path/To/tokens.json"))
    }

    @Test func parseInput_whenGivenInvalidArgumentCount_throwsWrongArgumentsError() throws {
        let input = "[Path/To/core.json, Path/To/Semantic tokens.Dark.tokens.json]"

        #expect(throws: ParseInputError.wrongArguments, performing: {
            try parseInput(input)
        })
    }

    @Test func parseInput_whenGivenInvalidCorePath_throwsWrongArgumentsError() throws {
        let input = "[Path/To/somefile.json]"

        #expect(throws: ParseInputError.wrongArguments, performing: {
            try parseInput(input)
        })
    }

    @Test func parseHex_whenGivenValid6DigitHex_correctlyParses() throws {
        let hexString = "#fffaf5"
        let parsed = try parseHex(hexString)
        #expect(parsed.red.isAlmostEqual(to: CGFloat(1.0), accuracy: 0.001), "Red component should be 1.0")
        #expect(parsed.green.isAlmostEqual(to: CGFloat(0.9804), accuracy: 0.001), "Green component should be approximately 0.9804")
        #expect(parsed.blue.isAlmostEqual(to: CGFloat(0.9608), accuracy: 0.001), "Blue component should be approximately 0.9608")
        #expect(parsed.alpha.isAlmostEqual(to: CGFloat(1.0), accuracy: 0.001), "Alpha component should be 1.0")
    }

    @Test func parseHex_whenGivenValid8DigitHex_correctlyParses() throws {
        let hexString = "#fffaf5cc"
        let parsed = try parseHex(hexString)
        #expect(parsed.red.isAlmostEqual(to: CGFloat(1.0), accuracy: 0.001), "Red component should be 1.0")
        #expect(parsed.green.isAlmostEqual(to: CGFloat(0.9804), accuracy: 0.001), "Green component should be approximately 0.9804")
        #expect(parsed.blue.isAlmostEqual(to: CGFloat(0.9608), accuracy: 0.001), "Blue component should be approximately 0.9608")
        #expect(parsed.alpha.isAlmostEqual(to: CGFloat(0.8), accuracy: 0.001), "Alpha component should be 0.8")
    }

    @Test func parseHex_whenGivenInvalidHex_throwsError() {
        let hexString = "#zzzzzz"
        #expect(throws: HexDecodingError.invalidInputCharacters, performing: {
            try parseHex(hexString)
        })
    }

    @Test func parseHex_whenGivenIncompleteHex_throwsError() {
        let hexString = "#fff"

        #expect(throws: HexDecodingError.invalidInputLength, performing: {
            try parseHex(hexString)
        })
    }

    @Test func parseHex_whenGivenEmptyString_throwsError() {
        let hexString = ""

        #expect(throws: HexDecodingError.invalidInputLength, performing: {
            try parseHex(hexString)
        })
    }

    @Test func parseNumber_withPxSuffix_parsesCorrectly() throws {
        #expect(try parseNumber("44px") == 44.0)
        #expect(try parseNumber("123.4px") == 123.4)
    }

    @Test func parseNumber_withoutSuffix_parsesCorrectly() throws {
        #expect(try parseNumber("150") == 150.0)
    }

    @Test func parseNumber_whenInvalidInput_throwsError() {
        #expect(throws: NumberDecodingError.self, performing: {
            try parseNumber("abcpx")
        })

        #expect(throws: NumberDecodingError.self, performing: {
            try parseNumber("123pxabc")
        })
    }

    @Test func extractFlatColorData_whenLeafNodes_parsesCorrectly() throws {
        let json: [String: Any] = [
            "Black opacity": [
                "090": [
                    "type": "color",
                    "value": "#000000e6"
                ]
            ]
        ]

        let colorData = try extractFlatColorData(from: json)

        #expect(colorData.keys.count == 1)
        #expect(colorData["black opacity.090"]?.type == "color")
        #expect(colorData["black opacity.090"]?.value == "#000000e6")
    }

    @Test func extractFlatColorData_whenHasNestedFlatColorData() throws {
        let json: [String: Any] = [
            "Base": [
                "white": [
                    "type": "color",
                    "value": "#ffffff"
                ]
            ],
            "LightGray": [
                "0": [
                    "type": "color",
                    "value": "{Colors.Grey.0}"
                ]
            ],
            "Grey": [
                "0": [
                    "type": "color",
                    "value": "{Colors.Base.white}"
                ]
            ]
        ]

        let colorData = try extractFlatColorData(from: json)

        #expect(colorData.keys.count == 3)
        #expect(colorData["base.white"]?.type == "color")
        #expect(colorData["base.white"]?.value == "#ffffff")
        #expect(colorData["lightgray.0"]?.type == "color")
        #expect(colorData["lightgray.0"]?.value == "#ffffff")
        #expect(colorData["grey.0"]?.type == "color")
        #expect(colorData["grey.0"]?.value == "#ffffff")
    }

    @Test func extractFlatColorData_whenNestedNodes_parsesCorrectly() throws {
        let json: [String: Any] = [
            "Secondary": [
                "Orange": [
                    "100": [
                        "type": "color",
                        "value": "#ffead5"
                    ]
                ]
            ]
        ]

        let colorData = try extractFlatColorData(from: json)

        #expect(colorData.keys.count == 1)
        #expect(colorData["secondary.orange.100"]?.type == "color")
        #expect(colorData["secondary.orange.100"]?.value == "#ffead5")
    }

    @Test func extractFlatColorData_whenInvalidJSON_doesNotParse() throws {
        let json: [String: Any] = [
            "Black opacity": "This should be a dictionary, not a string."
        ]
        let colorData = try extractFlatColorData(from: json)
        #expect(colorData.keys.count == 0)
    }

    @Test func extractColorData_whenValidInput_returnsCorrectColorData() throws {
        let jsonObject: [String: Any] = [
            "Text": [
                "--color-text-inverse": [
                    "type": "color",
                    "value": "{Colors.Secondary.Indigo.700}"
                ]
            ],
            "Icon": [
                "--color-icon-disable": [
                    "type": "color",
                    "value": "{Colors.Secondary.Blue.400}"
                ]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let flatMap = makeColorsFlatMap()

        let colorData = try extractColorData(from: jsonData, using: flatMap)

        #expect(colorData["Text"]?["--color-text-inverse"]?.value == "#4B0082")
        #expect(colorData["Icon"]?["--color-icon-disable"]?.value == "#0000FF")
    }

    @Test func extractColorData_whenRgbaInput_shouldReturnColorWithCorrectAlphaValue() throws {
        let jsonObject: [String: Any] = [
            "Button": [
                "--color-button-warning": [
                    "type": "color",
                    "value": "rgba( {Colors.Secondary.Blue.400}, 0.5)"
                ]
            ],
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let flatMap = makeColorsFlatMap()

        let colorData = try extractColorData(from: jsonData, using: flatMap)

        #expect(colorData["Button"]?["--color-button-warning"]?.value == "#0000FF80")
    }

    @Test func extractColorData_whenInvalidInput_throwsError() throws {
        let jsonObject: [String: Any] = [
            "Text": [
                "--color-text-inverse": [
                    "type": "color",
                    "value": "{Colors.NonExistentColor.100}"
                ]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let flatMap = makeColorsFlatMap()

        do {
            _ = try extractColorData(from: jsonData, using: flatMap)
            Issue.record("Expected `ExtractColorDataError.inputIsWrong` but no error was thrown.")
        } catch {
            if let extractError = error as? ExtractColorDataError {
                switch extractError {
                case .inputIsWrong(let reason):
                    #expect(reason == "Error: couldn't lookup ColorInfo for --color-text-inverse with value {Colors.NonExistentColor.100}")
                }
            } else {
                Issue.record("Expected `ExtractColorDataError.inputIsWrong` but got \(error)")
            }
        }
    }

    // MARK: - String Extensions tests

    @Test func toCGFloat_withValidString_returnsCGFloat() {
        #expect("1.23".toCGFloat() == CGFloat(1.23))
    }

    @Test func toCGFloat_withInvalidString_returnsNil() {
        #expect("abc".toCGFloat() == nil)
    }

    @Test func toPascalCase_convertsString() {
        #expect("hello world".toPascalCase() == "HelloWorld")
    }

    @Test func toCamelCase_convertsString() {
        #expect("Hello World".toCamelCase() == "helloWorld")
    }

    @Test func deletingPrefix_removesPrefix() {
        #expect("HelloWorld".deletingPrefix("Hello") == "World")
    }

    @Test func deletingPrefix_withNonMatchingPrefix_returnsSameString() {
        #expect("HelloWorld".deletingPrefix("Foo") == "HelloWorld")
    }

    @Test func isNumeric_withNumericString_returnsTrue() {
        #expect("12345".isNumeric())
    }

    @Test func isNumeric_withNonNumericString_returnsFalse() {
        #expect("abc".isNumeric() == false)
    }

    @Test func sanitizeSemanticJSONKey_removesExtraneousInformation() {
        #expect("{Colors.Secondary.Indigo.700}".sanitizeSemanticJSONKey() == "secondary.indigo.700")
    }

    @Test func sanitizeSemanticJSONKey_removesExtraneousInformation_forTokensWithRgba() {
        #expect("rgba( {Colors.Grey.500}, 0.1)".sanitizeSemanticJSONKey() == "grey.500")
    }

    @Test func sanitizeSemanticVariableName_removesExtraneousInformation_andAddBackticks() {
        #expect("--color-parent-foo-bar".sanitizeSemanticVariableName(with: "parent") == "`fooBar`")
    }

    @Test func sanitizeNumberVariableName_withNumericString_prependsUnderscore() {
        #expect("123".sanitizeNumberVariableName() == "_123")
    }

    @Test func sanitizeNumberVariableName_withNonNumericString_removesExtraneousInformation() {
        #expect("--border-radius-foo-bar".sanitizeNumberVariableName() == "fooBar")
    }

    @Test func alphaValueFromSemanticColors_withValidRgba_returnsAlpha() {
        #expect("rgba( {Colors.Grey.500}, 0.3)".alphaValueFromSemanticColors() == 0.3)
    }

    @Test func isHexColor() {
        #expect("#FFFFFF".isHexColor == true)
        #expect("#000000".isHexColor == true)
        #expect("#12345678".isHexColor == true)
        #expect("123456".isHexColor == false)
        #expect("#GGGGGG".isHexColor == false)
        #expect("notAHex".isHexColor == false)
    }

    @Test func updateHexAlpha_withValidAlpha_updatesHex() {
        let hex = "#ff0000"
        #expect(hex.updateHexAlpha(alpha: 0.5) == "#ff000080")
    }

    @Test func updateHexAlpha_withNilAlpha_returnsOriginalHex() {
        let hex = "#ff000080"
        #expect(hex.updateHexAlpha(alpha: nil) == hex)
    }

    @Test func updateHexAlpha_withInvalidHex_returnsOriginalString() {
        let hex = "notAHex"
        #expect(hex.updateHexAlpha(alpha: 0.5) == hex)
    }
}

// MARK: - Helpers

private extension TokenCodegenGeneratorTests {
    func makeColorsFlatMap() -> [String: ColorInfo] {
        [
            "secondary.indigo.700": .init(type: "color", value: "#4B0082"),
            "secondary.magenta.300": .init(type: "color", value: "#FF00FF"),
            "warning.400": .init(type: "color", value: "#FFD700"),
            "secondary.orange.300": .init(type: "color", value: "#FFA500"),
            "secondary.indigo.300": .init(type: "color", value: "#4B0082"),
            "secondary.blue.400": .init(type: "color", value: "#0000FF"),
            "success.400": .init(type: "color", value: "#008000"),
            "error.400": .init(type: "color", value: "#FF0000")
        ]
    }
}

extension CGFloat {
    func isAlmostEqual(to value: CGFloat, accuracy: CGFloat = .ulpOfOne) -> Bool {
        abs(self - value) <= accuracy
    }
}
