# MEGADesignToken

Swift Package Manager (SPM) package responsible for creating `Swift` code based on design tokens `JSON` files.

Example usage and the expected spec of the `JSON` files can be found at `/Sources/MEGADesignToken`.

Available enums (namespaces) containing tokens: `TokenColors, TokenSpacing and TokenRadius`.

> ⚠️ **NOTE**: Only the semantic palette is exposed as code

## Usage

### MEGA main application palette 

After adding `MEGADesignToken` as a package dependency, use it as:

```swift
import MEGADesignToken

let uiKitColorExample = TokenColors.Background.blur // UIColor
let swiftUIColorExample = TokenColors.Button.brandPressed.swiftUI // Color
let spacingExample = TokenSpacing._1 // CGFloat
let radiusExample = TokenRadius.small // CGFloat
```

### Custom palette

If you want to use your custom palette, then you must:

- Create a group (folder) under your target called `MEGADesignTokenResources`
- Place the following `.json` resources in the group: `core.json`, `Semantic tokens.Dark.tokens.json` and `Semantic tokens.Light.tokens.json`

> ⚠️ **NOTE**: The `.json` resources must respect the same name and format as the main application ones

- Under `Build Phases` of your target, add `TokenCodegen` in `Run Build Tool Plug-ins`

- Build your target and then use the available enums in your code, **without** importing `MEGADesignToken`

## Troubleshooting

- `Cannot find 'MEGADesignToken*' in scope`

The code is generated in a build tool plugin, so before start using the enums, first build your project.
