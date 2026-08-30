import SwiftUI
import WidgetKit

/// Renders the rectangular next-lesson Smart Stack card independently from
/// every watch-face complication layout.
///
/// The card is a short run of the day rather than a single row: three lessons
/// ride a lit glass arch, with the one the wearer is in held at the crest and
/// a marker tracking their way across it. Under it, one line says what they
/// are actually waiting for.
struct NextLessonWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: NextLessonEntry

    var body: some View {
        Group {
            if renderingMode == .fullColor {
                card
            } else {
                tintedCard
            }
        }
        .containerBackground(for: .widget) { backdrop }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Full colour

    /// Every measurement comes off the card's own height: a rectangular
    /// accessory is a different size on each watch, and proportions guessed
    /// against one of them crowd the line underneath on the others.
    private var card: some View {
        GeometryReader { proxy in
            let arch = Arch(height: proxy.size.height)

            ZStack(alignment: .top) {
                field
                band(arch)

                VStack(spacing: 0) {
                    lessons(arch, width: proxy.size.width)
                        .padding(.horizontal, 5)

                    Spacer(minLength: 0)

                    // The pocket the arch leaves under its crest.
                    footerLine(arch)
                        .padding(.horizontal, 6)
                        .padding(.bottom, arch.height * 0.02)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            // The card paints to its own edges, so it has to take the
            // container's corners with it.
            .clipShape(ContainerRelativeShape())
        }
    }

    private func band(_ arch: Arch) -> some View {
        let shape = arch.shape
        let day = entry.dayProgress
        return ZStack {
            // The day's own colour, lit at the crest and falling away to both
            // ends — cool at the first period, warm by the last.
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: DayHue.color(day - 0.2, brightness: 0.62), location: 0),
                        .init(color: DayHue.color(day, brightness: 1, white: 0.3), location: glowAnchor),
                        .init(color: DayHue.color(day + 0.2, brightness: 0.6), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Light from above: a lit upper face falling into shadow
            // underneath, which is what gives the band its depth.
            shape.fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.18), location: 0),
                        .init(color: .white.opacity(0), location: 0.45),
                        .init(color: .black.opacity(0.34), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // The core of that light. Clipped to the arch: loose on the
            // background it escapes below the band and reads as a second one.
            RadialGradient(
                colors: [.white.opacity(0.22), .white.opacity(0)],
                center: UnitPoint(x: glowAnchor, y: 0.3),
                startRadius: 0,
                endRadius: arch.height * 0.6
            )
            .clipShape(shape)

            Color.clear
                .glassEffect(.clear.tint(DayHue.color(day, brightness: 0.9).opacity(0.14)), in: shape)

            // A rim on the leading edge only — the underside stays dark.
            shape.stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.6), location: 0),
                        .init(color: .white.opacity(0), location: 0.4),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.5
            )
        }
        .compositingGroup()
        // Glass only reads as lifted if it casts onto what it is lifted from.
        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
        .overlay { litEdge(arch) }
        .overlay { marker(arch) }
    }

    /// The stretch of the day already behind the wearer, drawn as a lit rim
    /// along the arch's leading edge up to the marker. Progress as a path
    /// rather than a lone dot: the dot says where, the rim says how far.
    @ViewBuilder private func litEdge(_ arch: Arch) -> some View {
        if let cursor {
            ArchEdgeShape(arch: arch, end: cursor)
                .stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .shadow(color: accent.opacity(0.8), radius: 2.5)
        }
    }

    /// Where the wearer has got to, riding the arch's leading edge.
    @ViewBuilder private func marker(_ arch: Arch) -> some View {
        if let cursor {
            GeometryReader { proxy in
                Circle()
                    .fill(.white)
                    .frame(width: arch.markerSize, height: arch.markerSize)
                    .shadow(color: accent.opacity(0.9), radius: 3)
                    .position(
                        x: proxy.size.width * cursor,
                        y: arch.inset + arch.drop(at: cursor) + arch.markerSize * 0.25
                    )
            }
        }
    }

    private func lessons(_ arch: Arch, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 3) {
            // A week without a single lesson — a weekend with nothing fetched
            // ahead, or an empty timetable — still gets the arch, with its
            // title riding the crest where the focus would.
            if !hasAnyLesson {
                Text(emptyTitle)
                    .font(.system(size: arch.subjectSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .offset(y: arch.textTop(at: 0.5, isFocus: false))
            } else {
                ForEach(Array(entry.slots.enumerated()), id: \.offset) { index, lesson in
                    let focus = index == focusSlot
                    cell(for: lesson, isFocus: focus, arch: arch)
                        // The flanks lean with the band: each is turned to
                        // the arch's own tangent where it stands, so the
                        // lessons ride the curve rather than hover over it.
                        // The focus sits at the crest, where the tangent is
                        // flat anyway.
                        .rotationEffect(focus ? .zero : arch.tilt(at: anchor(of: index), width: width))
                        // Each lesson is centred on the band's own centreline
                        // where it stands, so it rides the arch instead of
                        // sitting on a flat line across it. Aligning tops or
                        // baselines instead leaves the smaller flanking
                        // lessons floating high or low in the band.
                        .offset(y: arch.textTop(at: anchor(of: index), isFocus: focus))
                }
            }
        }
    }

    @ViewBuilder private func cell(for lesson: Lesson?, isFocus: Bool, arch: Arch) -> some View {
        if let lesson {
            VStack(spacing: -1) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(lesson.period))
                        .font(.system(
                            size: isFocus ? arch.subjectSize : arch.flankSize,
                            weight: isFocus ? .semibold : .medium,
                            design: .rounded
                        ))
                        .foregroundStyle(.white.opacity(isFocus ? 0.5 : 0.3))

                    // The flanks sit much further back than the focus — far
                    // enough that at a glance only one lesson is on the card.
                    Text(lesson.subject)
                        .font(.system(
                            size: isFocus ? arch.subjectSize : arch.flankSize,
                            weight: isFocus ? .semibold : .medium
                        ))
                        .foregroundStyle(.white.opacity(isFocus ? 1 : 0.55))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                // Only the lesson in focus carries a teacher: three subjects
                // over three names is more than the band can hold.
                if isFocus, lesson.hasTeacher {
                    Text(lesson.teacher)
                        .font(.system(size: arch.teacherSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            // The edge of the day: the slot stays empty so the lesson in
            // focus keeps the crest.
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    /// The countdown, set the way the references set a value: a dim label at
    /// the leading edge, the number at the trailing one, loud and in the
    /// day's own colour. A line with no label — the day is over, the week is
    /// empty — has nothing to anchor against and stays centred.
    private func footerLine(_ arch: Arch) -> some View {
        let line = footer
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let prefix = line.prefix {
                Text(prefix)
                    .kerning(0.4)
                    .font(.system(size: arch.footerSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))

                Spacer(minLength: 4)
            }

            if let value = line.value {
                Text(value)
                    .font(.system(size: arch.footerValueSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                    .shadow(color: accent.opacity(0.5), radius: 3)
            }

            Text(line.suffix)
                .kerning(0.4)
                .font(.system(size: arch.footerSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
    }

    /// A colour field rather than black: the arch reads as glass lifted off
    /// the card only when there is something under it to lift off. It carries
    /// the same colour as the arch, a few stops down.
    ///
    /// Drawn as the card's own bottom layer as well as its container
    /// background, because the Smart Stack drops container backgrounds and
    /// would otherwise leave the arch floating on black.
    private var field: some View {
        ZStack {
            mesh
            rings
            vignette
        }
    }

    private var mesh: some View {
        let day = entry.dayProgress
        // A 3×3 mesh rather than stacked gradients: the interior point is
        // pulled down into the pocket the arch leaves, so the light gathers
        // under the crest and the corners fall away at their own rates.
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.55], [0.5, 0.78], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                DayHue.color(day - 0.15, brightness: 0.46),
                DayHue.color(day, brightness: 0.6),
                DayHue.color(day + 0.15, brightness: 0.42),

                DayHue.color(day - 0.1, brightness: 0.28),
                DayHue.color(day, brightness: 1, white: 0.22),
                DayHue.color(day + 0.2, brightness: 0.3),

                DayHue.color(day, brightness: 0.12),
                DayHue.color(day, brightness: 0.3),
                DayHue.color(day + 0.15, brightness: 0.1),
            ]
        )
    }

    /// The instrument texture: faint rings spreading from the card's light,
    /// there to be felt rather than seen. Without them the field is only a
    /// gradient; with them it reads as a surface the light is measured on.
    private var rings: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width * glowAnchor, y: size.height * 0.5)
            let step = size.height * 0.24
            var radius = size.height * 0.2
            while radius < size.width {
                let rect = CGRect(
                    x: centre.x - radius,
                    y: centre.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Circle().path(in: rect),
                    with: .color(.white.opacity(0.05)),
                    lineWidth: 0.5
                )
                radius += step
            }
        }
    }

    /// Corners sunk away from the light, so the card falls to near-black at
    /// its edges the way every reference does.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.32), location: 1),
            ],
            center: UnitPoint(x: glowAnchor, y: 0.45),
            startRadius: 0,
            endRadius: 200
        )
    }

    private var backdrop: some View {
        field.opacity(renderingMode == .fullColor ? 1 : 0)
    }

    // MARK: - Watch face

    /// On a face the card is drawn in a single tint, so the arch and the
    /// neighbouring lessons would only muddy it. One lesson, stated plainly.
    private var tintedCard: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(entry.lesson.map { String($0.period) } ?? "—")
                .font(.system(.headline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize()

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.lesson?.subject ?? emptyTitle)
                    .font(.system(.headline, weight: .semibold))
                    .widgetAccentable()

                Text(entry.lesson?.teacher ?? "")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(footer.plain)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Position

    /// The day's hue lifted most of the way to white: bright enough to carry
    /// the countdown and the lit edge, still unmistakably the card's colour.
    private var accent: Color {
        DayHue.color(entry.dayProgress, brightness: 1, white: 0.55)
    }

    /// `false` only when the whole week is empty — the slots then hold three
    /// blanks rather than nothing at all, which is why counting them beats
    /// asking whether the array is empty.
    private var hasAnyLesson: Bool {
        entry.slots.contains { $0 != nil }
    }

    /// The middle slot, which the lesson in focus always holds.
    private var focusSlot: Int { entry.lesson == nil ? -1 : 1 }

    /// Where the card's light falls, in unit width: over the lesson in focus,
    /// or over the gap between two lessons while a break is running.
    private var glowAnchor: CGFloat {
        guard isBreak, !entry.slots.isEmpty else { return 0.5 }
        return CGFloat(focusSlot) / CGFloat(entry.slots.count)
    }

    /// The centre of the slot at `index`, in unit width.
    private func anchor(of index: Int) -> CGFloat {
        guard !entry.slots.isEmpty else { return 0.5 }
        return (CGFloat(index) + 0.5) / CGFloat(entry.slots.count)
    }

    /// Where the marker sits, in unit width: crossing the lesson in progress,
    /// or hovering at the seam between two lessons during a break. Nothing to
    /// track before the first bell or after the last, so it is hidden.
    private var cursor: CGFloat? {
        guard let progress, !entry.slots.isEmpty else { return nil }
        let slot = 1 / CGFloat(entry.slots.count)
        switch entry.status {
        case .current:
            return slot + progress * slot
        case .upcoming where isBreak:
            return slot + (progress - 0.5) * slot * 0.3
        case .upcoming, .future, .finished:
            return nil
        }
    }

    /// How far through the lesson — or the break before it — the wearer is.
    private var progress: CGFloat? {
        let span: (start: Date, end: Date)? = switch entry.status {
        case .current:
            entry.startsAt.flatMap { start in entry.endsAt.map { (start, $0) } }
        case .upcoming:
            entry.breakStartedAt.flatMap { start in entry.startsAt.map { (start, $0) } }
        case .future, .finished:
            nil
        }
        guard let span, span.end > span.start else { return nil }
        let elapsed = entry.date.timeIntervalSince(span.start)
        return min(max(elapsed / span.end.timeIntervalSince(span.start), 0), 1)
    }

    /// `true` only when the wearer is between two lessons — before the first
    /// bell there is nothing to be between.
    private var isBreak: Bool {
        guard entry.status == .upcoming, entry.breakStartedAt != nil else { return false }
        // A lesson has to sit before the focus for there to be a gap at all.
        return entry.slots.first.flatMap { $0 } != nil
    }

    /// How long the current break runs, used to tell a corridor break from
    /// the lunch hour.
    private var breakLength: Int? {
        guard let start = entry.breakStartedAt, let end = entry.startsAt else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    // MARK: - Content

    /// The line under the arch: a label anchored at the leading edge, the
    /// number anchored at the trailing one. Every state that has anything to
    /// wait for carries a label, so the line almost always spans the card.
    private var footer: Footer {
        guard entry.lesson != nil else {
            // The day's lessons ran out — or the whole week has none to run,
            // which the slots the card was handed still show.
            return Footer(suffix: hasAnyLesson ? "오늘 수업 끝" : "이번 주 수업 없음")
        }

        switch entry.status {
        case .current:
            // A running lesson needs no label — the countdown alone, centred.
            // Only the day's last period earns a word at the leading edge.
            let label = entry.isLastLesson ? "마지막 교시" : nil
            guard let minutes = remainingMinutes else { return Footer(suffix: label ?? "수업 중") }
            guard minutes > 0 else { return Footer(prefix: label, suffix: "곧 종료") }
            return Footer(prefix: label, value: durationText(minutes), suffix: "남음")
        case .upcoming:
            return startFooter
        case .future:
            let day = entry.dayLabel ?? "다음 수업"
            guard let clock = entry.startsAt?.schoolClockText else {
                return Footer(suffix: "\(day) 첫 교시")
            }
            return Footer(prefix: day, value: clock, suffix: "시작")
        case .finished:
            return Footer(suffix: "오늘 수업 끝")
        }
    }

    /// Close to the bell the wearer wants minutes; further out, the clock time
    /// is the more useful answer. A break names itself; before the first bell
    /// there is no break to name, so the label falls back to the wait itself.
    private var startFooter: Footer {
        let label = breakLabel ?? "수업 전"
        guard let minutes = remainingMinutes else {
            guard let clock = entry.startsAt?.schoolClockText else { return Footer(suffix: "다음 수업") }
            return Footer(prefix: label, value: clock, suffix: "시작")
        }
        guard minutes > 0 else { return Footer(prefix: label, suffix: "곧 시작") }
        guard minutes > 60, let clock = entry.startsAt?.schoolClockText else {
            return Footer(prefix: label, value: "\(minutes)분", suffix: "후 시작")
        }
        return Footer(prefix: label, value: clock, suffix: "시작")
    }

    /// The gap after the fourth period runs long enough to be the lunch hour;
    /// anything shorter is the usual few minutes between rooms.
    private var breakLabel: String? {
        guard isBreak, let length = breakLength else { return nil }
        return length >= 40 ? "점심시간" : "쉬는 시간"
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)분" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }

    private var remainingMinutes: Int? {
        guard let target = entry.countdownTarget else { return nil }
        return Int((target.timeIntervalSince(entry.date) / 60).rounded(.up))
    }

    private var emptyTitle: String {
        entry.status == .finished ? "수업 끝" : "수업 없음"
    }

    private var accessibilityLabel: Text {
        guard let lesson = entry.lesson else { return Text("남은 수업 없음") }
        var parts: [String] = []
        if let day = entry.dayLabel { parts.append(day) }
        parts.append("\(lesson.period)교시")
        parts.append(lesson.subject)
        if lesson.hasTeacher { parts.append(lesson.teacher) }
        parts.append(footer.plain)
        return Text(parts.joined(separator: ", "))
    }

    /// The countdown in three parts, so the number can be set apart from what
    /// qualifies it.
    struct Footer {
        var prefix: String?
        var value: String?
        var suffix: String

        var plain: String {
            [prefix, value, suffix].compactMap { $0 }.joined(separator: " ")
        }
    }
}

/// The colour of a school day: cool at the first period, indigo across the
/// middle of it, warm by the last.
///
/// One hue carries both the arch and the field under it, so the card reads as
/// one object lit by one light rather than a shape pasted onto a backdrop.
private enum DayHue {
    private static let stops: [(r: Double, g: Double, b: Double)] = [
        (0.10, 0.36, 0.92),
        (0.30, 0.24, 0.86),
        (0.66, 0.24, 0.50),
    ]

    /// - Parameters:
    ///   - progress: 0 at the first period, 1 at the last.
    ///   - brightness: scales the colour down towards black.
    ///   - white: lifts it towards white, for the lit crest.
    static func color(_ progress: CGFloat, brightness: Double = 1, white: Double = 0) -> Color {
        let clamped = min(max(Double(progress), 0), 1)
        let position = clamped * Double(stops.count - 1)
        let index = min(Int(position), stops.count - 2)
        let fraction = position - Double(index)
        let lower = stops[index]
        let upper = stops[index + 1]

        func channel(_ from: Double, _ to: Double) -> Double {
            let value = (from + (to - from) * fraction) * brightness
            return value + (1 - value) * white
        }

        return Color(
            red: channel(lower.r, upper.r),
            green: channel(lower.g, upper.g),
            blue: channel(lower.b, upper.b)
        )
    }
}

/// The arch the lessons ride: a parabola of constant thickness that crests
/// over the middle of the card and falls away off both bottom corners.
///
/// Every measurement is a fraction of the card, and the same curve places the
/// shape and offsets the lessons standing on it, so a subject never floats off
/// the band it belongs to.
private struct Arch {
    /// The height of the whole card.
    var height: CGFloat

    /// The colour the crest rises into, measured from the top of the card.
    var inset: CGFloat { height * 0.05 }
    /// How far the arch falls from its crest to the edges of the card.
    var rise: CGFloat { height * 0.28 }
    /// The band's own depth, measured straight down.
    var thickness: CGFloat { height * 0.64 }

    var subjectSize: CGFloat { height * 0.30 }
    var flankSize: CGFloat { height * 0.26 }
    var teacherSize: CGFloat { height * 0.16 }
    var footerSize: CGFloat { height * 0.175 }
    /// The countdown outweighs everything qualifying it — the loudest number
    /// on the card, per the references.
    var footerValueSize: CGFloat { height * 0.215 }
    var markerSize: CGFloat { height * 0.085 }

    /// The middle of the band at unit position `x`.
    func centre(at x: CGFloat) -> CGFloat { inset + drop(at: x) + thickness / 2 }

    /// What a lesson stands on: its own height centred on the band, nudged
    /// down enough to leave the crest's rim to the marker.
    func textTop(at x: CGFloat, isFocus: Bool) -> CGFloat {
        centre(at: x) - contentHeight(isFocus: isFocus) / 2 + height * 0.03
    }

    /// Close enough to the laid-out height of a cell to centre it without
    /// measuring the text. Only the focus carries a second line.
    private func contentHeight(isFocus: Bool) -> CGFloat {
        guard isFocus else { return flankSize * 1.22 }
        return subjectSize * 1.22 + teacherSize * 1.22 - 1
    }

    /// How far below the crest the band sits at unit position `x`.
    func drop(at x: CGFloat) -> CGFloat {
        let distance = (x - 0.5) / 0.5
        return rise * distance * distance
    }

    /// The band's own lean at unit position `x`: the parabola's tangent,
    /// derived from the same curve `drop(at:)` samples, so text turned by it
    /// lies along the band rather than at an angle guessed to suit it.
    func tilt(at x: CGFloat, width: CGFloat) -> Angle {
        let slope = 4 * rise * (x - 0.5) / 0.5 / max(width, 1)
        return .radians(atan(Double(slope)))
    }

    var shape: ArchShape { ArchShape(arch: self) }
}

private struct ArchShape: Shape {
    var arch: Arch

    func path(in rect: CGRect) -> Path {
        // Sampled rather than drawn as one curve: a quadratic would only
        // approximate the parabola the lessons are positioned against.
        let steps = 40
        let overhang: CGFloat = 10
        let width = rect.width + overhang * 2
        let points = (0...steps).map { step -> CGPoint in
            let position = CGFloat(step) / CGFloat(steps)
            let x = rect.minX - overhang + width * position
            let unit = (x - rect.minX) / max(rect.width, 1)
            return CGPoint(x: x, y: rect.minY + arch.inset + arch.drop(at: unit))
        }

        // One closed subpath, out along the top edge and back along the
        // bottom. Stroking a centreline instead would leave every internal
        // seam of the outline visible as a hatch across the band.
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        for point in points.reversed() {
            path.addLine(to: CGPoint(x: point.x, y: point.y + arch.thickness))
        }
        path.closeSubpath()
        return path
    }
}

/// The arch's top edge alone, from the band's left overhang to `end` in unit
/// width — the piece of the day the wearer has already crossed, stroked as a
/// lit rim. Sampled from the same parabola that places the band, so the rim
/// never drifts off the edge it lights.
private struct ArchEdgeShape: Shape {
    var arch: Arch
    var end: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let overhang: CGFloat = 10
        let startX = rect.minX - overhang
        let endX = rect.minX + rect.width * min(max(end, 0), 1)
        guard endX > startX else { return path }

        let steps = 30
        for step in 0...steps {
            let x = startX + (endX - startX) * CGFloat(step) / CGFloat(steps)
            let unit = (x - rect.minX) / max(rect.width, 1)
            let point = CGPoint(x: x, y: rect.minY + arch.inset + arch.drop(at: unit))
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

#if DEBUG
struct NextLessonWidgetViewPreviews: PreviewProvider {
    static var previews: some View {
        NextLessonWidgetView(entry: .placeholder)
            .environment(\.locale, .school)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Next lesson · Smart Stack view")
    }
}
#endif
