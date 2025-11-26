import Foundation
import PackagePlugin

@main
struct TokenCodegenPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let input = context.package.directoryURL.appending(path: Constants.resourcesPath)

        let executableURL = try context.tool(named: Constants.executable).url

        let output = context.pluginWorkDirectoryURL.appending(path: Constants.outputSuffix)

        return [
            .buildCommand(
                displayName: Constants.displayName,
                executable: executableURL,
                arguments: [input.path(), output.path()],
                inputFiles: [input],
                outputFiles: [output]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TokenCodegenPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let input = context.xcodeProject.directoryURL.appending(path: Constants.resourcesPath)

        let executableURL = try context.tool(named: Constants.executable).url

        let output = context.pluginWorkDirectoryURL.appending(path: Constants.outputSuffix)

        return [
            .buildCommand(
                displayName: Constants.displayName,
                executable: executableURL,
                arguments: [input.path(), output.path()],
                inputFiles: [input],
                outputFiles: [output]
            )
        ]
    }
}
#endif

// MARK: - Constants

private extension TokenCodegenPlugin {
    enum Constants {
        static let resourcesPath = "/MEGADesignTokenResources/tokens.json"
        static let executable = "TokenCodegenGenerator"
        static let outputSuffix = "MEGADesignTokenColors.swift"
        static let displayName = "Generating code for Design Tokens"
    }
}
