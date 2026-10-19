import SwiftUI

struct WelcomeMotionView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .icons
    @State private var iconIndex = 0
    @State private var phraseIndex = 0
    @State private var iconHasAppeared = false

    private let icons = [
        "car.fill",
        "motorcycle.fill",
        "bicycle",
        "figure.walk",
        "shoeprints.fill"
    ]
    private let phraseEndings = ["حاليا", "هسه", "يمعود"]

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ZStack {
                if phase == .icons {
                    ZStack {
                        Image(systemName: icons[iconIndex])
                            .font(.system(size: 88, weight: .medium))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.black)
                            .id(iconIndex)
                            .transition(iconMorphTransition)
                    }
                    .frame(width: 176, height: 176)
                    .opacity(iconHasAppeared ? 1 : 0)
                    .blur(radius: iconHasAppeared ? 0 : 12)
                    .scaleEffect(iconHasAppeared ? 1 : 0.7)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(iconAccessibilityLabel)
                    .transition(blurMorphTransition)
                } else if phase == .question {
                    question
                        .transition(blurMorphTransition)
                } else {
                    brand
                        .transition(blurMorphTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await playIntro()
        }
        .accessibilityElement(children: .contain)
    }

    private var question: some View {
        // Measure complete sentences, not a fixed-width ending. The leading
        // edge stays anchored in RTL while Arabic shaping and spacing stay native.
        ZStack(alignment: .leading) {
            ForEach(phraseEndings, id: \.self) { ending in
                Text("وين انت \(ending)")
                    .hidden()
                    .accessibilityHidden(true)
            }

            Text("وين انت \(phraseEndings[phraseIndex])")
                .id(phraseIndex)
                .transition(.opacity)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundStyle(Color.black)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("وين انت \(phraseEndings[phraseIndex])")
    }

    private var brand: some View {
        Text("استخدم تطبيق وين")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(Color.black)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 24)
            .environment(\.layoutDirection, .rightToLeft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityLabel("استخدم تطبيق وين")
    }

    private var iconMorphTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BlurScaleOpacityModifier(blur: 14, scale: 0.55, opacity: 0, rotation: .degrees(-18)),
                identity: BlurScaleOpacityModifier(blur: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: BlurScaleOpacityModifier(blur: 12, scale: 1.35, opacity: 0, rotation: .degrees(14)),
                identity: BlurScaleOpacityModifier(blur: 0, scale: 1, opacity: 1)
            )
        )
    }

    private var blurMorphTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: BlurScaleOpacityModifier(blur: 10, scale: 0.88, opacity: 0),
                identity: BlurScaleOpacityModifier(blur: 0, scale: 1, opacity: 1)
            ),
            removal: .modifier(
                active: BlurScaleOpacityModifier(blur: 10, scale: 1.08, opacity: 0),
                identity: BlurScaleOpacityModifier(blur: 0, scale: 1, opacity: 1)
            )
        )
    }

    private var iconAccessibilityLabel: String {
        switch iconIndex {
        case 0: return "سيارة"
        case 1: return "دراجة نارية"
        case 2: return "دراجة"
        case 3: return "شخص يمشي"
        default: return "آثار أقدام"
        }
    }

    @MainActor
    private func playIntro() async {
        if reduceMotion {
            phase = .brand
            guard await wait(for: .milliseconds(1_500)) else { return }
            onContinue()
            return
        }

        withAnimation(.easeOut(duration: 0.32)) {
            iconHasAppeared = true
        }
        guard await wait(for: .milliseconds(500)) else { return }

        for nextIndex in icons.indices.dropFirst() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                iconIndex = nextIndex
            }
            guard await wait(for: .milliseconds(400)) else { return }
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            phraseIndex = 0
            phase = .question
        }

        guard await wait(for: .milliseconds(700)) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            phraseIndex = 1
        }

        guard await wait(for: .milliseconds(650)) else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            phraseIndex = 2
        }

        guard await wait(for: .milliseconds(650)) else { return }
        withAnimation(.easeInOut(duration: 0.32)) {
            phase = .brand
        }

        guard await wait(for: .milliseconds(1_500)) else { return }
        onContinue()
    }

    private func wait(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private enum Phase {
        case icons
        case question
        case brand
    }
}

private struct BlurScaleOpacityModifier: ViewModifier {
    let blur: CGFloat
    let scale: CGFloat
    let opacity: Double
    var rotation: Angle = .zero

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale)
            .rotationEffect(rotation)
    }
}
