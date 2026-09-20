import SwiftUI

/// Chalk on iron. A blackboard in a gym: chalk dust, red tape, gold for records.
enum Chalk {
    static let board = Color(red: 0.043, green: 0.043, blue: 0.047)      // #0B0B0C
    static let slate = Color(red: 0.086, green: 0.086, blue: 0.094)      // cards
    static let slateHi = Color(red: 0.125, green: 0.125, blue: 0.137)
    static let white = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let dust = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.55)
    static let faint = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.22)
    static let line = Color(red: 0.96, green: 0.95, blue: 0.92).opacity(0.10)
    static let red = Color(red: 0.90, green: 0.22, blue: 0.20)           // tape
    static let redDeep = Color(red: 0.55, green: 0.10, blue: 0.10)
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.20)
    static let green = Color(red: 0.36, green: 0.82, blue: 0.48)
}

extension Font {
    /// Big hand-lettered feel: rounded, black, italic.
    static func slab(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func chalk(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
    static func digits(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded).monospacedDigit() }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

/// The blackboard: near black, chalk dust in the corners, faint smears.
struct BoardBackground: View {
    var body: some View {
        ZStack {
            Chalk.board
            RadialGradient(colors: [Chalk.white.opacity(0.07), .clear], center: .init(x: 0.15, y: 0.05), startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Chalk.red.opacity(0.10), .clear], center: .init(x: 1.05, y: 1.0), startRadius: 20, endRadius: 520)
            Canvas { ctx, size in
                var seed: UInt64 = 0x2545F4914F6CDD1D
                for i in 0..<1400 {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let x = CGFloat(seed >> 33 % 10000) / 10000 * size.width
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    let y = CGFloat(seed >> 33 % 10000) / 10000 * size.height
                    let w: CGFloat = i % 7 == 0 ? 2 : 1
                    ctx.fill(Path(CGRect(x: x, y: y, width: w, height: w)), with: .color(Chalk.white.opacity(i % 5 == 0 ? 0.10 : 0.05)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// A strip of red gaffer tape with chalk lettering, slightly askew.
struct Tape: View {
    let text: String
    var tilt: Double = -1.5
    var body: some View {
        Text(text.uppercased())
            .font(.chalk(12, .black))
            .tracking(2.2)
            .foregroundStyle(Chalk.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Rectangle()
                    .fill(LinearGradient(colors: [Chalk.red, Chalk.redDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 3)
            )
            .rotationEffect(.degrees(tilt))
    }
}

/// Section label written in chalk.
struct Eyebrow: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased()).font(.chalk(11, .bold)).tracking(2).foregroundStyle(Chalk.faint)
    }
}

extension View {
    /// A slate card with a chalk hairline, as if a rectangle were drawn on the board.
    func slate(padding: CGFloat = 16, radius: CGFloat = 18) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Chalk.slateHi, Chalk.slate], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Chalk.line, lineWidth: 1))
    }
}

/// A big chalk number with a small unit.
struct Figure: View {
    let value: String
    let unit: String
    var color: Color = Chalk.white
    var size: CGFloat = 34
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(value).font(.digits(size, .black)).foregroundStyle(color)
            if !unit.isEmpty { Text(unit).font(.chalk(13, .bold)).foregroundStyle(Chalk.dust) }
        }
    }
}

/// Primary chalk button: red tape block.
struct TapeButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = Chalk.red
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .black)) }
                Text(title.uppercased()).font(.chalk(14, .black)).tracking(1.5)
            }
            .foregroundStyle(fill == Chalk.gold ? Chalk.board : Chalk.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill).shadow(color: fill.opacity(0.35), radius: 14, y: 6))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title.uppercased()).font(.chalk(12, .black)).tracking(1.2)
            }
            .foregroundStyle(Chalk.dust)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Chalk.faint, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }
}

/// The floating tab bar: a strip of slate with chalk icons, the active one under a red tape tab.
struct BoardTabBar: View {
    @Binding var selection: Tab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = t }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: t.icon).font(.system(size: 18, weight: selection == t ? .black : .medium))
                        Text(t.rawValue.uppercased()).font(.chalk(9, .black)).tracking(1)
                    }
                    .foregroundStyle(selection == t ? Chalk.white : Chalk.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selection == t {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Chalk.red.opacity(0.9))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Chalk.slate).shadow(color: .black.opacity(0.6), radius: 20, y: 10))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Chalk.line, lineWidth: 1))
        .padding(.horizontal, 18)
    }
}

/// A starburst "PR" mark, drawn in chalk gold.
struct PRBadge: View {
    var body: some View {
        ZStack {
            Star(points: 12, inner: 0.72).fill(Chalk.gold)
            Text("PR").font(.chalk(9, .black)).foregroundStyle(Chalk.board)
        }
        .frame(width: 30, height: 30)
    }
}

struct Star: Shape {
    var points: Int
    var inner: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<(points * 2) {
            let a = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let rr = i % 2 == 0 ? r : r * inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
