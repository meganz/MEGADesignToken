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

    func sanitizeSemanticJSONKey() -> String {
        // In the Semantic Colors JSON, keys are in the format '{Secondary.Indigo.700}', always with the "bloat" curly braces
        // and 'Colors.' prefix. This sanitizes the key to contain only the necessary hierarchical information.
        // It also makes everything lowercased so we don't get tripped up while doing lookups.
        self
            .replacingOccurrences(of: "[\\{\\}]", with: "", options: .regularExpression, range: nil)
            .deletingPrefix("Colors.")
            .lowercased()
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
