# CollapsibleInset

A SwiftUI view modifier that attaches a header or footer to a scrollable view and smoothly collapses or expands it as the user scrolls.

The inset snaps to fully expanded or fully collapsed when scrolling stops, and your view builder receives an `expansion` value (0 = collapsed, 1 = expanded) so you can animate fonts, padding, opacity, or anything else in step with the scroll.

## Requirements

- iOS 26+
- Swift 6.3+

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter the repository URL.

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fschwehn/CollapsibleInset.git", from: "0.1.0")
]
```

Then add `"CollapsibleInset"` to your target's dependencies.

## Usage

Apply `.collapsibleInset` to any scrollable view (`List`, `ScrollView`, …). The trailing closure builds the inset content and receives the current expansion as a `CGFloat` between 0 and 1.

```swift
import SwiftUI
import CollapsibleInset

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(1 ... 30, id: \.self) { i in
                Text("Row \(i)")
            }
            .collapsibleInset { expansion in
                VStack(spacing: 4 * expansion) {
                    Text("Collapsing Header")
                        .font(.system(size: 14 + expansion * 16, weight: .semibold))
                    Text("Scroll down to collapse")
                        .font(.caption)
                        .opacity(expansion)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8 + expansion * 12)
                .background(Material.ultraThin)
            }
        }
    }
}
```

### Parameters

- `edge`: which vertical edge to attach to — `.top` (default) or `.bottom`.
- `scrollDeltaRange`: how many points of scroll travel map to a full collapse/expand. Default is `200`.
- `header`: a view builder that receives the current expansion (`0` = collapsed, `1` = expanded).

### Bottom-edge example

```swift
.collapsibleInset(edge: .bottom, scrollDeltaRange: 150) { expansion in
    FooterBar(expansion: expansion)
}
```

## License

MIT — see [LICENSE](LICENSE).
