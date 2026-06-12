import SwiftUI

public typealias CollapsibleInsetContentFactory<Content> = (Binding<Bool>) -> Content where Content: View

/// Tracks scroll movement and snaps the inset to fully expanded or collapsed when scrolling stops.
/// Apply to any scrollable view (List, ScrollView, etc.) via `.collapsibleInset { expansion, isExpanded in ... }`.
private struct CollapsibleInsetModifier<SafeAreaContent: View>: ViewModifier {
    let edge: VerticalEdge
    let scrollDeltaRange: CGFloat
    let animation: Animation

    @ViewBuilder var safeAreaContent: CollapsibleInsetContentFactory<SafeAreaContent>

#if DEBUG
    @Environment(\.collapsibleInsetShowDebugHUD) var showDebugHUD
#endif

    init(
        edge: VerticalEdge,
        scrollDeltaRange: CGFloat,
        isExpanded: Binding<Bool>?,
        animation: Animation,
        @ViewBuilder content: @escaping CollapsibleInsetContentFactory<SafeAreaContent>,
    ) {
        self.edge = edge
        self.scrollDeltaRange = scrollDeltaRange
        isExpandedBinding = isExpanded
        self.animation = animation
        safeAreaContent = content
    }

    private var isExpandedBinding: Binding<Bool>?

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var scrollDelta: CGFloat = 0
    @State private var scrollDirection: ScrollDirection = .none
    @State private var isExpandedFallback: Bool = true
    @State private var isAnimating: Bool = false

    private var isExpanded: Bool {
        get {
            isExpandedBinding?.wrappedValue ?? isExpandedFallback
        }
        nonmutating set {
            if let isExpandedBinding {
                isExpandedBinding.wrappedValue = newValue
            } else {
                isExpandedFallback = newValue
            }
        }
    }

    private enum ScrollDirection { case none, down, up }

    func body(content: Content) -> some View {
        ZStack {
            content
#if DEBUG
            if showDebugHUD {
                debugHUD
            }
#endif
        }
        .safeAreaInset(edge: edge) {
            safeAreaContent(
                .init(
                    get: { isExpanded },
                    set: { isExpanded = $0 },
                ),
            )
        }
        .onScrollPhaseChange { _, new in
            scrollPhase = new
            if new == .idle {
                scrollDelta = isExpanded ? 0 : scrollDeltaRange
                scrollDirection = .none
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in
            guard !isAnimating, scrollPhase == .interacting else { return }

            let frameDelta = new - old
            scrollDelta = max(0, min(scrollDeltaRange, scrollDelta + frameDelta))

            if isExpanded {
                if scrollDelta >= scrollDeltaRange {
                    isAnimating = true

                    withAnimation(animation) {
                        isExpanded = false
                    } completion: {
                        isAnimating = false
                    }
                }
            } else {
                if scrollDelta <= 0 {
                    isAnimating = true

                    withAnimation(animation) {
                        isExpanded = true
                    } completion: {
                        isAnimating = false
                    }
                }
            }
        }
    }
}

#if DEBUG
extension EnvironmentValues {
    @Entry public var collapsibleInsetShowDebugHUD: Bool = false
}

extension CollapsibleInsetModifier {
    var debugHUD: some View {
        Form {
            LabeledContent("scrollDeltaRange", value: String(format: "%.0f", scrollDeltaRange))
            LabeledContent("scrollDelta", value: String(format: "%.1f", scrollDelta))
            LabeledContent("scrollPhase", value: scrollPhase.debugDescription)
        }
        .formStyle(.columns)
        .monospacedDigit()
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
#endif


public extension View {
    /// Attaches a collapsing inset that animates between expanded and collapsed states as the user scrolls.
    ///
    /// - Parameters:
    ///   - edge: Which vertical edge the inset is attached to. Default is `.top`.
    ///   - isExpanded: Optional external binding driving the expansion state. When `nil`, the modifier manages the state internally.
    ///   - scrollDeltaRange: How many points of scroll travel map to a full collapse/expand. Default is 200.
    ///   - content: A view builder that receives the current expansion (0 = collapsed, 1 = expanded) and a binding to the expansion state, allowing the content to programmatically toggle it.
    func collapsibleInset<Content: View>(
        edge: VerticalEdge = .top,
        isExpanded: Binding<Bool>? = nil,
        scrollDeltaRange: CGFloat = 100,
        animation: Animation = .default,
        @ViewBuilder content: @escaping CollapsibleInsetContentFactory<Content>,
    ) -> some View {
        modifier(
            CollapsibleInsetModifier<Content>(
                edge: edge,
                scrollDeltaRange: scrollDeltaRange,
                isExpanded: isExpanded,
                animation: animation,
                content: content,
            ),
        )
    }
}

#Preview("top edge") {
    @Previewable @State var isExpanded = true

    let animation = Animation.snappy(duration: 0.3, extraBounce: 0.1)

    List(1 ... 30, id: \.self) { i in
        Text("Row \(i)").padding(.vertical, 4)
    }
    .listStyle(.plain)
    .collapsibleInset(isExpanded: $isExpanded, scrollDeltaRange: 50, animation: animation) { _ in
        VStack(spacing: isExpanded ? nil : 0) {
            Button(isExpanded ? "collapse" : "expand") {
                withAnimation(animation) {
                    isExpanded.toggle()
                }
            }
            .buttonStyle(.glass)

            if isExpanded {
                Text("Extended content")
                    .font(.title)
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom)
        .background(.bar)
    }
    .environment(\.collapsibleInsetShowDebugHUD, true)
}
