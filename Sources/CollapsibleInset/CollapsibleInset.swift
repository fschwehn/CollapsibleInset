import SwiftUI

public typealias CollapsibleInsetContentFactory<Content> = (CGFloat, Binding<Bool>) -> Content where Content: View

/// Tracks scroll movement and snaps the inset to fully expanded or collapsed when scrolling stops.
/// Apply to any scrollable view (List, ScrollView, etc.) via `.collapsibleInset { expansion, isExpanded in ... }`.
private struct CollapsibleInsetModifier<SafeAreaContent: View>: ViewModifier {
    var edge: VerticalEdge
    var scrollDeltaRange: CGFloat
    @ViewBuilder var safeAreaContent: CollapsibleInsetContentFactory<SafeAreaContent>

    init(edge: VerticalEdge, scrollDeltaRange: CGFloat, isExpanded: Binding<Bool>?, content: @escaping CollapsibleInsetContentFactory<SafeAreaContent>) {
        self.edge = edge
        self.scrollDeltaRange = scrollDeltaRange
        isExpandedBinding = isExpanded
        safeAreaContent = content
    }

    private var isExpandedBinding: Binding<Bool>?

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var scrollDelta: CGFloat = 0
    @State private var scrollDirection: ScrollDirection = .none
    @State private var isExpandedFallback: Bool = true

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

    /// 0 = fully collapsed, 1 = fully expanded
    private var expansion: CGFloat {
        max(0, min(1, scrollDelta / -scrollDeltaRange + (isExpanded ? 1 : 0)))
    }

    func body(content: Content) -> some View {
        ZStack {
            content
        }
        .safeAreaInset(edge: edge) { safeAreaContent(expansion, .init(get: { isExpanded }, set: { isExpanded = $0 })) }
        .onScrollPhaseChange { _, new in
            scrollPhase = new
            if new == .idle {
                withAnimation {
                    isExpanded = expansion >= 0.5
                    scrollDelta = 0
                    scrollDirection = .none
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { old, new in
            guard scrollPhase == .interacting || scrollPhase == .decelerating else { return }

            let frameDelta = new - old
            scrollDelta += frameDelta

            if scrollPhase == .interacting {
                scrollDirection = frameDelta > 0 ? .down : .up
            }
        }
        .onChange(of: scrollDirection) { _, _ in
            if scrollPhase == .interacting {
                scrollDelta = max(-scrollDeltaRange, min(scrollDeltaRange, scrollDelta))
            }
        }
    }
}

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
        scrollDeltaRange: CGFloat = 200,
        @ViewBuilder content: @escaping CollapsibleInsetContentFactory<Content>,
    ) -> some View {
        modifier(
            CollapsibleInsetModifier<Content>(
                edge: edge,
                scrollDeltaRange: scrollDeltaRange,
                isExpanded: isExpanded,
                content: content,
            ),
        )
    }
}

#Preview("top edge") {
    @Previewable @State var isExpanded = true

    List(1 ... 30, id: \.self) { i in
        Text("Row \(i)").padding(.vertical, 4)
    }
    .listStyle(.plain)
    .collapsibleInset(isExpanded: $isExpanded) { expansion, _ in
        VStack(spacing: 4 * expansion) {
            Text("Collapsing Header")
                .font(.system(size: 14 + expansion * 16, weight: .semibold))
                .onTapGesture {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
            Text("Scroll down to collapse")
                .font(.caption)
                .opacity(expansion)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 + expansion * 12)
        .background(.bar)
    }
}

#Preview("bottom edge") {
    List(1 ... 30, id: \.self) { i in
        Text("Row \(i)").padding(.vertical, 4)
    }
    .listStyle(.plain)
    .collapsibleInset(edge: .bottom) { expansion, isExpanded in
        VStack(spacing: 4 * expansion) {
            Text("Collapsing Footer")
                .font(.system(size: 14 + expansion * 16, weight: .semibold))
                .onTapGesture {
                    withAnimation {
                        isExpanded.wrappedValue.toggle()
                    }
                }
            Text("Scroll down to collapse")
                .font(.caption)
                .opacity(expansion)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 + expansion * 12)
        .background(.bar)
    }
}
