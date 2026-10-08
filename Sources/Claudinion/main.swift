import AppKit

// MARK: - Hook mode
// Claude Code runs `Claudinion --hook` for each hook event. It reads the event JSON on stdin and
// appends a one-line summary to ~/.claude/claudinion/events.jsonl, which the running pet watches.

let eventsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claudinion")
let eventsURL = eventsDir.appendingPathComponent("events.jsonl")

func runHook() -> Never {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { exit(0) }
    var out: [String: Any] = ["ts": Date().timeIntervalSince1970]
    for key in ["hook_event_name", "tool_name", "notification_type", "session_id"] {
        if let v = obj[key] as? String { out[key] = v }
    }
    guard var line = try? JSONSerialization.data(withJSONObject: out) else { exit(0) }
    line.append(0x0A)
    try? FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)
    if let size = (try? FileManager.default.attributesOfItem(atPath: eventsURL.path))?[.size] as? Int,
       size > 512_000 {
        try? Data().write(to: eventsURL)
    }
    if let f = fopen(eventsURL.path, "a") {
        line.withUnsafeBytes { _ = fwrite($0.baseAddress, 1, line.count, f) }
        fclose(f)
    }
    exit(0)
}

if CommandLine.arguments.contains("--hook") { runHook() }

// MARK: - Look

var U: CGFloat = 8                  // one sprite pixel, in points (changed by the size setting)
let canvasCols: CGFloat = 26
let canvasRows: CGFloat = 20
var canvasSize: NSSize { NSSize(width: canvasCols * U, height: canvasRows * U) }
let bodyX: CGFloat = 7              // where the 12x9 body grid sits inside the canvas
let bodyY: CGFloat = canvasRows - 9

// Light and dark themes. `darkTheme` follows the Appearance setting (or macOS when set to Auto).
var darkTheme = true
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
var orange: NSColor { darkTheme ? rgb(0.80, 0.44, 0.32) : rgb(0.85, 0.47, 0.34) }
var outlineColor: NSColor { darkTheme ? rgb(1, 1, 1, 0.22) : rgb(0, 0, 0, 0.22) }
let eyeColor = rgb(0.08, 0.08, 0.08)

func paletteColor(_ ch: Character) -> NSColor? {
    switch ch {
    case "o": return orange
    case "k": return eyeColor
    case "w": return darkTheme ? .white : rgb(0.55, 0.70, 0.88)
    case "l": return darkTheme ? rgb(0.82, 0.84, 0.88) : rgb(0.42, 0.44, 0.50)
    case "m": return darkTheme ? rgb(0.55, 0.58, 0.65) : rgb(0.48, 0.50, 0.56)
    case "r": return rgb(0.92, 0.27, 0.27)
    case "b": return rgb(0.30, 0.55, 0.95)
    case "g": return rgb(0.30, 0.80, 0.42)
    case "y": return darkTheme ? rgb(1.00, 0.84, 0.20) : rgb(0.90, 0.68, 0.05)
    case "p": return rgb(0.96, 0.52, 0.78)
    case "n": return rgb(0.58, 0.37, 0.20)
    case "c": return darkTheme ? rgb(0.50, 0.85, 1.00) : rgb(0.20, 0.60, 0.92)
    default: return nil
    }
}

enum Art {
    static let z = ["llll", "..l.", ".l..", "llll"]
    static let bang = ["rr", "rr", "rr", "rr", "..", "rr"]
    static let question = [".yyy.", "y...y", "...y.", "..y..", ".....", "..y.."]
    static let note = ["..bb", "..b.", "..b.", "bbb.", "bbb."]
    static let heart = [".rr.rr.", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."]
    static let ball = [".rr.", "rwrr", "rrrr", ".rr."]
    static let dot = ["ll", "ll"]
    static let star = [".y.", "yyy", ".y."]
    static let sweat = [".c.", "ccc", "ccc", ".c."]
    static let crumb = ["n"]
    static let magnifier = [".kkk...", "kcwck..", "kccck..", "kccck..", ".kkk...", "....nn.", ".....nn"]
    static let laptop = [
        [".kkkkkkkk.", ".kggkgggk.", ".kkgggkkk.", ".kgkggggk.", ".kkkkkkkk.", "llllllllll"],
        [".kkkkkkkk.", ".kgggkggk.", ".kgkkgggk.", ".kkggkkkk.", ".kkkkkkkk.", "llllllllll"],
    ]
    static let hammerUp = ["lllll", "lllll", "..n..", "..n..", "..n..", "..n.."]
    static let hammerDown = ["....ll", "nnnnll", "....ll"]
    static let brick = ["rrrr", "rrrr"]
    static let globe = [
        ["..bbb..", ".bgbbb.", "bggbbbb", "bbggbgb", "bbbbggb", ".bbbgb.", "..bbb.."],
        ["..bbb..", ".bbbgb.", "bbbggbb", "bgbbggb", "bggbbbb", ".bgbbb.", "..bbb.."],
    ]
    static let check = ["......g", ".....gg", "g...gg.", "gg.gg..", ".ggg...", "..g...."]
    static let book = [
        ["nwwwwnwwwwn", "nwkkwnwkkwn", "nwwwwnwwwwn", "nwkkwnwkkwn", "nnnnnnnnnnn"],
        ["nwwwwnnwwwn", "nwkkwnnwkwn", "nwwwwnnwwwn", "nwkkwnnwkwn", "nnnnnnnnnnn"],
    ]
    static let cookie = [".nnn.", "nknnn", "nnnkn", "nknnn", ".nnn."]
    static let butterfly = [["pp.pp", "ppkpp", ".p.p."], [".....", "ppkpp", "....."]]
    static let dumbbell = ["kk" + String(repeating: ".", count: 18) + "kk",
                           "kk" + String(repeating: "l", count: 18) + "kk",
                           "kk" + String(repeating: ".", count: 18) + "kk"]
    static let glove = [".rr", "rrr", "rrr"]
    static let punchingBag = ["..k..", "..k..", ".rrr.", "rrrrr", "rrrrr", "rrrrr", "rrrrr", "rrrrr", "rrrrr", ".rrr."]
    static let headband = [String(repeating: "r", count: 16)]
    static let showerHead = ["..........ll", "..........ll", "..........ll", "..........ll",
                             "..llllllllll", ".llllllllll."]
    static let bubble = [".w.", "w.w", ".w."]
    static let fedora = ["..nnnn..", "..nnnn..", "nnnnnnnn"]
    static let blaster = ["lllllll", "bb.....", "bb....."]
    static let laser = ["rrrr"]
    static let smoke = [".l.", "lll", ".l."]
    static let glasses = ["kkkk......kkkk", "k..kkkkkkkk..k", "k..k......k..k", "kkkk......kkkk"]
    static let mug = ["llll.", "lnnll", "lnnl.", "llll."]
    static let codeGlyphs = [
        [".gg.gg.", ".g...g.", "g.....g", ".g...g.", ".gg.gg."],   // { }
        [".g.", "gg.", ".g.", ".g.", "ggg"],                       // 1
        ["ggg", "g.g", "g.g", "g.g", "ggg"],                       // 0
    ]
    static let cloud = [".mmm.mm..", "mmmmmmmmm", ".mmmmmmm."]
    static func juggleBall(_ c: Character) -> [String] { [".\(c).", "\(c)\(c)\(c)", ".\(c)."] }
    static func pixel(_ c: Character) -> [String] { [String(c)] }
}

// MARK: - Pose

enum Arm { case out, up, down, raised, punch, hidden }
enum Eyes { case open, closed, happy, dizzy, sad, big, look(CGFloat, CGFloat) }
enum Mouth { case none, o, smile }

struct Pose {
    var dx: CGFloat = 0, dy: CGFloat = 0     // body offset in sprite pixels (dy < 0 is up)
    var rot: CGFloat = 0
    var sx: CGFloat = 1, sy: CGFloat = 1     // squash and stretch, anchored at the feet
    var left = Arm.out, right = Arm.out
    var legs: [CGFloat] = [2, 2, 2, 2]       // leg heights, 0 hides a leg
    var eyes = Eyes.open
    var mouth = Mouth.none
    var color = orange

    mutating func sit() { legs = [0, 0, 0, 0]; dy += 2 }
    mutating func walk(_ t: Int, every n: Int = 3) { legs = (t / n) % 2 == 0 ? [1, 2, 1, 2] : [2, 1, 2, 1] }
    mutating func front(_ f: CGFloat, _ a: Arm) { if f > 0 { right = a } else { left = a } }
    mutating func back(_ f: CGFloat, _ a: Arm) { if f > 0 { left = a } else { right = a } }
}

struct Prop { var art: [String]; var x: CGFloat; var y: CGFloat; var s: CGFloat = 0.5 }

struct Frame {
    var pose = Pose()
    var props: [Prop] = []
    var vx: CGFloat = 0          // horizontal walking speed, sprite pixels per tick
    var offscreen = false        // allowed to leave the screen (and wrap around)
}

// MARK: - Actions

enum Act: String, CaseIterable {
    // Free play
    case walk, run, sleep, roll, hop, dance, wave, keepyUppy, sit, lookAround
    case stretch, spin, exercise, juggle, eat, read, sing, backflip, chaseButterfly, meditate
    case fight, workout, shower, whip, blaster, coding, crying, depressed, playDead
    // Claude reactions
    case wakeUp, perk, thinking, typing, searching, building, browsing, sad, alert, celebrate
    case dizzy, goodbye, squish, wrap, idle

    /// Free-play actions, grouped for the menu and the settings window.
    static let categories: [(name: String, acts: [Act])] = [
        ("Moving", [.walk, .run, .hop, .roll, .spin, .backflip, .chaseButterfly]),
        ("Fun", [.dance, .wave, .sing, .keepyUppy, .juggle, .eat, .playDead]),
        ("Sports", [.exercise, .workout, .fight, .whip, .blaster]),
        ("Chill", [.sit, .lookAround, .stretch, .read, .meditate, .shower, .sleep]),
        ("Work", [.coding]),
        ("Moods", [.crying, .depressed]),
    ]
    static let freePlay: [Act] = categories.flatMap { $0.acts }
    /// Claude reactions, in the order they usually happen during a session.
    static let claude: [Act] = [.wakeUp, .perk, .thinking, .searching, .typing, .building, .browsing, .alert,
                                .sad, .squish, .wrap, .celebrate, .dizzy, .goodbye]

    var isLoop: Bool { [.thinking, .typing, .searching, .building, .browsing, .alert, .squish].contains(self) }

    var title: String {
        switch self {
        case .walk: return "Walk"
        case .run: return "Run"
        case .sleep: return "Sleep"
        case .roll: return "Roll"
        case .hop: return "Hop"
        case .dance: return "Dance"
        case .wave: return "Wave"
        case .keepyUppy: return "Play Ball"
        case .sit: return "Sit"
        case .lookAround: return "Look Around"
        case .stretch: return "Stretch & Yawn"
        case .spin: return "Spin"
        case .exercise: return "Lift Weights"
        case .juggle: return "Juggle"
        case .eat: return "Eat a Cookie"
        case .read: return "Read a Book"
        case .sing: return "Sing"
        case .backflip: return "Backflip"
        case .chaseButterfly: return "Chase a Butterfly"
        case .meditate: return "Meditate"
        case .fight: return "Boxing"
        case .workout: return "Jumping Jacks"
        case .shower: return "Shower"
        case .whip: return "Use a Whip"
        case .blaster: return "Use a Blaster"
        case .coding: return "Coding"
        case .crying: return "Cry"
        case .depressed: return "Feel Down"
        case .playDead: return "Play Dead"
        case .wakeUp: return "Wake Up – session starts"
        case .perk: return "Perk Up – you send a message"
        case .thinking: return "Pace – thinking"
        case .typing: return "Laptop – running commands"
        case .searching: return "Magnifier – reading & searching"
        case .building: return "Hammer – editing files"
        case .browsing: return "Globe – using the web"
        case .sad: return "Sad – a tool failed"
        case .alert: return "Jump with ! – needs you"
        case .celebrate: return "Celebrate – finished"
        case .dizzy: return "Dizzy – API error"
        case .goodbye: return "Wave Goodbye – session ends"
        case .squish: return "Squished – compacting"
        case .wrap: return "Run Off Screen – folder changed"
        case .idle: return "Idle"
        }
    }

    func duration() -> Int {
        switch self {
        case .walk: return Int.random(in: 50...120)
        case .run: return Int.random(in: 30...60)
        case .sleep: return Int.random(in: 150...300)
        case .sit: return Int.random(in: 80...150)
        case .dance: return Int.random(in: 72...120)
        case .read: return Int.random(in: 120...180)
        case .meditate: return Int.random(in: 120...180)
        case .chaseButterfly: return Int.random(in: 96...144)
        case .idle: return Int.random(in: 12...36)
        case .fight, .workout: return 72
        case .shower: return 120
        case .whip: return 80
        case .blaster: return 96
        case .coding: return Int.random(in: 120...200)
        case .crying: return 96
        case .depressed: return Int.random(in: 120...180)
        case .playDead: return 84
        case .roll, .spin, .stretch, .wave, .goodbye: return 36
        case .hop: return 24
        case .backflip: return 24
        case .perk: return 12
        case .lookAround: return 60
        case .exercise: return 72
        case .juggle, .keepyUppy: return 96
        case .eat, .sing: return 84
        case .wakeUp: return 48
        case .sad: return 30
        case .celebrate: return 40
        case .dizzy: return 60
        case .wrap: return 600
        case .thinking, .typing, .searching, .building, .browsing, .alert, .squish: return 96
        }
    }
}

/// Builds the pose and props for tick `t` of an action, facing right when `f` is 1 and left when -1.
func render(_ act: Act, _ t: Int, _ f: CGFloat) -> Frame {
    var fr = Frame()
    var p = Pose()
    let tt = CGFloat(t)
    func width(_ art: [String], _ s: CGFloat) -> CGFloat { CGFloat(art[0].count) * s }
    func add(_ art: [String], _ x: CGFloat, _ y: CGFloat, _ s: CGFloat = 0.5) {
        fr.props.append(Prop(art: art, x: x, y: y, s: s))
    }
    // Places a prop on the side the pet is facing (x is given for facing right).
    func addF(_ art: [String], _ x: CGFloat, _ y: CGFloat, _ s: CGFloat = 0.5) {
        add(art, f > 0 ? x : 12 - x - width(art, s), y, s)
    }

    switch act {
    case .walk:
        p.walk(t); p.eyes = .look(f, 0); fr.vx = 0.3 * f

    case .run:
        p.walk(t, every: 2); p.eyes = .look(f, 0); fr.vx = 0.8 * f
        let swing = (t / 4) % 2 == 0
        p.front(f, swing ? .raised : .down); p.back(f, swing ? .down : .raised)
        if t % 24 < 12 { addF(Art.sweat, -1, 0.5) }

    case .sleep:
        p.sit(); p.eyes = .closed
        for k in 0..<3 {
            let k = CGFloat((t + k * 16) % 48) / 48
            add(Art.z, 9 + k * 3, 3 - k * 6, 0.25 + 0.25 * k)
        }

    case .roll:
        let q = (t / 3) % 4
        p.legs = [0, 0, 0, 0]; p.left = .hidden; p.right = .hidden; p.eyes = .happy
        p.rot = f * CGFloat(q) * .pi / 2
        p.dy = q % 2 == 0 ? 2 : 0.5
        fr.vx = 0.6 * f

    case .hop:
        let ph = t % 8
        p.dy = -4 * sin(.pi * CGFloat(ph) / 8)
        if ph == 0 { p.sy = 0.85 }
        if ph > 1 && ph < 7 { p.eyes = .happy; p.left = .up; p.right = .up }

    case .dance:
        let beat = (t / 6) % 4
        p.dx = [0, 1, 0, -1][beat]
        p.left = beat % 2 == 0 ? .up : .out; p.right = beat % 2 == 0 ? .out : .up
        p.walk(t, every: 6); p.eyes = .happy; p.mouth = .smile
        for k in 0..<2 {
            let ph = CGFloat((t + k * 18) % 36)
            add(Art.note, k == 0 ? 11 + ph / 12 : -2 - ph / 12, 2 - ph / 6)
        }

    case .wave, .goodbye:
        p.front(f, (t / 4) % 2 == 0 ? .up : .raised); p.eyes = .happy; p.mouth = .smile

    case .keepyUppy:
        let ph = t % 16
        add(Art.ball, 5, -6 * sin(.pi * CGFloat(ph) / 16))
        if ph < 2 || ph > 14 { p.sy = 0.9 }
        p.eyes = .look(0, -1)

    case .sit:
        p.sit()
        let looks: [Eyes] = [.open, .look(-1, 0), .open, .look(1, 0)]
        p.eyes = looks[(t / 20) % 4]

    case .lookAround:
        let looks: [Eyes] = [.look(-1, 0), .look(1, 0), .look(0, -1), .look(0, 1), .open]
        p.eyes = looks[min(t / 12, 4)]
        if t > 48 { add(Art.question, 10, -2) }

    case .stretch:
        let k = sin(.pi * tt / 36)
        p.sy = 1 + 0.15 * k; p.left = .up; p.right = .up; p.eyes = .closed
        p.mouth = k > 0.5 ? .o : .none

    case .spin:
        let c = cos(tt * .pi / 6)
        p.sx = abs(c) < 0.15 ? (c < 0 ? -0.15 : 0.15) : c
        p.dy = -sin(.pi * tt / 36); p.eyes = .happy

    case .exercise:
        let down = (t / 8) % 2 == 1
        p.left = .up; p.right = .up; p.eyes = .closed
        if down { p.dy = 1; p.legs = [1, 1, 1, 1] }
        add(Art.dumbbell, 0.5, p.dy - 1.5)
        if t > 36 { add(Art.sweat, 11, 0.5) }

    case .juggle:
        p.eyes = .look(0, -1)
        let swap = (t / 6) % 2 == 0
        p.left = swap ? .raised : .out; p.right = swap ? .out : .raised
        for (k, c) in ["r", "b", "g"].enumerated() {
            let a = tt * 0.3 + CGFloat(k) * 2 * .pi / 3
            add(Art.juggleBall(Character(c)), 5.25 + 4.5 * cos(a), -3 + 2.5 * sin(a))
        }

    case .eat:
        p.front(f, .raised); p.eyes = .happy
        let bites = min(4, t / 16)
        if bites < 4 {
            let cookie = Art.cookie.map { row -> String in
                let chars = Array(row)
                return String(chars.enumerated().map { i, ch in
                    (f > 0 ? i < bites : i >= chars.count - bites) ? "." : ch
                })
            }
            addF(cookie, 11.5, 2.5)
            let chew = t % 16
            if chew > 4 { p.mouth = (t / 4) % 2 == 0 ? .o : .none }
            if chew > 4 && chew < 12 { addF(Art.crumb, 10.5, 5 + CGFloat(chew - 4) * 0.4) }
        } else {
            p.mouth = .smile
            add(Art.heart, 4.25, -3.5 - CGFloat(t - 64) * 0.05)
        }

    case .read:
        p.left = .raised; p.right = .raised; p.eyes = .look(0, 1)
        add(Art.book[t % 40 > 34 ? 1 : 0], 3.25, 4.75)

    case .sing:
        p.mouth = (t / 6) % 2 == 0 ? .o : .none; p.eyes = .closed
        p.dx = sin(tt * 0.2)
        for k in 0..<2 {
            let ph = CGFloat((t + k * 14) % 28)
            addF(Art.note, 9 + ph / 8, 3 - ph / 4)
        }

    case .backflip:
        let k = tt / 24
        p.dy = -6 * sin(.pi * k); p.rot = -f * 2 * .pi * k
        p.left = .up; p.right = .up; p.eyes = .happy
        if t >= 22 { p.sy = 0.85; p.rot = 0 }

    case .chaseButterfly:
        fr.vx = 0.45 * f; p.walk(t, every: 2); p.eyes = .look(f, -1)
        let bx = 14 + 1.5 * sin(tt * 0.2)
        add(Art.butterfly[(t / 3) % 2], f > 0 ? bx : 12 - bx - 2.5, -1 + 2.5 * sin(tt * 0.13))
        let ph = t % 32
        if ph >= 24 { p.dy = -3 * sin(.pi * CGFloat(ph - 24) / 8); p.front(f, .up) }

    case .meditate:
        p.sit(); p.dy -= 1.5 + 0.5 * sin(tt * 0.1); p.eyes = .closed; p.left = .down; p.right = .down
        if (t / 8) % 2 == 0 { add(Art.star, -1.5, 3); add(Art.star, 12, 1) }
        else { add(Art.star, -1, 0.5); add(Art.star, 11.5, 4) }

    case .fight:
        let hit = (t / 5) % 2 == 1
        p.eyes = .look(f, 0)
        p.dy = (t / 3) % 2 == 0 ? 0 : -0.5
        p.back(f, .raised); addF(Art.glove, -0.5, 2.5 + p.dy)
        if hit {
            p.front(f, .punch); addF(Art.glove, 12.5, 3.25 + p.dy); addF(Art.star, 15.5, 2)
        } else {
            p.front(f, .raised); addF(Art.glove, 11, 2.5 + p.dy)
        }
        addF(Art.punchingBag, hit ? 14.25 : 13.5, -1)

    case .workout:
        if (t / 6) % 2 == 0 {
            p.left = .up; p.right = .up; p.legs = [2, 0, 0, 2]; p.dy = -1; p.eyes = .closed
        } else {
            p.left = .down; p.right = .down; p.legs = [0, 2, 2, 0]
        }
        add(Art.headband, 2, 2.25 + p.dy)
        if t > 30 { add(Art.sweat, 11, 0.5 + p.dy) }

    case .shower:
        let scrub = (t / 4) % 2 == 0
        p.eyes = .happy; p.mouth = .smile
        p.left = scrub ? .up : .raised; p.right = scrub ? .raised : .up
        add(Art.showerHead, 2.5, -6)
        for k in 0..<7 {
            add(Art.pixel("c"), 3 + CGFloat(k) * 0.9, -3 + CGFloat((t * 2 + k * 5) % 10) * 0.5)
        }
        for (k, x) in [0.5, 10.5, 5.5].enumerated() {
            add(Art.bubble, CGFloat(x), 1.5 - CGFloat((t + k * 10) % 30) * 0.15)
        }
        if (t / 24) % 2 == 1 { addF(Art.note, 11, -1) }

    case .whip:
        p.front(f, .up); p.eyes = .look(f, 0)
        add(Art.fedora, 4, 0.5)
        let cyc = t % 20
        let w = cyc < 8 ? 0 : min(1, CGFloat(cyc - 8) / 4)
        for i in 0..<16 {
            let u = CGFloat(i) / 15
            let x = (1 - w) * (10.5 - 12 * u) + w * (10.5 + 7.5 * u)
            let y = (1 - w) * (-3 * sin(u * .pi) - u) + w * (6 * u * u)
            add(Art.pixel("n"), f > 0 ? x : 12 - x - 0.5, y)
        }
        if cyc >= 12 && cyc < 15 { addF(Art.star, 17, 5) }

    case .blaster:
        p.front(f, .out); p.eyes = .look(f, 0)
        addF(Art.blaster, 11.5, 4)
        let cyc = t % 16
        if cyc < 2 { addF(Art.star, 15, 3.5); p.dx = -0.25 * f }
        if cyc < 6 { addF(Art.laser, 15 + CGFloat(cyc) * 0.6, 4) }
        let puff = t % 48
        if puff >= 36 { addF(Art.smoke, 15, 3 - CGFloat(puff - 36) * 0.2) }

    case .coding:
        let swap = (t / 2) % 2 == 0
        p.left = swap ? .raised : .out; p.right = swap ? .out : .raised; p.eyes = .look(0, 1)
        add(Art.glasses, 2.5, 2.5)
        add(Art.laptop[(t / 4) % 2], 3.5, 6)
        add(Art.mug, 10.5, 7)
        add(Art.pixel("l"), 11.25, 6 - CGFloat(t % 12) * 0.2)
        for (k, x) in [-3.0, 13.5, -1.5].enumerated() {
            add(Art.codeGlyphs[k], CGFloat(x), 4 - CGFloat((t + k * 16) % 48) * 0.15)
        }

    case .crying:
        p.sit(); p.eyes = .sad; p.mouth = .o
        let wipe = (t / 12) % 2 == 0
        p.left = wipe ? .raised : .down; p.right = wipe ? .raised : .down
        if (t / 3) % 2 == 1 { p.dy += 0.25 }                       // sobbing
        for (side, x) in [(-1.0, 3.0), (1.0, 8.5)] {
            for k in 0..<3 {
                let ph = CGFloat((t + k * 4) % 12)
                add(Art.pixel("c"), CGFloat(x) + CGFloat(side) * ph * 0.08, 5.5 + ph * 0.3)
            }
        }
        let puddle = min(16, 4 + t / 8)
        add([String(repeating: "c", count: puddle)], 6 - CGFloat(puddle) * 0.25, 8.5)

    case .depressed:
        p.sit(); p.sy = 0.9; p.eyes = .sad; p.left = .down; p.right = .down
        p.color = orange.blended(withFraction: 0.45, of: .gray) ?? orange
        add(Art.cloud, 3.75, -0.5 + 0.25 * sin(tt * 0.1))
        for k in 0..<4 {
            add(Art.pixel("c"), 4.25 + CGFloat(k) * 1.2, 1 + CGFloat((t + k * 3) % 8) * 0.4)
        }

    case .playDead:
        if t < 6 {
            p.rot = f * CGFloat(t) / 6 * .pi / 4; p.eyes = .big
        } else if t < 60 {
            p.rot = .pi; p.dy = 2; p.eyes = .dizzy; p.mouth = .o
            if t % 20 < 4 { p.legs = (t / 2) % 2 == 0 ? [1, 2, 1, 2] : [2, 1, 2, 1] }   // twitch
        } else {
            var hop = render(.hop, t - 60, f)
            hop.pose.eyes = .happy; hop.pose.mouth = .smile
            hop.props.append(Prop(art: Art.star, x: -1, y: 1))
            hop.props.append(Prop(art: Art.star, x: 11.5, y: 0))
            return hop
        }

    case .wakeUp:
        return t < 36 ? render(.stretch, t, f) : render(.hop, t - 36, f)

    case .perk:
        p.dy = -2 * sin(.pi * tt / 12); p.eyes = .big
        add(Art.bang, 5.5, -3.5 + p.dy)

    case .thinking:
        fr.vx = 0.25 * f; p.walk(t, every: 4); p.eyes = .look(f, -1); p.front(f, .raised)
        for i in 0..<((t / 8) % 4) { add(Art.dot, 3.5 + CGFloat(i) * 1.75, -1.5) }

    case .typing:
        let swap = (t / 2) % 2 == 0
        p.left = swap ? .raised : .out; p.right = swap ? .out : .raised; p.eyes = .look(0, 1)
        add(Art.laptop[(t / 4) % 2], 3.5, 6)

    case .searching:
        fr.vx = 0.2 * f; p.walk(t, every: 4); p.front(f, .raised)
        p.eyes = (t / 10) % 2 == 0 ? .look(f, 0) : .look(f, 1)
        addF(Art.magnifier, 10.5, 1.5)

    case .building:
        p.eyes = .look(f, 1)
        addF(Art.brick, 14.5, 8)
        if (t / 5) % 2 == 0 {
            p.front(f, .up); addF(Art.hammerUp, 9.5, -2.5)
        } else {
            p.sy = 0.95; addF(Art.hammerDown, 12, 3.5); addF(Art.star, 14.5, 6.5)
        }

    case .browsing:
        p.eyes = .look(0, -1); p.left = .raised; p.right = .raised
        add(Art.globe[(t / 6) % 2], 4.25, -3.5)

    case .sad:
        p.eyes = .sad; p.dx = (t / 2) % 2 == 0 ? 0.25 : -0.25; p.left = .down; p.right = .down
        add(Art.sweat, 10.5, 0.5)

    case .alert:
        let ph = t % 10
        p.dy = -2 * sin(.pi * CGFloat(ph) / 10); p.eyes = .big
        p.left = ph < 5 ? .up : .raised; p.right = ph < 5 ? .raised : .up
        if (t / 6) % 2 == 0 { add(Art.bang, 5.5, -4 + p.dy) }

    case .celebrate:
        let ph = t % 10
        p.dy = -3 * sin(.pi * CGFloat(ph) / 10)
        p.left = .up; p.right = .up; p.eyes = .happy; p.mouth = .smile
        add(Art.check, 4.25, -4 + p.dy)
        let confetti: [Character] = ["r", "b", "g", "y", "p", "c"]
        for (k, c) in confetti.enumerated() {
            add(Art.pixel(c), -3 + CGFloat(k) * 3.2, -6 + CGFloat((t + k * 7) % 20) * 0.6)
        }

    case .dizzy:
        p.rot = f * .pi / 2; p.dy = -1.5; p.eyes = .dizzy
        for k in 0..<3 {
            let a = tt * 0.3 + CGFloat(k) * 2 * .pi / 3
            add(Art.star, 5.25 + 4 * cos(a), -1 + 1.2 * sin(a))
        }

    case .squish:
        p.sy = 0.55; p.sx = 1.15; p.eyes = .closed
        if (t / 12) % 2 == 0 { add(Art.sweat, 11, 4) }

    case .wrap:
        p.walk(t, every: 2); fr.vx = 1.2 * f; fr.offscreen = true; p.eyes = .look(f, 0)

    case .idle:
        break
    }
    fr.pose = p
    return fr
}

// MARK: - Drawing

func armRect(_ a: Arm) -> CGRect? {
    switch a {
    case .out: return CGRect(x: 0, y: 4, width: 2, height: 2)
    case .up: return CGRect(x: 1, y: 0, width: 1, height: 4)
    case .down: return CGRect(x: 1, y: 4, width: 1, height: 3)
    case .raised: return CGRect(x: 0, y: 3, width: 2, height: 2)
    case .punch: return CGRect(x: -1, y: 4, width: 3, height: 1.5)
    case .hidden: return nil
    }
}

func drawEye(_ ctx: CGContext, _ e: Eyes, _ x: CGFloat, _ y: CGFloat) {
    var rects: [CGRect] = []
    switch e {
    case .open: rects = [CGRect(x: x, y: y, width: 1, height: 1)]
    case let .look(dx, dy):
        rects = [CGRect(x: x + max(0, dx) * 0.5, y: y + max(0, dy) * 0.5,
                        width: dx == 0 ? 1 : 0.5, height: dy == 0 ? 1 : 0.5)]
    case .closed: rects = [CGRect(x: x - 0.25, y: y + 0.5, width: 1.5, height: 0.25)]
    case .happy:
        rects = [CGRect(x: x - 0.25, y: y + 0.5, width: 0.5, height: 0.25),
                 CGRect(x: x + 0.25, y: y + 0.25, width: 0.5, height: 0.25),
                 CGRect(x: x + 0.75, y: y + 0.5, width: 0.5, height: 0.25)]
    case .dizzy:
        let s: CGFloat = 0.34
        rects = [(0, 0), (0.66, 0), (0.33, 0.33), (0, 0.66), (0.66, 0.66)].map {
            CGRect(x: x + $0.0, y: y + $0.1, width: s, height: s)
        }
    case .sad: rects = [CGRect(x: x, y: y + 0.5, width: 1, height: 0.5)]
    case .big: rects = [CGRect(x: x - 0.25, y: y - 0.25, width: 1.5, height: 1.5)]
    }
    rects.forEach { ctx.fill($0) }
}

/// Draws the pet in body-grid space: a 12x9 grid with the feet on row 9.
func drawBody(_ ctx: CGContext, _ p: Pose, at origin: CGPoint, scale s: CGFloat = 1) {
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: p.dx, y: p.dy)
    ctx.translateBy(x: 6, y: 9); ctx.scaleBy(x: p.sx, y: p.sy); ctx.translateBy(x: -6, y: -9)
    ctx.translateBy(x: 6, y: 4.5); ctx.rotate(by: p.rot); ctx.translateBy(x: -6, y: -4.5)

    var shape = [CGRect(x: 2, y: 2, width: 8, height: 5)]
    if let r = armRect(p.left) { shape.append(r) }
    if let r = armRect(p.right) { shape.append(CGRect(x: 12 - r.maxX, y: r.minY, width: r.width, height: r.height)) }
    for (i, col) in [2, 4, 7, 9].enumerated() where p.legs[i] > 0 {
        shape.append(CGRect(x: CGFloat(col), y: 7, width: 1, height: p.legs[i]))
    }
    // A faint outline keeps the pet visible on wallpapers close to its own colour.
    ctx.setFillColor(outlineColor.cgColor)
    for (ox, oy) in [(-0.4, 0.0), (0.4, 0.0), (0.0, -0.4), (0.0, 0.4)] {
        shape.forEach { ctx.fill($0.offsetBy(dx: ox, dy: oy)) }
    }
    ctx.setFillColor(p.color.cgColor)
    shape.forEach { ctx.fill($0) }

    ctx.setFillColor(eyeColor.cgColor)
    drawEye(ctx, p.eyes, 3, 3)
    drawEye(ctx, p.eyes, 8, 3)
    switch p.mouth {
    case .none: break
    case .o: ctx.fill(CGRect(x: 5.5, y: 4.5, width: 1, height: 0.75))
    case .smile:
        ctx.fill(CGRect(x: 5.25, y: 4.75, width: 1.5, height: 0.25))
        ctx.fill(CGRect(x: 5, y: 4.5, width: 0.25, height: 0.25))
        ctx.fill(CGRect(x: 6.75, y: 4.5, width: 0.25, height: 0.25))
    }
    ctx.restoreGState()
}

func drawProp(_ ctx: CGContext, _ prop: Prop) {
    for (r, row) in prop.art.enumerated() {
        for (c, ch) in row.enumerated() {
            guard let color = paletteColor(ch) else { continue }
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: prop.x + CGFloat(c) * prop.s, y: prop.y + CGFloat(r) * prop.s,
                            width: prop.s, height: prop.s))
        }
    }
}

final class PetView: NSView {
    var frameToDraw = Frame()
    var clones: [(Pose, CGPoint)] = []

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.setShouldAntialias(false)
        ctx.scaleBy(x: U, y: U)
        ctx.translateBy(x: bodyX, y: bodyY)
        for (pose, origin) in clones { drawBody(ctx, pose, at: origin, scale: 0.5) }
        drawBody(ctx, frameToDraw.pose, at: .zero)
        frameToDraw.props.forEach { drawProp(ctx, $0) }
    }

    // Click to hop, double-click for a backflip, drag to move.
    var onClick: ((Int) -> Void)?
    var onDrag: ((Bool) -> Void)?
    private var grab = NSPoint.zero
    private var start = NSPoint.zero
    private var moved = false

    override func mouseDown(with event: NSEvent) {
        start = NSEvent.mouseLocation
        grab = NSPoint(x: start.x - window!.frame.origin.x, y: start.y - window!.frame.origin.y)
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        if !moved && hypot(p.x - start.x, p.y - start.y) > 3 { moved = true; onDrag?(true) }
        if moved { window?.setFrameOrigin(NSPoint(x: p.x - grab.x, y: p.y - grab.y)) }
    }

    override func mouseUp(with event: NSEvent) {
        if moved { onDrag?(false) } else { onClick?(event.clickCount) }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Walking area picker

final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Full-screen overlay where the user drags out the area the pet may walk in.
final class AreaPickerView: NSView {
    var start: NSPoint?
    var current: NSPoint?
    var onDone: ((NSRect?) -> Void)?

    var selection: NSRect? {
        guard let a = start, let b = current else { return nil }
        return NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.35).setFill()
        bounds.fill()
        let help = "Drag to draw where the pet can walk. It walks along the bottom edge. Press Esc to cancel."
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.white]
        let size = help.size(withAttributes: attrs)
        help.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
        guard let sel = selection, let win = window else { return }
        let r = sel.offsetBy(dx: -win.frame.minX, dy: -win.frame.minY)
        orange.withAlphaComponent(0.25).setFill()
        r.fill()
        let border = NSBezierPath(rect: r)
        border.lineWidth = 3
        border.setLineDash([8, 5], count: 2, phase: 0)
        orange.setStroke()
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) { start = NSEvent.mouseLocation; current = start; needsDisplay = true }
    override func mouseDragged(with event: NSEvent) { current = NSEvent.mouseLocation; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        current = NSEvent.mouseLocation
        if let sel = selection, sel.width > 20 { onDone?(sel) } else { start = nil; current = nil; needsDisplay = true }
    }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onDone?(nil) } }
}

// MARK: - Pet

final class Pet: NSObject {
    let window: NSWindow
    let view = PetView(frame: NSRect(origin: .zero, size: canvasSize))

    var act = Act.idle
    var t = 0
    var dur = 24
    var transient = false        // started by an event or the menu, so it plays to the end
    var queue: [Act] = []
    var facing: CGFloat = 1
    var posX: CGFloat = 0
    var wrapped = false
    var tick = 0

    var reactToClaude = true
    var stayStill = false
    var dragging = false

    // Claude state
    var loop: Act?               // what Claude is busy with right now
    var loopBeforeSquish: Act?
    var lastEvent = Date()
    var subagents = 0
    var checkTicks = 0
    var heartTicks = 0

    var blinkTicks = 0
    var nextBlink = 40

    var readOffset: UInt64 = 0
    var partial = Data()

    // Settings, saved between launches
    var disabled = Set((UserDefaults.standard.stringArray(forKey: "disabledActions") ?? []).compactMap(Act.init(rawValue:)))
    var settingsWindow: NSWindow?
    var areaLabel: NSTextField?
    var pickerWindows: [NSWindow] = []
    var walkArea: NSRect? = {
        guard let saved = UserDefaults.standard.string(forKey: "walkArea") else { return nil }
        let r = NSRectFromString(saved)
        return r.width > 0 ? r : nil
    }()
    var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "Auto"   // Auto, Light or Dark
    var statusItem: NSStatusItem?
    var menus: [NSMenu] = []
    var checkboxes: [NSButton] = []

    override init() {
        if let area = UserDefaults.standard.string(forKey: "walkArea"),
           UserDefaults.standard.string(forKey: "lastWalkArea") == nil {
            UserDefaults.standard.set(area, forKey: "lastWalkArea")
        }
        let savedSize = UserDefaults.standard.double(forKey: "size")
        if savedSize > 0 { U = CGFloat(savedSize) }
        window = NSWindow(contentRect: NSRect(origin: .zero, size: canvasSize),
                          styleMask: .borderless, backing: .buffered, defer: false)
        super.init()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = view

        let screen = walkArea ?? NSScreen.main!.visibleFrame
        posX = screen.midX - canvasSize.width / 2
        window.setFrameOrigin(NSPoint(x: posX, y: screen.minY))
        window.orderFrontRegardless()

        view.onClick = { [weak self] count in
            guard let self = self else { return }
            if count >= 2 { self.interrupt([.backflip]) } else { self.heartTicks = 24; self.interrupt([.hop]) }
        }
        view.onDrag = { [weak self] down in
            guard let self = self else { return }
            self.dragging = down
            if !down { self.posX = self.window.frame.origin.x; self.keepInArea() }
        }
        view.menu = makeMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuBarIcon()
        item.button?.toolTip = "Claudinion"
        item.menu = makeMenu()
        statusItem = item

        if let size = (try? FileManager.default.attributesOfItem(atPath: eventsURL.path))?[.size] as? NSNumber {
            readOffset = size.uint64Value
        }
        refreshMenus()
        play(.wakeUp)
        Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in self?.step() }
    }

    // MARK: Menu

    /// A small one-colour version of the pet; macOS tints it to match the menu bar.
    func menuBarIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let s: CGFloat = 1.5
            let rows = ["..########..", "..#.####.#..", "############", "############",
                        "..########..", "..#.#..#.#..", "..#.#..#.#.."]
            let top = (18 - CGFloat(rows.count) * s) / 2
            NSColor.black.setFill()
            for (r, row) in rows.enumerated() {
                for (c, ch) in row.enumerated() where ch == "#" {
                    NSRect(x: CGFloat(c) * s, y: top + CGFloat(r) * s, width: s, height: s).fill()
                }
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menus.append(menu)
        func item(_ title: String, _ action: Selector, _ key: String = "", in m: NSMenu) {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
            it.target = self
            m.addItem(it)
        }

        item("Hide Pet", #selector(toggleVisible), in: menu)
        menu.addItem(.separator())

        // Every action in one place: free play by category, then Claude's reactions.
        let play = NSMenu()
        func section(_ title: String, _ acts: [Act]) {
            if !play.items.isEmpty { play.addItem(.separator()) }
            play.addItem(.sectionHeader(title: title))
            for a in acts {
                let it = NSMenuItem(title: a.title, action: #selector(menuPlay(_:)), keyEquivalent: "")
                it.target = self
                it.representedObject = a.rawValue
                play.addItem(it)
            }
        }
        for c in Act.categories { section(c.name, c.acts) }
        section("Claude Reactions (automatic)", Act.claude)
        let playItem = NSMenuItem(title: "Play", action: nil, keyEquivalent: "")
        playItem.submenu = play
        menu.addItem(playItem)
        item("Stay in Place", #selector(toggleStill(_:)), in: menu)

        let area = NSMenu()
        item("Anywhere", #selector(clearArea), in: area)
        item("Custom Area", #selector(useCustomArea), in: area)
        area.addItem(.separator())
        item("Draw New Area…", #selector(pickArea), in: area)
        let areaItem = NSMenuItem(title: "Walking Area", action: nil, keyEquivalent: "")
        areaItem.submenu = area
        menu.addItem(areaItem)
        menu.addItem(.separator())

        item("React to Claude", #selector(toggleReact(_:)), in: menu)
        item("Connect to Claude…", #selector(toggleClaudeHooks), in: menu)
        menu.addItem(.separator())

        item("Settings…", #selector(openSettings), ",", in: menu)
        item("About Claudinion", #selector(openAbout), in: menu)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc func openAbout() {
        NSWorkspace.shared.open(URL(string: "https://github.com/tarek-89/Claudinion")!)
    }

    @objc func menuPlay(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let a = Act(rawValue: raw) { interrupt([a]) }
    }

    @objc func toggleReact(_ sender: NSMenuItem) {
        reactToClaude.toggle()
        if !reactToClaude { loop = nil; subagents = 0 }
        refreshMenus()
    }

    @objc func toggleStill(_ sender: NSMenuItem) {
        stayStill.toggle()
        refreshMenus()
    }

    @objc func toggleVisible() {
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
        refreshMenus()
    }

    /// Keeps the pet's right-click menu and the menu bar menu showing the same state.
    func refreshMenus() {
        let connected = isConnected()
        func allItems(_ m: NSMenu) -> [NSMenuItem] { m.items.flatMap { [$0] + ($0.submenu.map(allItems) ?? []) } }
        for menu in menus {
            for item in allItems(menu) {
                switch item.action {
                case #selector(toggleReact(_:)): item.state = reactToClaude ? .on : .off
                case #selector(toggleStill(_:)): item.state = stayStill ? .on : .off
                case #selector(clearArea): item.state = walkArea == nil ? .on : .off
                case #selector(useCustomArea):
                    item.state = walkArea == nil ? .off : .on
                case #selector(toggleVisible): item.title = window.isVisible ? "Hide Pet" : "Show Pet"
                case #selector(toggleClaudeHooks): item.title = connected ? "Disconnect from Claude…" : "Connect to Claude…"
                default: break
                }
            }
        }
    }

    // MARK: Claude hooks

    static let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                             "PermissionRequest", "Notification", "SubagentStart", "SubagentStop", "Stop",
                             "StopFailure", "PreCompact", "PostCompact", "TaskCompleted", "CwdChanged", "SessionEnd"]
    let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")

    func isPetHook(_ hook: Any) -> Bool {
        guard let command = (hook as? [String: Any])?["command"] as? String else { return false }
        return command.contains("Claudinion") && command.contains("--hook")
    }

    func isConnected() -> Bool {
        guard let data = try? Data(contentsOf: claudeSettingsURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { groups in
            (groups as? [[String: Any]] ?? []).contains { ($0["hooks"] as? [Any] ?? []).contains(where: isPetHook) }
        }
    }

    @objc func toggleClaudeHooks() {
        let connected = isConnected()
        let alert = NSAlert()
        alert.messageText = connected ? "Disconnect from Claude?" : "Connect to Claude?"
        alert.informativeText = connected
            ? "This removes the Claudinion hooks from ~/.claude/settings.json."
            : "This adds hooks to ~/.claude/settings.json so the pet reacts to Claude Code in the terminal and in the Claude app's Code tab. Your current file is backed up as settings.json.before-claudinion.\n\nStart a new Claude session afterwards."
        alert.addButton(withTitle: connected ? "Disconnect" : "Connect")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            var root: [String: Any] = [:]
            if FileManager.default.fileExists(atPath: claudeSettingsURL.path) {
                let data = try Data(contentsOf: claudeSettingsURL)
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "Claudinion", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "settings.json isn't a JSON object, so it was left alone."])
                }
                root = parsed
                let backup = claudeSettingsURL.appendingPathExtension("before-claudinion")
                try? FileManager.default.removeItem(at: backup)
                try FileManager.default.copyItem(at: claudeSettingsURL, to: backup)
            }
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            let command = "\"\(Bundle.main.executablePath!)\" --hook"
            for event in Pet.hookEvents {
                var groups = (hooks[event] as? [[String: Any]] ?? []).compactMap { group -> [String: Any]? in
                    var group = group
                    let kept = (group["hooks"] as? [Any] ?? []).filter { !isPetHook($0) }
                    if kept.isEmpty { return nil }
                    group["hooks"] = kept
                    return group
                }
                if !connected { groups.append(["hooks": [["type": "command", "command": command, "async": true]]]) }
                hooks[event] = groups.isEmpty ? nil : groups
            }
            root["hooks"] = hooks.isEmpty ? nil : hooks
            let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try FileManager.default.createDirectory(at: claudeSettingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try out.write(to: claudeSettingsURL, options: .atomic)
            if !connected { interrupt([.celebrate]) }
        } catch {
            let failed = NSAlert(error: error)
            failed.runModal()
        }
        refreshMenus()
    }

    // MARK: Settings window

    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = makeSettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func makeSettingsWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Claudinion Settings"
        w.isReleasedWhenClosed = false
        w.level = .floating

        func heading(_ text: String) -> NSTextField {
            let label = NSTextField(labelWithString: text)
            label.font = .boldSystemFont(ofSize: 13)
            return label
        }

        let slider = NSSlider(value: Double(U), minValue: 3, maxValue: 16, target: self, action: #selector(sizeChanged(_:)))
        slider.numberOfTickMarks = 14
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let sizeRow = NSStackView(views: [NSTextField(labelWithString: "Small"), slider, NSTextField(labelWithString: "Big")])

        checkboxes = Act.freePlay.enumerated().map { i, a in
            let box = NSButton(checkboxWithTitle: a.title, target: self, action: #selector(actionToggled(_:)))
            box.tag = i
            box.state = disabled.contains(a) ? .off : .on
            return box
        }
        let groups: [NSView] = Act.categories.map { c in
            let title = NSTextField(labelWithString: c.name.uppercased())
            title.font = .systemFont(ofSize: 10, weight: .semibold)
            title.textColor = .secondaryLabelColor
            let col = NSStackView(views: [title] + c.acts.map { checkboxes[Act.freePlay.firstIndex(of: $0)!] })
            col.orientation = .vertical
            col.alignment = .leading
            col.spacing = 5
            return col
        }
        let grid = NSGridView(views: stride(from: 0, to: groups.count, by: 3).map { Array(groups[$0..<min($0 + 3, groups.count)]) })
        grid.rowSpacing = 16
        grid.columnSpacing = 28
        grid.rowAlignment = .none
        for r in 0..<grid.numberOfRows { grid.row(at: r).yPlacement = .top }

        let buttons = NSStackView(views: [
            NSButton(title: "Select All", target: self, action: #selector(selectAll)),
            NSButton(title: "Select None", target: self, action: #selector(selectNone)),
        ])

        let hint = NSTextField(wrappingLabelWithString:
            "Unticked actions won't play on their own, but you can still start them from the right-click menu. Claude reactions always play.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 380

        let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        themePopup.addItems(withTitles: ["Auto", "Light", "Dark"])
        themePopup.selectItem(withTitle: appearance)
        themePopup.target = self
        themePopup.action = #selector(appearanceChanged(_:))
        let themeHint = NSTextField(labelWithString: "Auto follows your Mac's light or dark mode.")
        themeHint.font = .systemFont(ofSize: 11)
        themeHint.textColor = .secondaryLabelColor
        let themeRow = NSStackView(views: [themePopup, themeHint])

        let areaLabel = NSTextField(labelWithString: "")
        areaLabel.font = .systemFont(ofSize: 11)
        areaLabel.textColor = .secondaryLabelColor
        self.areaLabel = areaLabel
        updateAreaLabel()
        let areaRow = NSStackView(views: [
            NSButton(title: "Draw Area…", target: self, action: #selector(pickArea)),
            NSButton(title: "Walk Anywhere", target: self, action: #selector(clearArea)),
            areaLabel,
        ])

        let stack = NSStackView(views: [heading("Size"), sizeRow, heading("Appearance"), themeRow,
                                        heading("Where it walks"), areaRow, heading("Actions it does on its own"), grid, buttons, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(24, after: sizeRow)
        stack.setCustomSpacing(24, after: themeRow)
        stack.setCustomSpacing(24, after: areaRow)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        w.contentView = stack
        w.setContentSize(stack.fittingSize)
        w.center()
        return w
    }

    // MARK: Walking area

    @objc func pickArea() {
        settingsWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        pickerWindows = NSScreen.screens.map { screen in
            let w = KeyWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .screenSaver
            let picker = AreaPickerView(frame: NSRect(origin: .zero, size: screen.frame.size))
            picker.onDone = { [weak self] rect in self?.finishPicking(rect) }
            w.contentView = picker
            w.makeKeyAndOrderFront(nil)
            w.makeFirstResponder(picker)
            return w
        }
    }

    func finishPicking(_ rect: NSRect?) {
        pickerWindows.forEach { $0.orderOut(nil) }
        pickerWindows = []
        guard let rect = rect else { return }
        walkArea = rect
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: "walkArea")
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: "lastWalkArea")
        areaChanged()
    }

    /// Switches back to the most recently drawn area, or asks for one if there is none.
    @objc func useCustomArea() {
        guard let saved = UserDefaults.standard.string(forKey: "lastWalkArea") else { pickArea(); return }
        finishPicking(NSRectFromString(saved))
    }

    @objc func clearArea() {
        walkArea = nil
        UserDefaults.standard.removeObject(forKey: "walkArea")
        areaChanged()
    }

    func areaChanged() {
        updateAreaLabel()
        refreshMenus()
        keepInArea(force: true)
        interrupt([.hop])
    }

    func updateAreaLabel() {
        if let a = walkArea {
            areaLabel?.stringValue = "Custom area, \(Int(a.width)) × \(Int(a.height)) points"
        } else {
            areaLabel?.stringValue = "Anywhere along the bottom of the screen"
        }
    }

    /// Moves the pet back inside its walking area if it is outside (or always onto the ground with `force`).
    func keepInArea(force: Bool = false) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let area = walkArea ?? screen.visibleFrame
        let feet = NSPoint(x: window.frame.minX + (bodyX + 6) * U, y: window.frame.minY)
        let inside = area.insetBy(dx: -1, dy: -1).contains(feet)
        guard force || (walkArea != nil && !inside) else { return }
        let minX = area.minX - bodyX * U
        let maxX = max(minX, area.maxX - (bodyX + 12) * U)
        posX = min(max(window.frame.minX, minX), maxX)
        window.setFrameOrigin(NSPoint(x: posX, y: area.minY))
    }

    @objc func appearanceChanged(_ sender: NSPopUpButton) {
        appearance = sender.titleOfSelectedItem ?? "Auto"
        UserDefaults.standard.set(appearance, forKey: "appearance")
    }

    @objc func sizeChanged(_ sender: NSSlider) {
        setSize(CGFloat(sender.doubleValue.rounded()))
        UserDefaults.standard.set(Double(U), forKey: "size")
    }

    /// Resizes the pet, keeping its feet where they were.
    func setSize(_ u: CGFloat) {
        guard u != U else { return }
        let old = window.frame
        let feetX = old.minX + (bodyX + 6) * U
        U = u
        posX = feetX - (bodyX + 6) * U
        window.setFrame(NSRect(origin: NSPoint(x: posX, y: old.minY), size: canvasSize), display: true)
        view.frame = NSRect(origin: .zero, size: canvasSize)
        view.needsDisplay = true
    }

    @objc func actionToggled(_ sender: NSButton) {
        let a = Act.freePlay[sender.tag]
        if sender.state == .on { disabled.remove(a) } else { disabled.insert(a) }
        saveActions()
    }

    @objc func selectAll() { disabled = []; saveActions() }
    @objc func selectNone() { disabled = Set(Act.freePlay); saveActions() }

    func saveActions() {
        UserDefaults.standard.set(disabled.map(\.rawValue), forKey: "disabledActions")
        for box in checkboxes { box.state = disabled.contains(Act.freePlay[box.tag]) ? .off : .on }
        // Stop a free-play action that was just switched off.
        if !transient && Act.freePlay.contains(act) && disabled.contains(act) { play(.idle) }
    }

    // MARK: Choosing what to do

    func play(_ a: Act, transient: Bool = false) {
        act = a; t = 0; dur = a.duration(); wrapped = false
        self.transient = transient
        if !transient && [.walk, .run, .roll, .chaseButterfly].contains(a) && Bool.random() { facing = -facing }
    }

    func interrupt(_ acts: [Act]) {
        queue = acts
        next()
    }

    func next() {
        if !queue.isEmpty { play(queue.removeFirst(), transient: true); return }
        if let l = loop { play(l); return }
        let enabled = Act.freePlay.filter { !disabled.contains($0) }
        if act != .idle || enabled.isEmpty { play(.idle); return }
        // Walking, sitting and looking around come up a bit more often.
        let weighted = enabled + [.walk, .walk, .walk, .sit, .lookAround].filter { enabled.contains($0) }
        play(weighted.randomElement()!)
    }

    // MARK: Claude events

    func toolAct(_ tool: String) -> Act {
        switch tool {
        case "Bash", "BashOutput", "KillShell", "Monitor": return .typing
        case "Read", "Grep", "Glob", "LS", "NotebookRead", "ToolSearch": return .searching
        case "Edit", "Write", "MultiEdit", "NotebookEdit": return .building
        case "WebFetch", "WebSearch": return .browsing
        case "AskUserQuestion", "ExitPlanMode": return .alert
        default:
            let name = tool.lowercased()
            if name.contains("browser") || name.contains("chrome") || name.contains("web") { return .browsing }
            if name.contains("search") || name.contains("read") || name.contains("find") || name.contains("query") {
                return .searching
            }
            return .thinking
        }
    }

    func handle(_ e: [String: Any]) {
        guard reactToClaude, let name = e["hook_event_name"] as? String else { return }
        lastEvent = Date()
        switch name {
        case "SessionStart":
            if loop == nil { interrupt([.wakeUp]) }
        case "UserPromptSubmit":
            loop = .thinking; interrupt([.perk])
        case "PreToolUse":
            loop = toolAct(e["tool_name"] as? String ?? "")
        case "PostToolUse":
            if loop != .squish { loop = .thinking }
        case "PostToolUseFailure":
            loop = .thinking; interrupt([.sad])
        case "PermissionRequest":
            loop = .alert
        case "Notification":
            let type = e["notification_type"] as? String ?? ""
            if type == "permission_prompt" || type == "elicitation_dialog" { loop = .alert }
            if type == "idle_prompt" { loop = nil }
        case "SubagentStart":
            subagents += 1
        case "SubagentStop":
            subagents = max(0, subagents - 1)
        case "Stop":
            loop = nil; subagents = 0; interrupt([.celebrate])
        case "StopFailure":
            loop = nil; subagents = 0; interrupt([.dizzy])
        case "PreCompact":
            loopBeforeSquish = loop; loop = .squish
        case "PostCompact":
            loop = loopBeforeSquish; interrupt([.hop])
        case "TaskCompleted":
            checkTicks = 30
        case "CwdChanged":
            interrupt([.wrap])
        case "SessionEnd":
            loop = nil; subagents = 0; interrupt([.goodbye, .sleep])
        default:
            break
        }
    }

    func pollEvents() {
        guard let h = try? FileHandle(forReadingFrom: eventsURL) else { return }
        defer { try? h.close() }
        guard let size = try? h.seekToEnd() else { return }
        if size < readOffset { readOffset = 0; partial = Data() }
        guard size > readOffset else { return }
        try? h.seek(toOffset: readOffset)
        partial.append(h.readData(ofLength: Int(size - readOffset)))
        readOffset = size
        while let nl = partial.firstIndex(of: 0x0A) {
            let line = partial.subdata(in: partial.startIndex..<nl)
            partial = Data(partial[(nl + 1)...])
            if let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] { handle(obj) }
        }
    }

    // MARK: Animation loop

    func step() {
        tick += 1
        switch appearance {
        case "Light": darkTheme = false
        case "Dark": darkTheme = true
        default: darkTheme = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        if tick % 3 == 0 { pollEvents() }
        // Forget a busy state if Claude went quiet (for example a session that was closed).
        if loop != nil && Date().timeIntervalSince(lastEvent) > 600 { loop = nil; subagents = 0 }

        t += 1
        let done: Bool
        if transient { done = t >= dur }
        else if act.isLoop { done = loop != act && t >= 18 }   // keep each tool on screen for a moment
        else { done = loop != nil || t >= dur }               // Claude getting busy interrupts free play
        if done { next() }

        var fr = render(act, t, facing)

        if dragging {
            fr = Frame()
            fr.pose.walk(tick, every: 2); fr.pose.left = .up; fr.pose.right = .up; fr.pose.eyes = .big
        }

        // Blink now and then when the eyes are plainly open.
        nextBlink -= 1
        if nextBlink <= 0 { blinkTicks = 2; nextBlink = Int.random(in: 30...80) }
        if blinkTicks > 0 {
            blinkTicks -= 1
            switch fr.pose.eyes {
            case .open, .look: fr.pose.eyes = .closed
            default: break
            }
        }

        if checkTicks > 0 { checkTicks -= 1; fr.props.append(Prop(art: Art.check, x: 4.25, y: -4.5 + fr.pose.dy)) }
        if heartTicks > 0 {
            heartTicks -= 1
            fr.props.append(Prop(art: Art.heart, x: 4.25, y: -2 - CGFloat(24 - heartTicks) * 0.15))
        }

        // Mini helpers appear while Claude runs subagents.
        view.clones = (0..<min(subagents, 2)).map { i in
            var p = Pose()
            p.walk(tick + i * 3, every: 3)
            p.eyes = .look(i == 0 ? 1 : -1, 0)
            p.dy = (tick / 6 + i) % 2 == 0 ? 0 : -1
            return (p, CGPoint(x: i == 0 ? -6.5 : 12.5, y: 4.5))
        }

        if !dragging { move(fr) }
        view.frameToDraw = fr
        view.needsDisplay = true
    }

    func move(_ fr: Frame) {
        guard fr.vx != 0 && !stayStill, let screen = window.screen ?? NSScreen.main else { return }
        posX += fr.vx * U
        let area = walkArea ?? screen.visibleFrame
        let minX = area.minX - bodyX * U
        let maxX = max(minX, area.maxX - (bodyX + 12) * U)
        if fr.offscreen {
            // Run off one edge, come back in from the other.
            let full = walkArea ?? screen.frame
            if facing > 0 && posX + bodyX * U > full.maxX {
                posX = full.minX - (bodyX + 12) * U; wrapped = true; dur = t + 30
            } else if facing < 0 && posX + (bodyX + 12) * U < full.minX {
                posX = full.maxX - bodyX * U; wrapped = true; dur = t + 30
            }
        } else {
            if posX < minX { posX = minX; facing = 1 }
            if posX > maxX { posX = maxX; facing = -1 }
        }
        window.setFrameOrigin(NSPoint(x: posX, y: window.frame.origin.y))
    }
}

// `Claudinion --sheet out.png` draws a few frames of every action into one image, for checking the art.
if let i = CommandLine.arguments.firstIndex(of: "--sheet"), i + 1 < CommandLine.arguments.count {
    var acts = Act.freePlay + Act.claude
    if i + 3 < CommandLine.arguments.count, let a = Int(CommandLine.arguments[i + 2]), let b = Int(CommandLine.arguments[i + 3]) {
        acts = Array(acts[a..<min(b, acts.count)])
    }
    let ticks = [4, 14, 26, 40]
    let cell = canvasSize
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cell.width) * ticks.count,
                               pixelsHigh: Int(cell.height) * acts.count, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor(white: 0.18, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
    ctx.translateBy(x: 0, y: CGFloat(rep.pixelsHigh)); ctx.scaleBy(x: 1, y: -1)
    ctx.setShouldAntialias(false)
    for (r, a) in acts.enumerated() {
        for (c, tk) in ticks.enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(c) * cell.width, y: CGFloat(r) * cell.height)
            ctx.setStrokeColor(NSColor(white: 0.3, alpha: 1).cgColor)
            ctx.stroke(CGRect(origin: .zero, size: cell))
            ctx.scaleBy(x: U, y: U); ctx.translateBy(x: bodyX, y: bodyY)
            let fr = render(a, tk, 1)
            drawBody(ctx, fr.pose, at: .zero)
            fr.props.forEach { drawProp(ctx, $0) }
            ctx.restoreGState()
        }
    }
    try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

/// Renders into a new bitmap of the given pixel size, with a flipped (top-left origin) context.
func renderImage(width: Int, height: Int, to path: String, _ draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    gc.cgContext.translateBy(x: 0, y: CGFloat(height))
    gc.cgContext.scaleBy(x: 1, y: -1)
    draw(gc.cgContext)
    gc.flushGraphics()
    try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func argument(after flag: String) -> String? {
    guard let i = CommandLine.arguments.firstIndex(of: flag), i + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[i + 1]
}

// `Claudinion --icon out.png` draws the 1024x1024 app icon.
if let path = argument(after: "--icon") {
    darkTheme = false
    renderImage(width: 1024, height: 1024, to: path) { ctx in
        let bg = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.addPath(bg)
        ctx.setFillColor(rgb(0.13, 0.13, 0.15).cgColor)
        ctx.fillPath()
        ctx.setShouldAntialias(false)
        ctx.translateBy(x: 512 - 6 * 52, y: 512 - 5.5 * 52)
        ctx.scaleBy(x: 52, y: 52)
        var pose = Pose()
        pose.eyes = .happy
        pose.color = rgb(0.85, 0.47, 0.34)
        drawBody(ctx, pose, at: .zero)
    }
    exit(0)
}

// `Claudinion --gallery out.png [reactions]` draws one labelled frame of every action, for the README.
if let path = argument(after: "--gallery") {
    let showReactions = CommandLine.arguments.contains("reactions")
    let acts = showReactions ? Act.claude : Act.freePlay
    let bestTick: [Act: Int] = [.hop: 4, .backflip: 8, .roll: 3, .keepyUppy: 8, .eat: 20, .playDead: 30, .perk: 6,
                                .alert: 2, .whip: 13, .blaster: 1, .fight: 5, .wrap: 4, .wakeUp: 18, .stretch: 18,
                                .spin: 2, .chaseButterfly: 27, .exercise: 4, .workout: 2, .building: 0, .celebrate: 3,
                                .crying: 40, .run: 2, .dance: 6, .sing: 6, .wave: 2, .goodbye: 2, .lookAround: 50,
                                .typing: 4, .coding: 20, .shower: 8, .read: 4, .juggle: 6, .meditate: 10, .sleep: 20]
    let cols = 6
    let cellW = 200, cellH = 190, scale: CGFloat = 0.9
    let rows = (acts.count + cols - 1) / cols
    darkTheme = true
    renderImage(width: cellW * cols, height: cellH * rows, to: path) { ctx in
        ctx.setFillColor(rgb(0.11, 0.11, 0.13).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: cellW * cols, height: cellH * rows))
        for (i, a) in acts.enumerated() {
            let ox = CGFloat((i % cols) * cellW), oy = CGFloat((i / cols) * cellH)
            ctx.saveGState()
            ctx.clip(to: CGRect(x: ox, y: oy, width: CGFloat(cellW), height: CGFloat(cellH)))
            ctx.setShouldAntialias(false)
            ctx.translateBy(x: ox + (CGFloat(cellW) - canvasSize.width * scale) / 2, y: oy + 6)
            ctx.scaleBy(x: U * scale, y: U * scale)
            ctx.translateBy(x: bodyX, y: bodyY)
            let fr = render(a, bestTick[a] ?? 14, 1)
            drawBody(ctx, fr.pose, at: .zero)
            fr.props.forEach { drawProp(ctx, $0) }
            ctx.restoreGState()
            // Text is drawn in an unflipped context so it isn't upside down.
            let label = showReactions ? String(a.title.split(separator: "–").first ?? "").trimmingCharacters(in: .whitespaces) : a.title
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium),
                                                        .foregroundColor: NSColor(white: 0.85, alpha: 1)]
            let size = label.size(withAttributes: attrs)
            ctx.saveGState()
            ctx.translateBy(x: 0, y: oy + CGFloat(cellH) - 14)
            ctx.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            label.draw(at: NSPoint(x: ox + (CGFloat(cellW) - size.width) / 2, y: 0), withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()
        }
    }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon
let pet = Pet()
app.run()
