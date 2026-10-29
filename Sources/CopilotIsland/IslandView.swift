import SwiftUI

struct IslandMetrics: Equatable {
    var collapsed: CGSize
    var expanded: CGSize
    var notch: CGFloat
    // Transparent margin around the expanded size so the spring overshoot isn't clipped by the window.
    static let slack: CGFloat = 24
}

struct IslandView: View {
    @ObservedObject var store: SessionStore
    let metrics: IslandMetrics

    private var size: CGSize { store.expanded ? metrics.expanded : metrics.collapsed }
    private var radius: CGFloat { store.expanded ? 26 : metrics.collapsed.height / 2 }

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
        ZStack(alignment: .top) {
            rows
                .frame(width: metrics.expanded.width, height: metrics.expanded.height, alignment: .top)
                .opacity(store.expanded ? 1 : 0)
                .scaleEffect(store.expanded ? 1 : 0.85, anchor: .top)
                .animation(.easeOut(duration: 0.2).delay(store.expanded ? 0.1 : 0), value: store.expanded)
            dots
                .frame(width: metrics.collapsed.width, height: metrics.collapsed.height)
                .opacity(store.expanded ? 0 : 1)
                .animation(.easeOut(duration: 0.12), value: store.expanded)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(shape.fill(.black))
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: store.expanded)
    }

    private var rows: some View {
        VStack(spacing: 4) {
            ForEach(store.sessions.prefix(AppDelegate.maxRows)) { session in
                SessionRow(session: session, store: store)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10 + metrics.notch)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(store.sessions.prefix(6)) { Circle().fill($0.state.color).frame(width: 8, height: 8) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            if let color = store.attentionColor {
                Circle().fill(color).frame(width: 8, height: 8).padding(.trailing, 6)
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    let store: SessionStore

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(session.state.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.project).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(session.message.isEmpty ? session.state.label : session.message)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button { store.dismiss(session) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { store.open(session) }
    }
}
