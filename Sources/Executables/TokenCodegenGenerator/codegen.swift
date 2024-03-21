import SwiftSyntax
import SwiftSyntaxBuilder

struct CodegenInput {
    let dark: SemanticInput
    let light: SemanticInput
    let spacing: NumberInput
    let radius: NumberInput
}

enum NumberInput {
    case radius(NumberData)
    case spacing(NumberData)

    var data: NumberData {
        switch self {
        case .radius(let data), .spacing(let data):
            return data
        }
    }

    var identifier: String {
        switch self {
        case .radius:
            return "TokenRadius"
        case .spacing:
            return "TokenSpacing"
        }
    }
}

enum SemanticInput {
    case dark(ColorData)
    case light(ColorData)

    var data: ColorData {
        switch self {
        case .dark(let data), .light(let data):
            return data
        }
    }
}

enum CodegenError: Error {
    case codeHasWarnings
    case codeHasErrors
    case inputIsWrong(reason: String)
}

func generateCode(with input: CodegenInput) throws -> String {
    let code = try generateSourceFileSyntax(from: input)
    let formattedCode = code.formatted()

    guard !formattedCode.hasWarning else {
        throw CodegenError.codeHasWarnings
    }

    guard !formattedCode.hasError else {
        throw CodegenError.codeHasErrors
    }

    return formattedCode.description
}

private func generateSourceFileSyntax(from input: CodegenInput) throws -> SourceFileSyntax {
    try SourceFileSyntax {
        generateImport()
        generateNumberTopLevelEnum(with: input.spacing)
            .with(\.leadingTrivia, .newlines(2))
        generateNumberTopLevelEnum(with: input.radius)
            .with(\.leadingTrivia, .newlines(2))
        try generateSemanticTopLevelEnum(from: input)
            .with(\.leadingTrivia, .newlines(2))
        generateSwiftUIExtensions()
            .with(\.leadingTrivia, .newlines(2))
    }
}

private func generateImport() -> ImportDeclSyntax {
    let importPath = ImportPathComponentListSyntax { .init(name: .identifier("SwiftUI")) }

    return ImportDeclSyntax(importKeyword: .keyword(.import), path: importPath)
}

private func generateSwiftUIExtensions() -> DeclSyntax {
    DeclSyntax(stringLiteral:
        """
        #if os(macOS)
        public extension NSColor {
            var swiftUI: Color {
                if #available(macOS 12, *) {
                    Color(nsColor: self)
                } else {
                    Color(self)
                }
            }
        }
        #else
        public extension UIColor {
            var swiftUI: Color {
                if #available(iOS 15, *) {
                    Color(uiColor: self)
                } else {
                    Color(self)
                }
            }
        }
        #endif
        """
    )
}

private func mergeColorData(
    lightData: ColorData,
    darkData: ColorData
) -> [String: [String: (light: ColorInfo, dark: ColorInfo)]] {
    var mergedData = [String: [String: (light: ColorInfo, dark: ColorInfo)]]()

    for (key, lightValues) in lightData {
        guard let darkValues = darkData[key] else { continue }

        for (innerKey, lightColorInfo) in lightValues {
            if let darkColorInfo = darkValues[innerKey] {
                mergedData[key, default: [:]][innerKey] = (light: lightColorInfo, dark: darkColorInfo)
            }
        }
    }

    return mergedData
}

private func generateSemanticTopLevelEnum(from input: CodegenInput) throws -> EnumDeclSyntax {
    let combinedData = mergeColorData(lightData: input.light.data, darkData: input.dark.data)
    let memberBlockBuilder = {
        try MemberBlockItemListSyntax {
            for (enumName, category) in combinedData.sorted(by: { $0.key < $1.key }) {
                try generateSemanticEnum(for: enumName, category: category)
                    .with(\.leadingTrivia, .newlines(2))
            }
            
            try StructDeclSyntax(
                SyntaxNodeString(stringLiteral: "ColorCategory")) {
                   try VariableDeclSyntax(SyntaxNodeString(stringLiteral: "var name: String"), accessor: {})
                }
        }
    }

    return try EnumDeclSyntax(
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier("TokenColors", leadingTrivia: .space, trailingTrivia: .space),
        memberBlockBuilder: memberBlockBuilder
    )
}

private func generateNumberTopLevelEnum(with input: NumberInput) -> EnumDeclSyntax {
    let memberBlockBuilder = {
        MemberBlockItemListSyntax {
            for (name, info) in input.data.sorted(by: { $0.value < $1.value }) {
                generateNumberVariable(for: name, info: info)
            }
        }
    }

    return EnumDeclSyntax(
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier(input.identifier, leadingTrivia: .space, trailingTrivia: .space),
        memberBlockBuilder: memberBlockBuilder
    )
}

private func generateSemanticEnum(
    for name: String,
    category: [String: (light: ColorInfo, dark: ColorInfo)]
) throws -> EnumDeclSyntax {
    let memberBlock = try MemberBlockSyntax {
        for (variableName, info) in category.sorted(by: { $0.key < $1.key }) {
            try generateSemanticVariable(
                for: variableName,
                parentName: name,
                lightColorInfo: info.light,
                darkColorInfo: info.dark
            )
            .with(\.leadingTrivia, .newlines(2))
        }
    }

    return EnumDeclSyntax(
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier(name.toPascalCase(), leadingTrivia: .space, trailingTrivia: .space),
        memberBlock: memberBlock
    )
}

private func generateNumberVariable(for name: String, info: NumberInfo) -> DeclSyntax {
    let variableName = name.sanitizeNumberVariableName()

    return DeclSyntax(
    """
    /// \(raw: Int(info.value))pt
    public static let \(raw: variableName) = CGFloat(\(raw: info.value))
    """
    )
}

private func generateSemanticVariable(
    for name: String,
    parentName: String,
    lightColorInfo: ColorInfo,
    darkColorInfo: ColorInfo
) throws -> DeclSyntax {
    guard let lightRgba = lightColorInfo.rgba else {
        throw CodegenError.inputIsWrong(reason: "Codegen: unable to parse light version of Color(\(name))")
    }

    guard let darkRgba = darkColorInfo.rgba else {
        throw CodegenError.inputIsWrong(reason: "Codegen: unable to parse dark version of Color(\(name))")
    }

    let variableName = name.sanitizeSemanticVariableName(with: parentName)

    return DeclSyntax(
        """
        #if os(macOS)
        public static let \(raw: variableName) = NSColor(
            name: nil,
            dynamicProvider: {
                if $0.name == .aqua || $0.name == .vibrantLight || $0.name == .accessibilityHighContrastAqua || $0.name == .accessibilityHighContrastVibrantLight {
                    NSColor(red: \(raw: lightRgba.red), green: \(raw: lightRgba.green), blue: \(raw: lightRgba.blue), alpha: \(raw: lightRgba.alpha))
                } else {
                    NSColor(red: \(raw: darkRgba.red), green: \(raw: darkRgba.green), blue: \(raw: darkRgba.blue), alpha: \(raw: darkRgba.alpha))
                }
            }
        )
        #else
        public static let \(raw: variableName) = UIColor(
            dynamicProvider: {
                $0.userInterfaceStyle == .light
                    ? UIColor(red: \(raw: lightRgba.red), green: \(raw: lightRgba.green), blue: \(raw: lightRgba.blue), alpha: \(raw: lightRgba.alpha))
                    : UIColor(red: \(raw: darkRgba.red), green: \(raw: darkRgba.green), blue: \(raw: darkRgba.blue), alpha: \(raw: darkRgba.alpha))
            }
        )
        #endif
        """
    )
}
