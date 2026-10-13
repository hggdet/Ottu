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
                    Image(systemName: icons[iconIndex])
                        .font(.system(size: 88, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.black)
                        .frame(width: 176, height: 176)
                        .opacity(iconHasAppeared ? 1 : 0)
                        .blur(radius: iconHasAppeared ? 0 : 12)
                        .scaleEffect(iconHasAppeared ? 1 : 0.9)
                        .id(icons[iconIndex])
                        .transition(blurMorphTransition)
                        .accessibilityLabel(iconAccessibilityLabel)
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
        HStack(spacing: 8) {
            Text("وين انت")
                .fixedSize()

            ZStack {
                Text(phraseEndings[phraseIndex])
                    .id(phraseIndex)
                    .transition(blurMorphTransition)
            }
            .frame(width: 154, height: 54)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .font(.system(size: 34, weight: .bold, design: .rounded))
        .foregroundStyle(Color.black)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("وين انت \(phraseEndings[phraseIndex])")
        .animation(.easeInOut(duration: 0.38), value: phraseIndex)
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

        withAnimation(.easeInOut(duration: 0.8)) {
            iconHasAppeared = true
        }
        guard await wait(for: .milliseconds(800)) else { return }

        let iconDurations: [Duration] = [
            .milliseconds(900),
            .milliseconds(900),
            .milliseconds(900),
            .milliseconds(1_000)
        ]

        for nextIndex in icons.indices.dropFirst() {
            withAnimation(.easeInOut(duration: seconds(for: iconDurations[nextIndex - 1]))) {
                iconIndex = nextIndex
            }
            guard await wait(for: iconDurations[nextIndex - 1]) else { return }
        }

        guard await wait(for: .milliseconds(700)) else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            phraseIndex = 0
            phase = .question
        }

        guard await wait(for: .milliseconds(430)) else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            phraseIndex = 1
        }

        guard await wait(for: .milliseconds(430)) else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            phraseIndex = 2
        }

        guard await wait(for: .milliseconds(440)) else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            phase = .brand
        }

        guard await wait(for: .milliseconds(1_500)) else { return }
        onContinue()
    }

    private func seconds(for duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
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

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .scaleEffect(scale)
    }
}
