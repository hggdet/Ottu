import SwiftUI

struct WelcomeMotionView: View {
    let onContinue: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeMoment = 0
    @State private var routeProgress: CGFloat = 0.08
    @State private var glowIsExpanded = false

    private let moments: [WelcomeMoment] = [
        WelcomeMoment(symbol: "magnifyingglass", label: "welcome.scene.search", title: "welcome.title.search", message: "welcome.message.search"),
        WelcomeMoment(symbol: "point.topleft.down.to.point.bottomright.curvepath", label: "welcome.scene.routes", title: "welcome.title.routes", message: "welcome.message.routes"),
        WelcomeMoment(symbol: "bookmark.fill", label: "welcome.scene.saved", title: "welcome.title.saved", message: "welcome.message.saved"),
        WelcomeMoment(symbol: "exclamationmark.triangle.fill", label: "welcome.scene.reports", title: "welcome.title.reports", message: "welcome.message.reports"),
        WelcomeMoment(symbol: "arrow.down.to.line", label: "welcome.scene.offline", title: "welcome.title.offline", message: "welcome.message.offline")
    ]

    private var currentMoment: WelcomeMoment {
        moments[activeMoment]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.025, green: 0.055, blue: 0.09)
                    .ignoresSafeArea()

                ambientLight

                VStack(spacing: 0) {
                    brandLockup
                        .padding(.top, 8)

                    Spacer(minLength: 12)

                    mapStage(height: min(max(geometry.size.height * 0.39, 250), 360))

                    Spacer(minLength: 18)

                    storyCopy

                    Spacer(minLength: 18)

                    footer
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 560, maxHeight: .infinity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(3.2))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.72, dampingFraction: 0.82)) {
                    activeMoment = (activeMoment + 1) % moments.count
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var ambientLight: some View {
        GeometryReader { geometry in
            ZStack {
                RadialGradient(
                    colors: [Color(red: 0.08, green: 0.52, blue: 0.62).opacity(0.27), .clear],
                    center: UnitPoint(x: 0.82, y: 0.22),
                    startRadius: 4,
                    endRadius: geometry.size.width * 0.75
                )
                RadialGradient(
                    colors: [Color(red: 0.18, green: 0.29, blue: 0.78).opacity(0.2), .clear],
                    center: UnitPoint(x: 0.1, y: 0.84),
                    startRadius: 2,
                    endRadius: geometry.size.width * 0.72
                )
                AmbientGrid()
                    .stroke(Color.white.opacity(0.035), lineWidth: 0.7)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var brandLockup: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 25, weight: .medium))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 0.36, green: 0.91, blue: 0.88), Color.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("app.name")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("welcome.kicker")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(2.1)
                    .foregroundStyle(Color.white.opacity(0.52))
            }
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(red: 0.36, green: 0.91, blue: 0.72))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color.teal.opacity(0.8), radius: 6)
                Text("welcome.live")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }

    private func mapStage(height: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.075, green: 0.15, blue: 0.21), Color(red: 0.045, green: 0.09, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                MapArtworkGrid()
                    .stroke(Color(red: 0.48, green: 0.77, blue: 0.77).opacity(0.13), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                mapDistricts(in: size)

                routePath(in: size)
                    .stroke(Color(red: 0.22, green: 0.82, blue: 0.88).opacity(0.1), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
                    .blur(radius: 8)

                routePath(in: size)
                    .trim(from: 0, to: routeProgress)
                    .stroke(
                        LinearGradient(colors: [Color(red: 0.37, green: 0.98, blue: 0.83), Color(red: 0.29, green: 0.78, blue: 0.97)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.cyan.opacity(0.68), radius: 9)

                routeNode(at: CGPoint(x: size.width * 0.12, y: size.height * 0.77), color: Color(red: 0.97, green: 0.75, blue: 0.37), size: 9)
                destinationPin(at: CGPoint(x: size.width * 0.82, y: size.height * 0.29))

                cityLabel
                    .position(x: size.width * 0.55, y: size.height * 0.47)

                VStack {
                    HStack(alignment: .top) {
                        sceneChip
                        Spacer(minLength: 8)
                        locationChip
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        routeSummaryCard
                        Spacer(minLength: 8)
                        compassMark
                    }
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 28, x: 0, y: 18)
            .onAppear(perform: startMapMotion)
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(currentMoment.title))
        .accessibilityHint(Text(currentMoment.message))
    }

    private func mapDistricts(in size: CGSize) -> some View {
        ZStack {
            district(x: 0.12, y: 0.18, width: 0.16, height: 0.14, in: size, rotation: -14)
            district(x: 0.39, y: 0.15, width: 0.18, height: 0.11, in: size, rotation: 9)
            district(x: 0.66, y: 0.11, width: 0.13, height: 0.15, in: size, rotation: -8)
            district(x: 0.17, y: 0.52, width: 0.17, height: 0.12, in: size, rotation: 11)
            district(x: 0.48, y: 0.71, width: 0.19, height: 0.12, in: size, rotation: -12)
            district(x: 0.77, y: 0.62, width: 0.14, height: 0.14, in: size, rotation: 15)
            district(x: 0.32, y: 0.34, width: 0.11, height: 0.12, in: size, rotation: -6)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func district(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, in size: CGSize, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.37, green: 0.58, blue: 0.59).opacity(0.11))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
            }
            .frame(width: size.width * width, height: size.height * height)
            .rotationEffect(.degrees(rotation))
            .position(x: size.width * x, y: size.height * y)
    }

    private func routePath(in size: CGSize) -> Path {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.77))
            path.addCurve(
                to: CGPoint(x: size.width * 0.39, y: size.height * 0.63),
                control1: CGPoint(x: size.width * 0.21, y: size.height * 0.7),
                control2: CGPoint(x: size.width * 0.28, y: size.height * 0.77)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.61, y: size.height * 0.47),
                control1: CGPoint(x: size.width * 0.5, y: size.height * 0.51),
                control2: CGPoint(x: size.width * 0.51, y: size.height * 0.66)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.82, y: size.height * 0.29),
                control1: CGPoint(x: size.width * 0.73, y: size.height * 0.3),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.43)
            )
        }
    }

    private func routeNode(at point: CGPoint, color: Color, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.19)).frame(width: size * 2.8, height: size * 2.8)
            Circle().fill(color).frame(width: size, height: size)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.5))
        }
        .position(point)
        .shadow(color: color.opacity(0.42), radius: 10)
    }

    private func destinationPin(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.43, green: 0.98, blue: 0.88).opacity(0.28), lineWidth: 1)
                .frame(width: glowIsExpanded ? 58 : 43, height: glowIsExpanded ? 58 : 43)
            Circle()
                .fill(Color(red: 0.32, green: 0.94, blue: 0.83).opacity(0.1))
                .frame(width: 39, height: 39)
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.42, green: 1, blue: 0.88))
                .shadow(color: Color.cyan.opacity(0.8), radius: 12)
                .scaleEffect(glowIsExpanded ? 1.08 : 0.94)
        }
        .position(point)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.65).repeatForever(autoreverses: true), value: glowIsExpanded)
    }

    private var sceneChip: some View {
        HStack(spacing: 7) {
            Image(systemName: currentMoment.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 0.4, green: 0.96, blue: 0.88))
                .contentTransition(.symbolEffect(.replace))
            Text(currentMoment.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: activeMoment)
    }

    private var locationChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.47, green: 0.96, blue: 0.76))
            Text("map.city")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var routeSummaryCard: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.32, green: 0.92, blue: 0.84).opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.38, green: 0.97, blue: 0.86))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("welcome.map.route")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text("welcome.map.destination")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color(red: 0.06, green: 0.12, blue: 0.17).opacity(0.83), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
        .id(activeMoment)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        .animation(.spring(response: 0.65, dampingFraction: 0.8), value: activeMoment)
    }

    private var compassMark: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.3)).frame(width: 38, height: 38)
            Circle().strokeBorder(Color.white.opacity(0.13), lineWidth: 1).frame(width: 38, height: 38)
            Image(systemName: "location.north.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.84))
                .rotationEffect(.degrees(glowIsExpanded ? 9 : -9))
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: glowIsExpanded)
        }
        .accessibilityHidden(true)
    }

    private var cityLabel: some View {
        Text("welcome.map.city_label")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(2.1)
            .foregroundStyle(Color.white.opacity(0.25))
            .rotationEffect(.degrees(-12))
            .accessibilityHidden(true)
    }

    private var storyCopy: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Capsule()
                    .fill(Color(red: 0.36, green: 0.93, blue: 0.84))
                    .frame(width: 17, height: 3)
                Text(currentMoment.label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(Color(red: 0.43, green: 0.92, blue: 0.88))
                    .contentTransition(.opacity)
            }

            Text(currentMoment.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .id("title-\(activeMoment)")
                .transition(.opacity.combined(with: .offset(y: 8)))

            Text(currentMoment.message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .id("message-\(activeMoment)")
                .transition(.opacity)

            HStack(spacing: 7) {
                ForEach(moments.indices, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                            activeMoment = index
                        }
                    } label: {
                        Capsule()
                            .fill(index == activeMoment ? Color(red: 0.38, green: 0.94, blue: 0.86) : Color.white.opacity(0.2))
                            .frame(width: index == activeMoment ? 22 : 5, height: 5)
                            .frame(minWidth: 16, minHeight: 22)
                            .contentShape(Rectangle())
                            .animation(.spring(response: 0.42, dampingFraction: 0.75), value: activeMoment)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(moments[index].label))
                    .accessibilityAddTraits(index == activeMoment ? .isSelected : [])
                }
            }
            .padding(.top, 3)
            .accessibilityElement(children: .contain)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .animation(.easeInOut(duration: 0.35), value: activeMoment)
    }

    private var footer: some View {
        VStack(spacing: 11) {
            Button(action: onContinue) {
                HStack(spacing: 10) {
                    Text("welcome.cta")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Image(systemName: locale.language.languageCode?.identifier == "en" ? "arrow.right" : "arrow.left")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color(red: 0.025, green: 0.09, blue: 0.12))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(colors: [Color(red: 0.47, green: 0.98, blue: 0.85), Color(red: 0.32, green: 0.84, blue: 0.92)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: Color(red: 0.19, green: 0.85, blue: 0.83).opacity(0.2), radius: 18, x: 0, y: 9)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("welcome.cta_hint"))

            Text("welcome.footer")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }

    private func startMapMotion() {
        if reduceMotion {
            routeProgress = 1
            glowIsExpanded = true
            return
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            routeProgress = 1
        }
        withAnimation(.easeInOut(duration: 1.65).repeatForever(autoreverses: true)) {
            glowIsExpanded = true
        }
    }
}

private struct WelcomeMoment {
    let symbol: String
    let label: LocalizedStringKey
    let title: LocalizedStringKey
    let message: LocalizedStringKey
}

private struct AmbientGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 32
        stride(from: 0, through: rect.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        stride(from: 0, through: rect.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}

private struct MapArtworkGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<5 {
            let y = rect.height * (0.14 + CGFloat(index) * 0.17)
            path.move(to: CGPoint(x: -rect.width * 0.05, y: y))
            path.addCurve(
                to: CGPoint(x: rect.width * 1.05, y: y - rect.height * 0.06),
                control1: CGPoint(x: rect.width * 0.33, y: y - rect.height * 0.12),
                control2: CGPoint(x: rect.width * 0.59, y: y + rect.height * 0.11)
            )
        }
        for index in 0..<5 {
            let x = rect.width * (0.1 + CGFloat(index) * 0.2)
            path.move(to: CGPoint(x: x, y: -rect.height * 0.05))
            path.addCurve(
                to: CGPoint(x: x + rect.width * 0.08, y: rect.height * 1.05),
                control1: CGPoint(x: x - rect.width * 0.12, y: rect.height * 0.36),
                control2: CGPoint(x: x + rect.width * 0.2, y: rect.height * 0.65)
            )
        }
        return path
    }
}
