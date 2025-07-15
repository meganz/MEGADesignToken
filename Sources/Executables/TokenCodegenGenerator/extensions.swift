import Foundation
import SwiftUI

extension String {
    func toCGFloat() -> CGFloat? {
        guard let doubleValue = Double(self) else {
            return nil
        }

        return CGFloat(doubleValue)
    }

    func toPascalCase() -> String {
        self
            .split(separator: " ")
            .map { $0.capitalized }
            .joined()
    }

    func toCamelCase() -> String {
        let pascalCased = self.toPascalCase()

        return pascalCased.prefix(1).lowercased() + pascalCased.dropFirst()
    }

    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }

        return String(self.dropFirst(prefix.count))
    }

    func isNumeric() -> Bool {
        CharacterSet.decimalDigits.isSuperset(of: .init(charactersIn: self))
    }

    /// In the Semantic Colors JSON, keys are in the format '{Secondary.Indigo.700}', always with the "bloat" curly braces
    /// and 'Colors.' prefix. This sanitizes the key to contain only the necessary hierarchical information.
    /// It also makes everything lowercased so we don't get tripped up while doing lookups.
    func sanitizeSemanticJSONKey() -> String {
        guard
            let start = range(of: "{Colors."),
            let end = range(of: "}")
        else { return self }

        let keyRange = start.upperBound..<end.lowerBound
        return self[keyRange].lowercased()
    }

    /// Extracts the alpha (opacity) component from semantic color strings in the format `rgba( {Colors.Grey.500}, 0.3)`.
    ///
    /// This function assumes the string follows the `rgba(...)` format, where the last component is the alpha value.
    /// It returns the alpha as a `Double`, or `nil` if the format is invalid.
    ///
    /// Example input:
    /// - `"rgba( {Colors.Grey.500}, 0.3)"` → `0.3`
    ///
    /// - Returns: A `Double` representing the alpha value, or `nil` if parsing fails.
    func alphaValueFromSemanticColors() -> Double? {
        guard starts(with: "rgba") else { return nil }

        let trimmed = self
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: ")", with: "")

        let components = trimmed.split(separator: ",")

        guard let alphaPart = components.last?.trimmingCharacters(in: .whitespaces) else { return nil }

        return Double(alphaPart)
    }

    func updateHexAlpha(alpha: Double?) -> String {
        guard let alpha else { return self }
        guard isHexColor else { return self }

        var updatedHex = self

        var hex = updatedHex.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        if hex.count == 8 {
            // Remove alpha channel if present
            hex = String(hex.prefix(6))
        }

        let clampedAlpha = max(0, min(1, alpha))
        let alphaInt = Int(round(clampedAlpha * 255))
        let alphaHex = String(format: "%02x", alphaInt)

        updatedHex = "#\(hex)\(alphaHex)"
        return updatedHex
    }

    /// Returns `true` if the string is a valid hex color code (e.g. `#FFF`, `#FFFFFF`, or `#FFFFFFFF`)
    var isHexColor: Bool {
        let pattern = #"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#
        return range(of: pattern, options: .regularExpression) != nil
    }

    /// Semantic colors have a format of '--color-foo-bar', so we'll make it 'fooBar'
    func sanitizeSemanticVariableName(with parentName: String) -> String {
        self
            .deletingPrefix("--color-")
            .removeSubstringIfNotWholeWord(parentName)
            .replacingOccurrences(of: "-", with: " ")
            .toCamelCase()
            .appendBackticks()
    }

    func removeSubstringIfNotWholeWord(_ substringToRemove: String) -> String {
        if self.lowercased() == substringToRemove.lowercased() {
            return self
        } else {
            return self.replacingOccurrences(
                of: substringToRemove,
                with: "",
                options: .caseInsensitive
            )
        }
    }

    func sanitizeNumberVariableName() -> String {
        if self.isNumeric() { // Dealing with Spacing, and Swift doesn't allow for numeric variable names
            return "_" + self
        } else { // Radius, which has a format of '--border-radius-foo-bar', so we'll make it 'fooBar'
            return self
                .deletingPrefix("--border-radius-")
                .replacingOccurrences(of: "-", with: " ")
                .toCamelCase()
        }
    }

    /// Some of the color names are Swift keywords, like `default`,
    /// so we need to append backticks to them to avoid compile errors
    func appendBackticks() -> String {
        "`\(self)`"
    }
}
