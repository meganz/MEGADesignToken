@testable import TokenCodegenGenerator
import XCTest

final class TokenCodegenGeneratorTests: XCTestCase {
    // MARK: - Parser methods tests

    func testParseInput_whenGivenValidInput_returnsParseInputPayload() throws {
        let input = "[Path/To/tokens.json]"
        let parsed = try parseInput(input)

        XCTAssertEqual(parsed, URL(fileURLWithPath: "Path/To/tokens.json"))
    }

    func testParseInput_whenGivenInvalidArgumentCount_throwsWrongArgumentsError() throws {
        let input = "[Path/To/core.json, Path/To/Semantic tokens.Dark.tokens.json]"

        XCTAssertThrowsError(try parseInput(input)) { error in
            XCTAssertEqual(error as? ParseInputError, .wrongArguments)
        }
    }

    func testParseInput_whenGivenInvalidCorePath_throwsWrongArgumentsError() throws {
        let input = "[Path/To/somefile.json]"

        XCTAssertThrowsError(try parseInput(input)) { error in
            XCTAssertEqual(error as? ParseInputError, .wrongArguments)
        }
    }

    func testParseHex_whenGivenValid6DigitHex_correctlyParses() throws {
        let hexString = "#fffaf5"
        let parsed = try parseHex(hexString)
        XCTAssertEqual(parsed.red, CGFloat(1.0), accuracy: 0.001, "Red component should be 1.0")
        XCTAssertEqual(parsed.green, CGFloat(0.9804), accuracy: 0.001, "Green component should be approximately 0.9804")
        XCTAssertEqual(parsed.blue, CGFloat(0.9608), accuracy: 0.001, "Blue component should be approximately 0.9608")
        XCTAssertEqual(parsed.alpha, CGFloat(1.0), accuracy: 0.001, "Alpha component should be 1.0")
    }

    func testParseHex_whenGivenValid8DigitHex_correctlyParses() throws {
        let hexString = "#fffaf5cc"
        let parsed = try parseHex(hexString)
        XCTAssertEqual(parsed.red, CGFloat(1.0), accuracy: 0.001, "Red component should be 1.0")
        XCTAssertEqual(parsed.green, CGFloat(0.9804), accuracy: 0.001, "Green component should be approximately 0.9804")
        XCTAssertEqual(parsed.blue, CGFloat(0.9608), accuracy: 0.001, "Blue component should be approximately 0.9608")
        XCTAssertEqual(parsed.alpha, CGFloat(0.8), accuracy: 0.001, "Alpha component should be 0.8")
    }

    func testParseHex_whenGivenInvalidHex_throwsError() {
        let hexString = "#zzzzzz"
        XCTAssertThrowsError(try parseHex(hexString)) { error in
            XCTAssertEqual(error as? HexDecodingError, HexDecodingError.invalidInputCharacters)
        }
    }

    func testParseHex_whenGivenIncompleteHex_throwsError() {
        let hexString = "#fff"
        XCTAssertThrowsError(try parseHex(hexString)) { error in
            XCTAssertEqual(error as? HexDecodingError, HexDecodingError.invalidInputLength)
        }
    }

    func testParseHex_whenGivenEmptyString_throwsError() {
        let hexString = ""
        XCTAssertThrowsError(try parseHex(hexString)) { error in
            XCTAssertEqual(error as? HexDecodingError, HexDecodingError.invalidInputLength)
        }
    }

    func testParseNumber_withPxSuffix_parsesCorrectly() throws {
        XCTAssertEqual(try parseNumber("44px"), 44.0)
        XCTAssertEqual(try parseNumber("123.4px"), 123.4)
    }

    func testParseNumber_withoutSuffix_parsesCorrectly() throws {
        XCTAssertEqual(try parseNumber("150"), 150.0)
    }

    func testParseNumber_whenInvalidInput_throwsError() {
        XCTAssertThrowsError(try parseNumber("abcpx")) { error in
            XCTAssertTrue(error is NumberDecodingError)
        }

        XCTAssertThrowsError(try parseNumber("123pxabc")) { error in
            XCTAssertTrue(error is NumberDecodingError)
        }
    }

    func testExtractFlatColorData_whenLeafNodes_parsesCorrectly() throws {
        let json: [String: Any] = [
            "Black opacity": [
                "090": [
                    "type": "color",
                    "value": "#000000e6"
                ]
            ]
        ]

        let colorData = try extractFlatColorData(from: json)

        XCTAssertEqual(colorData.keys.count, 1)
        XCTAssertEqual(colorData["black opacity.090"]?.type, "color")
        XCTAssertEqual(colorData["black opacity.090"]?.value, "#000000e6")
    }

    func testExtractFlatColorData_whenHasNestedFlatColorData() throws {
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

        XCTAssertEqual(colorData.keys.count, 3)
        XCTAssertEqual(colorData["base.white"]?.type, "color")
        XCTAssertEqual(colorData["base.white"]?.value, "#ffffff")
        XCTAssertEqual(colorData["lightgray.0"]?.type, "color")
        XCTAssertEqual(colorData["lightgray.0"]?.value, "#ffffff")
        XCTAssertEqual(colorData["grey.0"]?.type, "color")
        XCTAssertEqual(colorData["grey.0"]?.value, "#ffffff")
    }

    func testExtractFlatColorData_whenNestedNodes_parsesCorrectly() throws {
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

        XCTAssertEqual(colorData.keys.count, 1)
        XCTAssertEqual(colorData["secondary.orange.100"]?.type, "color")
        XCTAssertEqual(colorData["secondary.orange.100"]?.value, "#ffead5")
    }

    func testExtractFlatColorData_whenInvalidJSON_doesNotParse() throws {
        let json: [String: Any] = [
            "Black opacity": "This should be a dictionary, not a string."
        ]
        let colorData = try extractFlatColorData(from: json)
        XCTAssertEqual(colorData.keys.count, 0)
    }

    func testExtractColorData_whenValidInput_returnsCorrectColorData() throws {
        let jsonObject: [String: Any] = [
            "Text": [
                "--color-text-inverse": [
                    "type": "color",
                    "value": "{Secondary.Indigo.700}"
                ]
            ],
            "Icon": [
                "--color-icon-disable": [
                    "type": "color",
                    "value": "{Secondary.Blue.400}"
                ]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let flatMap = makeColorsFlatMap()

        let colorData = try extractColorData(from: jsonData, using: flatMap)

        XCTAssertEqual(colorData["Text"]?["--color-text-inverse"]?.value, "#4B0082")
        XCTAssertEqual(colorData["Icon"]?["--color-icon-disable"]?.value, "#0000FF")
    }

    func testExtractColorData_whenInvalidInput_throwsError() throws {
        let jsonObject: [String: Any] = [
            "Text": [
                "--color-text-inverse": [
                    "type": "color",
                    "value": "{NonExistentColor}"
                ]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let flatMap = makeColorsFlatMap()

        XCTAssertThrowsError(try extractColorData(from: jsonData, using: flatMap)) { error in
            if let extractError = error as? ExtractColorDataError {
                switch extractError {
                case .inputIsWrong(let reason):
                    XCTAssertEqual(reason, "Error: couldn't lookup ColorInfo for --color-text-inverse with value {NonExistentColor}")
                }
            } else {
                XCTFail("Expected `ExtractColorDataError.inputIsWrong` but got \(error)")
            }
        }
    }

    // MARK: - String Extensions tests

    func testToCGFloat_withValidString_returnsCGFloat() {
        XCTAssertEqual("1.23".toCGFloat(), CGFloat(1.23))
    }

    func testToCGFloat_withInvalidString_returnsNil() {
        XCTAssertNil("abc".toCGFloat())
    }

    func testToPascalCase_convertsString() {
        XCTAssertEqual("hello world".toPascalCase(), "HelloWorld")
    }

    func testToCamelCase_convertsString() {
        XCTAssertEqual("Hello World".toCamelCase(), "helloWorld")
    }

    func testDeletingPrefix_removesPrefix() {
        XCTAssertEqual("HelloWorld".deletingPrefix("Hello"), "World")
    }

    func testDeletingPrefix_withNonMatchingPrefix_returnsSameString() {
        XCTAssertEqual("HelloWorld".deletingPrefix("Foo"), "HelloWorld")
    }

    func testIsNumeric_withNumericString_returnsTrue() {
        XCTAssertTrue("12345".isNumeric())
    }

    func testIsNumeric_withNonNumericString_returnsFalse() {
        XCTAssertFalse("abc".isNumeric())
    }

    func testSanitizeSemanticJSONKey_removesExtraneousInformation() {
        XCTAssertEqual("{Colors.Secondary.Indigo.700}".sanitizeSemanticJSONKey(), "secondary.indigo.700")
    }

    func testSanitizeSemanticVariableName_removesExtraneousInformation() {
        XCTAssertEqual("--color-parent-foo-bar".sanitizeSemanticVariableName(with: "parent"), "fooBar")
    }

    func testSanitizeNumberVariableName_withNumericString_prependsUnderscore() {
        XCTAssertEqual("123".sanitizeNumberVariableName(), "_123")
    }

    func testSanitizeNumberVariableName_withNonNumericString_removesExtraneousInformation() {
        XCTAssertEqual("--border-radius-foo-bar".sanitizeNumberVariableName(), "fooBar")
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
