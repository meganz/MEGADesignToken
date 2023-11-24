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

    guard !code.hasWarning else {
        throw CodegenError.codeHasWarnings
    }

    guard !code.hasError else {
        throw CodegenError.codeHasErrors
    }

    return code.description
}

private func generateSourceFileSyntax(from input: CodegenInput) throws -> SourceFileSyntax {
    try SourceFileSyntax {
        generateImport()
        generateSwiftUIExtensions()
        try generateSemanticTopLevelEnum(from: input)
        generateNumberTopLevelEnum(with: input.spacing)
        generateNumberTopLevelEnum(with: input.radius)
    }
}

private func generateImport() -> ImportDeclSyntax {
    let importPath = ImportPathComponentListSyntax {
        .init(leadingTrivia: .space, name: .identifier("SwiftUI"), trailingTrivia: .newline)
    }

    return ImportDeclSyntax(importKeyword: .keyword(.import), path: importPath)
}

private func generateSwiftUIExtensions() -> DeclSyntax {
    DeclSyntax(stringLiteral:
        """
        public extension UIColor {
            var swiftUI: Color {
                if #available(iOS 15, *) {
                    Color(uiColor: self)
                } else {
                    Color(self)
                }
            }
        }
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
            for (enumName, category) in combinedData {
                try generateSemanticEnum(for: enumName, category: category)
            }
        }
    }

    return try EnumDeclSyntax(
        leadingTrivia: .newline,
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier("TokenColors", leadingTrivia: .space, trailingTrivia: .space),
        memberBlockBuilder: memberBlockBuilder,
        trailingTrivia: .newline
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
        leadingTrivia: .newline,
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier(input.identifier, leadingTrivia: .space, trailingTrivia: .space),
        memberBlockBuilder: memberBlockBuilder,
        trailingTrivia: .newline
    )
}

private func generateSemanticEnum(
    for name: String,
    category: [String: (light: ColorInfo, dark: ColorInfo)]
) throws -> EnumDeclSyntax {
    let memberBlock = try MemberBlockSyntax {
        for (variableName, info) in category {
            try generateSemanticVariable(
                for: variableName,
                parentName: name,
                lightColorInfo: info.light,
                darkColorInfo: info.dark
            )
        }
    }

    return EnumDeclSyntax(
        leadingTrivia: .newlines(2),
        modifiers: [.init(name: .keyword(.public, trailingTrivia: .space))],
        name: .identifier(name.toPascalCase(), leadingTrivia: .space, trailingTrivia: .space),
        memberBlock: memberBlock
    )
}

private func generateNumberVariable(for name: String, info: NumberInfo) -> DeclSyntax {
    let variableName = name.sanitizeNumberVariableName()

    return DeclSyntax(
    """
    \n
    /// \(raw: Int(info.value))pt
    public static let \(raw: variableName) = CGFloat(\(raw: info.value))
    \n
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
        \n
        public static let \(raw: variableName) = UIColor(dynamicProvider: { traitCollection in
            return traitCollection.userInterfaceStyle == .light
                ? UIColor(red: \(raw: lightRgba.red), green: \(raw: lightRgba.green), blue: \(raw: lightRgba.blue), alpha: \(raw: lightRgba.alpha))
                : UIColor(red: \(raw: darkRgba.red), green: \(raw: darkRgba.green), blue: \(raw: darkRgba.blue), alpha: \(raw: darkRgba.alpha))
        })
        \n
        """
    )
}
