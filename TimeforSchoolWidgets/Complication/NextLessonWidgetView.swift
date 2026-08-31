import SwiftUI
import Synchronization
import UIKit
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
                        // Centred on the rim rather than hung below it: the
                        // crest is also where the subject is set, and a
                        // marker sunk into the band lands on the text.
                        y: arch.inset + arch.drop(at: cursor) - arch.markerSize * 0.05
                    )
            }
        }
    }

    private func lessons(_ arch: Arch, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: Self.lessonSpacing) {
            // A week without a single lesson — a weekend with nothing fetched
            // ahead, or an empty timetable — still gets the arch, with its
            // title riding the crest where the focus would.
            if !hasAnyLesson {
                Text(emptyTitle)
                    .font(.system(size: arch.subjectSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: arch.thickness)
                    .offset(y: arch.bandTop(at: 0.5) + arch.nudge(.single(hasTeacher: false)))
            } else {
                let widths = slotWidths(row: width - Self.lessonInset * 2)
                ForEach(Array(entry.slots.enumerated()), id: \.offset) { index, lesson in
                    let focus = index == focusSlot
                    let position = anchor(of: index, width: width)
                    let layout = layout(for: lesson, isFocus: focus, arch: arch, width: widths[index])
                    // The size the subject and its period are set at, fitted
                    // to the width the slot actually has.
                    let size = lesson.map {
                        fittedSize(for: $0, layout: layout, isFocus: focus, arch: arch, width: widths[index])
                    } ?? arch.periodSize(layout, isFocus: focus)
                    cell(for: lesson, layout: layout, size: size, isFocus: focus, arch: arch, width: widths[index])
                        // Centred by the layout system inside a frame as deep
                        // as the band, rather than by a guess at how tall the
                        // text will come out. Hangul sets taller than the
                        // metrics such a guess assumes, and the shortfall
                        // showed as every lesson riding low on the band — the
                        // focus twice as far as its flanks, having two lines
                        // to be wrong about.
                        .frame(width: widths[index], height: arch.thickness)
                        // The flanks lean with the band: each is turned to
                        // the arch's own tangent where it stands, so the
                        // lessons ride the curve rather than hover over it.
                        // The focus sits at the crest, where the tangent is
                        // flat anyway.
                        .rotationEffect(focus ? .zero : arch.tilt(at: position, width: width))
                        // The frame now spans the band exactly, so the whole
                        // placement is where the band's top edge falls here.
                        .offset(y: arch.bandTop(at: position) + arch.nudge(layout))
                }
            }
        }
        .padding(.horizontal, Self.lessonInset)
    }

    @ViewBuilder private func cell(
        for lesson: Lesson?,
        layout: LessonLayout,
        size: CGFloat,
        isFocus: Bool,
        arch: Arch,
        width: CGFloat
    ) -> some View {
        if let lesson {
            // Subject over teacher, set tight: the pair reads as one block,
            // and the height it saves is clearance between the crest's marker
            // and the top of the subject.
            VStack(spacing: -2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(lesson.period))
                        .font(.system(size: size, weight: isFocus ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(isFocus ? 0.5 : 0.3))
                        .lineLimit(1)

                    // The flanks sit much further back than the focus — far
                    // enough that at a glance only one lesson is on the card.
                    Text(displaySubject(lesson, layout: layout, size: size, width: width))
                        .font(.system(size: size, weight: isFocus ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(isFocus ? 1 : 0.55))
                        // A subject the school writes out in full — 창의적
                        // 체험활동 — is set over two lines rather than shrunk
                        // to nothing: broken at its own space it stays the
                        // size of a subject, and the teacher gives up the
                        // room, being the one thing on the card nobody reads
                        // twice.
                        .lineLimit(layout.isWrapped ? 2 : 1)
                        .multilineTextAlignment(.center)
                        // The size above is already fitted to the slot; this
                        // is only a backstop for the rounding between what
                        // was measured and what gets laid out.
                        .minimumScaleFactor(0.9)
                }

                // Only the lesson in focus carries a teacher: three subjects
                // over three names is more than the band can hold.
                if layout.showsTeacher {
                    Text(lesson.teacher)
                        .font(.system(size: arch.teacherSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: width)
        } else {
            // The edge of the day: the slot stays empty so the lesson in
            // focus keeps the crest.
            Color.clear.frame(width: width)
        }
    }

    /// The countdown, set as one phrase under the crest: a dim label, the
    /// number loud and in the day's own colour, then what qualifies it. The
    /// line is always centred — the pocket the arch leaves is centred, and a
    /// label pushed out to the leading edge climbs into the band's underside.
    private func footerLine(_ arch: Arch) -> some View {
        let line = footer
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            if let prefix = line.prefix {
                Text(prefix)
                    .font(.system(size: arch.footerSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }

            if let value = line.value {
                // "24분" is a number and a unit, not one word: the references
                // set the figure loud and let what it is measured in stay
                // with the rest of the sentence. Splitting on the digits
                // themselves handles a clock time, a run of minutes, and an
                // hour and minutes together without a case for each.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ForEach(Array(Self.runs(of: value).enumerated()), id: \.offset) { _, run in
                        if run.isFigure {
                            Text(run.text)
                                .font(.system(size: arch.footerValueSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(accent)
                                .monospacedDigit()
                                .shadow(color: accent.opacity(0.5), radius: 3)
                        } else {
                            Text(run.text)
                                .font(.system(size: arch.footerSize, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }

            Text(line.suffix)
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
            // Gathered into one path and stroked once: the rings share a colour
            // and a width, so a stroke apiece is one drawing call per ring for
            // no visible difference.
            var path = Path()
            while radius < size.width {
                path.addEllipse(in: CGRect(
                    x: centre.x - radius,
                    y: centre.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                radius += step
            }
            context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
        }
    }

    /// Corners sunk away from the light, so the card falls to near-black at
    /// its edges the way every reference does.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.2), location: 1),
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

    /// What the countdown and the lit edge are stated in.
    private var accent: Color { DayHue.accent(entry.dayProgress) }

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

    /// The inset and the gaps the lesson row is actually laid out with. The
    /// anchors are measured through them: a slot's share of the bare card is
    /// not where the padded row puts it, and a flank placed against the wrong
    /// unit position rides the curve a little off the band.
    private static let lessonInset: CGFloat = 5
    private static let lessonSpacing: CGFloat = 3

    /// How a cell is set, once its subject has been measured against the slot
    /// it has to stand in. Measured rather than guessed from length: 진로와
    /// 직업 fits where 창의적 체험 활동 does not, and how much of either fits
    /// depends on the watch as much as on the string.
    ///
    /// Three steps down, each taken only when the one above it will not hold
    /// the subject whole: full size over the teacher, a smaller size still
    /// over the teacher, then two lines with the teacher given up. Truncation
    /// is the last resort — half a subject cannot be read at any size.
    private func layout(for lesson: Lesson?, isFocus: Bool, arch: Arch, width: CGFloat) -> LessonLayout {
        guard let lesson, isFocus else { return .flank }

        // Shrinking a little is better than breaking: a subject only just too
        // wide reads better held on one line.
        let subject = Self.capped(lesson.subject)
        if room(for: lesson, size: arch.subjectSize, width: width)
            .map({ measure(subject, size: arch.subjectSize) <= $0 / 0.8 }) == true {
            return .single(hasTeacher: lesson.hasTeacher)
        }

        guard let room = room(for: lesson, size: arch.reducedSize, width: width),
              measure(subject, size: arch.reducedSize) <= room
        else { return .reduced(lines: 2, hasTeacher: false) }
        return .reduced(lines: 1, hasTeacher: lesson.hasTeacher)
    }

    /// The size the period and the subject are both set at: the layout's own
    /// size, or as far down as the subject has to come to fit its slot.
    ///
    /// Both are set from one number rather than left to `minimumScaleFactor`,
    /// which shrinks each `Text` on its own: a period number is one digit and
    /// never needs to shrink, so a long subject beside it ends up set smaller
    /// than the number labelling it.
    private func fittedSize(
        for lesson: Lesson,
        layout: LessonLayout,
        isFocus: Bool,
        arch: Arch,
        width: CGFloat
    ) -> CGFloat {
        let base = arch.periodSize(layout, isFocus: isFocus)
        guard let room = room(for: lesson, size: base, width: width) else { return base }
        // A wrapped subject has a second line to spread into, so it is
        // measured against both.
        let available = room * CGFloat(layout.isWrapped ? 2 : 1)
        let subject = measure(Self.capped(lesson.subject), size: base)
        guard subject > available else { return base }
        // A floor, not a licence to shrink: past this the subject is smaller
        // than the countdown under it and stops reading as the thing the card
        // is about. Anything that will not fit at this size is cut instead.
        return max(base * available / subject, base * 0.75)
    }

    /// What the subject has to fit in: the slot, less the period number
    /// standing in front of it. `nil` when there is no room at all.
    private func room(for lesson: Lesson, size: CGFloat, width: CGFloat) -> CGFloat? {
        let room = width - measure(String(lesson.period), size: size) - 3
        return room > 0 ? room : nil
    }

    /// Text measurement is the card's hottest repeated work: fitting one
    /// subject measures it several times over, and trimming a long one measures
    /// again for every character it drops. The same handful of strings come
    /// back at the same handful of sizes on every entry in a timeline, so the
    /// widths are worth keeping.
    private static let widths = Mutex<[Measurement: CGFloat]>([:])

    private struct Measurement: Hashable {
        var text: String
        var size: CGFloat
    }

    private func measure(_ text: String, size: CGFloat) -> CGFloat {
        let key = Measurement(text: text, size: size)
        if let cached = Self.widths.withLock({ $0[key] }) { return cached }
        let width = text.size(withAttributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .semibold)
        ]).width
        Self.widths.withLock { widths in
            // A day's worth of subjects at a few sizes each; the bound is only
            // there so a pathological feed cannot grow this without end.
            if widths.count > 512 { widths.removeAll(keepingCapacity: true) }
            widths[key] = width
        }
        return width
    }

    /// What the subject is actually drawn as: broken so that it can wrap, and
    /// cut with an ellipsis when even two lines will not hold it.
    ///
    /// The cut is made here rather than left to the text view. A string broken
    /// by zero-width spaces truncates without ever drawing its ellipsis, so a
    /// subject too long for the card would simply stop, with nothing to say
    /// that the rest of it exists.
    private func displaySubject(
        _ lesson: Lesson,
        layout: LessonLayout,
        size: CGFloat,
        width: CGFloat
    ) -> String {
        let subject = Self.capped(lesson.subject)
        guard layout.isWrapped else { return subject }

        // The first line stands beside the period number; the second has the
        // slot to itself. Measured a little short, since where the line
        // actually breaks is the text view's call, not ours.
        let capacity = ((room(for: lesson, size: size, width: width) ?? width) + width) * 0.95
        let alreadyCut = subject.hasSuffix(Self.ellipsis)
        guard alreadyCut || measure(subject, size: size) > capacity else {
            return Self.breakable(subject)
        }

        // Cut a character short of the true capacity: the ellipsis has to end
        // up on the second line, and a cut made right at the edge pushes it
        // onto a third line that the line limit then throws away — taking the
        // only sign that the subject was cut with it.
        let room = capacity - measure("가", size: size)
        var head = Array(alreadyCut ? String(subject.dropLast()) : subject)
        while !head.isEmpty, measure(String(head) + Self.ellipsis, size: size) > room {
            head.removeLast()
        }
        return Self.breakable(String(head)) + Self.ellipsis
    }

    /// The longest subject the card sets in full. The feed occasionally puts a
    /// whole course title where a subject belongs, and past about this length
    /// there is no size the band can hold that is still read at a glance — the
    /// opening of the name says more than all of it set too small to read.
    private static let subjectLimit = 10
    private static let ellipsis = "…"

    private static func capped(_ subject: String) -> String {
        guard subject.count > subjectLimit else { return subject }
        let head = subject.prefix(subjectLimit).trimmingCharacters(in: .whitespaces)
        return head + ellipsis
    }

    /// Korean breaks lines at spaces, so a subject written as one unbroken run
    /// — 국제사회문화탐구 — would sooner truncate than take the second line it
    /// has been given. Zero-width spaces let it break between characters,
    /// which is where a Korean reader breaks it anyway.
    private static func breakable(_ subject: String) -> String {
        guard !subject.contains(" ") else { return subject }
        return subject.map(String.init).joined(separator: "\u{200B}")
    }

    /// The share of the row the lesson in focus is given. It carries the
    /// longest string on the card — a subject written out in full, over a
    /// teacher — while each flank carries a number and a word, so an even
    /// three-way split starves the only line anyone reads.
    private static let focusShare: CGFloat = 0.44

    /// How wide each slot is laid out, leading to trailing.
    private func slotWidths(row: CGFloat) -> [CGFloat] {
        let count = entry.slots.count
        guard count > 0 else { return [] }
        let free = row - Self.lessonSpacing * CGFloat(count - 1)
        guard free > 0 else { return Array(repeating: 0, count: count) }
        // With no lesson in focus — the day already over — there is nothing
        // to favour, so the row splits evenly.
        guard count > 1, entry.slots.indices.contains(focusSlot) else {
            return Array(repeating: free / CGFloat(count), count: count)
        }
        let focus = free * Self.focusShare
        let flank = (free - focus) / CGFloat(count - 1)
        return (0..<count).map { $0 == focusSlot ? focus : flank }
    }

    /// The centre of the slot at `index`, in unit width of the whole card —
    /// the frame the arch itself is drawn in.
    private func anchor(of index: Int, width: CGFloat) -> CGFloat {
        let widths = slotWidths(row: width - Self.lessonInset * 2)
        guard width > 0, widths.indices.contains(index) else { return 0.5 }
        let leading = widths[..<index].reduce(Self.lessonInset) { $0 + $1 + Self.lessonSpacing }
        return (leading + widths[index] / 2) / width
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
            return runningFooter
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

    /// A lesson in progress counts down to what comes after it, not to its own
    /// bell: sitting in fourth period, the answer the wearer wants is how long
    /// until lunch. The day's last lesson has nothing after it to name, so it
    /// alone counts down to itself.
    private var runningFooter: Footer {
        guard let minutes = remainingMinutes else {
            return Footer(suffix: entry.isLastLesson ? "마지막 교시" : "수업 중")
        }
        guard let label = nextBreakLabel else {
            let last = entry.isLastLesson ? "마지막 교시" : nil
            guard minutes > 0 else { return Footer(prefix: last, suffix: "곧 종료") }
            return Footer(prefix: last, value: durationText(minutes), suffix: "남음")
        }
        guard minutes > 0 else { return Footer(prefix: label, suffix: "곧 시작") }
        return Footer(prefix: label, value: durationText(minutes), suffix: "후 시작")
    }

    /// A break counts down as itself — what is left of it — rather than as the
    /// lesson on the far side. Before the first bell there is no break to
    /// count, only the wait, which is stated as the wait it is.
    ///
    /// Close to the bell the wearer wants minutes; further out, the clock time
    /// is the more useful answer.
    private var startFooter: Footer {
        if let label = breakLabel {
            guard let minutes = remainingMinutes else { return Footer(prefix: label, suffix: "진행 중") }
            guard minutes > 0 else { return Footer(prefix: label, suffix: "곧 종료") }
            return Footer(prefix: label, value: durationText(minutes), suffix: "남음")
        }

        let label = "수업 전"
        guard let minutes = remainingMinutes else {
            guard let clock = entry.startsAt?.schoolClockText else { return Footer(suffix: "다음 수업") }
            return Footer(prefix: label, value: clock, suffix: "시작")
        }
        guard minutes > 0 else { return Footer(prefix: label, suffix: "곧 시작") }
        guard minutes > 60, let clock = entry.startsAt?.schoolClockText else {
            return Footer(prefix: label, value: durationText(minutes), suffix: "후 시작")
        }
        return Footer(prefix: label, value: clock, suffix: "시작")
    }

    /// The gap after the fourth period runs long enough to be the lunch hour;
    /// anything shorter is the usual few minutes between rooms.
    private var breakLabel: String? {
        guard isBreak, let length = breakLength else { return nil }
        return Self.breakName(minutes: length)
    }

    /// The same naming for the gap the current lesson is running towards.
    private var nextBreakLabel: String? {
        entry.breakAfterLength.map(Self.breakName)
    }

    private static func breakName(minutes: Int) -> String {
        minutes >= 40 ? "점심시간" : "쉬는 시간"
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

    /// One stretch of a value that is set all one way: either the figure
    /// itself or the unit riding with it.
    struct Run {
        var text: String
        var isFigure: Bool
    }

    /// Splits a value into its figures and everything between them. A colon
    /// counts as part of a clock time rather than a separator, so "09:30"
    /// stays one figure.
    static func runs(of value: String) -> [Run] {
        var runs: [Run] = []
        for character in value {
            let isFigure = character.isNumber || character == ":"
            if var last = runs.last, last.isFigure == isFigure {
                last.text.append(character)
                runs[runs.count - 1] = last
            } else {
                runs.append(Run(text: String(character), isFigure: isFigure))
            }
        }
        return runs
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

    /// What the card states a value in. The field's own hue lifted towards
    /// white only ever gives a paler version of the ground it is read
    /// against, which is no accent at all; these are the hues that ground
    /// throws off when it is lit — icy at the first period, gold by the last
    /// — so the number reads as the brightest thing on the card rather than
    /// the palest.
    private static let accentStops: [(r: Double, g: Double, b: Double)] = [
        (0.53, 0.93, 1.00),
        (0.74, 0.90, 1.00),
        (1.00, 0.83, 0.60),
    ]

    /// - Parameters:
    ///   - progress: 0 at the first period, 1 at the last.
    ///   - brightness: scales the colour down towards black.
    ///   - white: lifts it towards white, for the lit crest.
    static func color(_ progress: CGFloat, brightness: Double = 1, white: Double = 0) -> Color {
        interpolate(stops, progress, brightness: brightness, white: white)
    }

    /// The accent for a day at `progress`, warming with it.
    static func accent(_ progress: CGFloat) -> Color {
        interpolate(accentStops, progress)
    }

    private static func interpolate(
        _ stops: [(r: Double, g: Double, b: Double)],
        _ progress: CGFloat,
        brightness: Double = 1,
        white: Double = 0
    ) -> Color {
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

/// How one lesson is set on the band.
private enum LessonLayout {
    /// A neighbour: a number and a subject, dim and small.
    case flank
    /// The focus at its own size, on one line, over its teacher.
    case single(hasTeacher: Bool)
    /// The focus set smaller because its subject is long — on one line with
    /// the teacher if that is enough room, on two lines without if it is not.
    /// The teacher is what gives way: it is the one thing on the card nobody
    /// reads twice.
    case reduced(lines: Int, hasTeacher: Bool)

    var isWrapped: Bool { if case .reduced(let lines, _) = self { lines > 1 } else { false } }

    var showsTeacher: Bool {
        switch self {
        case .flank: false
        case .single(let hasTeacher): hasTeacher
        case .reduced(_, let hasTeacher): hasTeacher
        }
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
    var teacherSize: CGFloat { height * 0.185 }
    var footerSize: CGFloat { height * 0.155 }
    /// The countdown outweighs everything qualifying it — the loudest number
    /// on the card, per the references, which set a value at half again what
    /// its units are set at rather than a hair over.
    var footerValueSize: CGFloat { height * 0.245 }
    var markerSize: CGFloat { height * 0.085 }

    /// The size a cell's subject and period are set at. A wrapped subject
    /// gives up some size to buy its second line — two lines at the focus's
    /// full size are taller than the band itself.
    func periodSize(_ layout: LessonLayout, isFocus: Bool) -> CGFloat {
        switch layout {
        case .flank: isFocus ? subjectSize : flankSize
        case .single: subjectSize
        case .reduced: reducedSize
        }
    }

    /// What a long subject is set at. Two lines at the focus's own size are
    /// taller than the band itself, so the second line is bought with size.
    var reducedSize: CGFloat { height * 0.215 }

    /// The band's top edge at unit position `x` — what a cell as deep as the
    /// band is offset by, so that centring the text inside that frame centres
    /// it on the band.
    func bandTop(at x: CGFloat) -> CGFloat { inset + drop(at: x) }

    /// The one thing measurement cannot give: the band's underside is in
    /// shadow and its lit upper face is not, so text centred exactly reads
    /// low. The flanks are lifted off the geometric centre; a lesson carrying
    /// a teacher underneath is left alone, its second line already balancing
    /// the block against the crest where the marker rides.
    func nudge(_ layout: LessonLayout) -> CGFloat {
        switch layout {
        case .flank: -height * 0.02
        case .single, .reduced: 0
        }
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
