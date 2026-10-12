import AppKit
import ServiceManagement

// MARK: - Hook mode
// Claude Code runs `Claudinion --hook` for each hook event. It reads the event JSON on stdin and
// appends a one-line summary to ~/.claude/claudinion/events.jsonl, which the running pet watches.

let eventsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claudinion")
let eventsURL = eventsDir.appendingPathComponent("events.jsonl")

func commandKind(_ command: String) -> String? {
    let parts = command.lowercased()
        .components(separatedBy: CharacterSet(charactersIn: "&|;\n"))
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("cd ") }
    func any(_ test: (String) -> Bool) -> Bool { parts.contains(where: test) }
    let testRunners = ["pytest", "jest", "vitest", "phpunit", "rspec", "pest", "mocha", "playwright test"]
    if any({ p in testRunners.contains { p.hasPrefix($0) } || p.range(of: #"\b(npm|yarn|pnpm|bun|go|cargo|swift|dotnet|mix|artisan|xcodebuild)\b.*\btest\b"#, options: .regularExpression) != nil }) {
        return "test"
    }
    if any({ $0.hasPrefix("git ") || $0 == "git" || $0.hasPrefix("gh ") }) { return "git" }
    if any({ $0.range(of: #"^(npm (install|i|ci)|yarn( add| install)?$|yarn add|pnpm (add|install|i)|bun (add|install)|pip3? install|brew install|composer (install|require|update)|bundle install|cargo (add|install)|gem install|pod install)\b"#, options: .regularExpression) != nil }) {
        return "install"
    }
    if any({ $0.range(of: #"^(make\b|xcodebuild|swiftc|swift build|cargo build|go build|tsc\b|vite build|webpack|gradle|mvn|\./build)|\b(npm|yarn|pnpm|bun) run (build|compile)"#, options: .regularExpression) != nil }) {
        return "build"
    }
    return nil
}

func runHook() -> Never {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { exit(0) }
    var out: [String: Any] = ["ts": Date().timeIntervalSince1970]
    for key in ["hook_event_name", "tool_name", "notification_type", "session_id", "error"] {
        if let v = obj[key] as? String { out[key] = v }
    }
    // For shell commands only a category is kept (git, test, install or build), never the command itself.
    if let command = (obj["tool_input"] as? [String: Any])?["command"] as? String, let kind = commandKind(command) {
        out["command_kind"] = kind
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
let bodyY: CGFloat = canvasRows - 10

// Light and dark themes. `darkTheme` follows the Appearance setting (or macOS when set to Auto).
var darkTheme = true
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
/// The pet's colour theme: "Classic" orange (follows light/dark mode), "Charcoal" or "Shadow".
let themes = ["Classic", "Charcoal", "Shadow"]
var theme = UserDefaults.standard.string(forKey: "theme") ?? "Classic"
var orange: NSColor {
    switch theme {
    case "Charcoal": return rgb(0.17, 0.17, 0.20)
    case "Shadow": return rgb(0.07, 0.07, 0.08)
    default: return darkTheme ? rgb(0.80, 0.44, 0.32) : rgb(0.85, 0.47, 0.34)
    }
}
var outlineColor: NSColor {
    switch theme {
    case "Charcoal": return rgb(0.85, 0.47, 0.34, 0.9)      // glowing orange edge
    case "Shadow": return rgb(0.75, 0.80, 0.90, 0.55)
    default: return darkTheme ? rgb(1, 1, 1, 0.22) : rgb(0, 0, 0, 0.22)
    }
}
var eyeColor: NSColor {
    switch theme {
    case "Charcoal": return rgb(1.0, 0.62, 0.40)
    case "Shadow": return rgb(0.95, 0.95, 1.0)
    default: return rgb(0.08, 0.08, 0.08)
    }
}

func paletteColor(_ ch: Character) -> NSColor? {
    switch ch {
    case "o": return orange
    case "k": return rgb(0.08, 0.08, 0.08)
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
    static let star = [".y.", "yyy", ".y."]
    static let sweat = [".c.", "ccc", "ccc", ".c."]
    static let crumb = ["n"]
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
    static let mug = ["llll.", "lnnll", "lnnl.", "llll."]
    static let cloud = [".mmm.mm..", "mmmmmmmmm", ".mmmmmmm."]
    // Thinking
    static let thoughtBubble = ["..mmmmmmmmmm..", ".mwwwwwwwwwwm.", "mwwwwwwwwwwwwm", "mwwwwwwwwwwwwm",
                                "mwwwwwwwwwwwwm", "mwwwwwwwwwwwwm", "mwwwwwwwwwwwwm", "mwwwwwwwwwwwwm",
                                ".mwwwwwwwwwwm.", "..mmmmmmmmmm.."]
    static let puffSmall = ["ww", "ww"]
    static let puffMedium = [".w.", "www", ".w."]
    static let thoughtDot = ["kk", "kk"]
    static let gear = [
        ["...k...", ".kkkkk.", ".kk.kk.", "kk...kk", ".kk.kk.", ".kkkkk.", "...k..."],
        ["k.....k", ".kkkkk.", ".kk.kk.", ".k...k.", ".kk.kk.", ".kkkkk.", "k.....k"],
    ]
    static let bulb = ["..yyy..", ".yyyyy.", ".yywyy.", ".yyyyy.", "..yyy..", "..mmm..", "...m..."]
    static let blueQuestion = question.map { $0.replacingOccurrences(of: "y", with: "b") }

    // Searching
    static let lens = [".kkkkk.", "kccccck", "kcwkkck", "kckkkck", "kckkkck", "kccccck", ".kkkkk."]
    static func document(highlight: Bool) -> [String] {
        ["wwwwm.", "wwwwmm", "wkkkkw", "wwwwww", "wkkkww", "wwwwww", highlight ? "wyyyyw" : "wkkkkw", "wwwwww"]
    }

    // Coding (side view)
    static let codeTag = ["..g...g.g..", ".g....g..g.", "g....g....g", ".g..g....g.", "..g.g...g.."]
    static let sideGlasses = ["...kkkk", "kkkk..k", "...k..k", "...kkkk"]
    static let stool = [String(repeating: "n", count: 12)]
    static let stoolLeg = ["nn", "nn", "nn"]
    static let deskTop = [String(repeating: "n", count: 16)]
    static let deskLeg = ["n", "n", "n", "n", "n", "n"]
    static let laptopSideBase = [String(repeating: "l", count: 7)]
    static let laptopSideScreen = ["..m", "..m", ".mm", ".m.", ".m.", "mm.", "m..", "m.."]
    static let bug = [[".r.", "rrr", "k.k"], [".r.", "rrr", ".k."]]
    /// The glowing inner face of the side-view screen, in cycling colours.
    static func screenGlow(_ colors: [Character], shift: Int) -> [String] {
        laptopSideScreen.enumerated().map { r, row in
            String(row.map { $0 == "m" ? colors[(r + shift) % colors.count] : "." })
        }
    }

    // More Claude reactions
    static func clipboard(checked: Int) -> [String] {
        func box(_ i: Int) -> String { i < checked ? "g" : "m" }
        return ["..nn..", "wwwwww", "w\(box(0))wkkw", "wwwwww", "w\(box(1))wkkw", "wwwwww", "w\(box(2))wkkw", "wwwwww"]
    }
    static let plug = ["llll.", "lllkk", "llll."]
    static let socket = ["mmmm", "mkkm", "mmmm", "mkkm"]
    static let zap = ["y.", "yy", ".y"]
    static let gitGraph = [".g.....", ".mm....", ".m.m...", ".m..p..", ".g..m..", ".m..m..", ".m..p..", ".m.m...",
                           ".mm....", ".g.....", ".m.....", ".g....."]
    static func flask(_ liquid: Character) -> [String] {
        [".mmm.", ".m\(liquid)m.", ".m\(liquid)m.", "m\(liquid)\(liquid)\(liquid)m", "m\(liquid)\(liquid)\(liquid)m", "mmmmm"]
    }
    static let box = ["nnnnnn", "nnyynn", "nnyynn", "nnnnnn", "nnnnnn"]
    static let stopSign = [".rrrr.", "rrrrrr", "rwwwwr", "rrrrrr", ".rrrr.", "..mm..", "..mm..", "..mm..", "..mm..",
                           "..mm.."]
    static func hourglass(_ k: Int) -> [String] {
        ["nnnnn",
         "m" + (k < 3 ? "yyy" : "...") + "m",
         ".m" + (k < 2 ? "y" : ".") + "m.",
         k < 3 ? "..y.." : "..m..",
         ".m" + (k >= 1 ? "y" : ".") + "m.",
         "m" + (k >= 2 ? "yyy" : k >= 1 ? ".y." : "...") + "m",
         "nnnnn"]
    }
    static let megaphone = ["...ll", "lrlll", "lrlll", "...ll"]
    static let soundWave = [".w", "w.", "w.", ".w"].map { String($0.reversed()) }

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
    var profile: CGFloat = 0                 // side view: 1 shows only the right eye, -1 only the left

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
    case studying, planning, testing, git, packaging, plugging, delegating, blocked, nudge, rateLimited

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
    static let claude: [Act] = [.wakeUp, .perk, .thinking, .searching, .studying, .planning, .typing, .testing, .git,
                                .packaging, .building, .browsing, .plugging, .delegating, .alert, .blocked, .sad,
                                .squish, .wrap, .celebrate, .nudge, .rateLimited, .dizzy, .goodbye]

    var isLoop: Bool {
        [.thinking, .typing, .searching, .building, .browsing, .alert, .squish, .studying, .planning, .testing, .git,
         .packaging, .plugging, .delegating].contains(self)
    }

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
        case .thinking: return "Thought Bubble – thinking"
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
        case .studying: return "Book – loading a skill"
        case .planning: return "Clipboard – planning & to-dos"
        case .testing: return "Test Tube – running tests"
        case .git: return "Branch Tree – using git"
        case .packaging: return "Boxes – installing & building"
        case .plugging: return "Plug – using an MCP tool"
        case .delegating: return "Megaphone – starting a subagent"
        case .blocked: return "Stop Sign – action blocked"
        case .nudge: return "Wave – your turn"
        case .rateLimited: return "Hourglass – rate limited"
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
        case .coding: return 144
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
        case .thinking, .typing, .searching, .building, .browsing, .alert, .squish, .studying, .planning, .testing,
             .git, .packaging, .plugging, .delegating: return 96
        case .nudge: return 48
        case .blocked: return 36
        case .rateLimited: return 120
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
        p.dy = q % 2 == 0 ? 2 : 1
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
        add(Art.book[t % 40 > 34 ? 1 : 0], 3.25, 5.25)

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
        // Side view: sits on a stool at a desk and types on a laptop. A bug crawls in, gets squashed, ✓.
        let cyc = t % 144
        p.legs = [0, 0, 0, 0]
        p.back(f, .hidden)
        p.eyes = .look(f, 0)
        p.profile = f
        addF(Art.sideGlasses, 6, 2.5)
        addF(Art.stool, 3, 8)
        addF(Art.stoolLeg, 5.5, 8.5)
        addF(Art.deskTop, 11, 6.5)
        addF(Art.deskLeg, 11.5, 7)
        addF(Art.deskLeg, 18, 7)
        addF(Art.laptopSideBase, 12, 6)
        addF(Art.laptopSideScreen, 15.25, 2)
        let bugTime = cyc >= 84 && cyc < 114
        let glowColors: [Character] = bugTime ? ["r", "r", "r"] : ["g", "b", "y", "p"]
        addF(Art.screenGlow(glowColors, shift: t / 2), 14.75, 2)
        addF(Art.mug, 17, 4.5)
        addF(Art.pixel("l"), 17.75, 4 - CGFloat(t % 12) * 0.2)

        if cyc < 84 {
            p.front(f, (t / 2) % 2 == 0 ? .punch : .raised)               // typing
            p.dy = (t / 4) % 2 == 0 ? 0 : 0.25
            let colors: [Character] = ["g", "b", "y", "p"]
            for k in 0..<3 {
                let ph = CGFloat((t + k * 8) % 24)
                addF(Art.pixel(colors[(t / 24 + k) % 4]), 15 - ph * 0.12 + CGFloat(k) * 0.4, 2 - ph * 0.2)
            }
            if (t / 12) % 4 == 1 { addF(Art.codeTag, 12.5, -1.5 - CGFloat(t % 12) * 0.1) }
        } else {
            let bugX = 18.5 - CGFloat(min(cyc, 101) - 84) * 0.25
            if cyc < 102 {
                p.front(f, .raised); p.eyes = .big
                addF(Art.bug[(t / 2) % 2], bugX, 5)
                if (t / 6) % 2 == 0 { add(Art.bang, 5.5, -3) }
            } else if cyc < 114 {
                p.front(f, .up); p.eyes = .closed                          // wind up
                addF(Art.bug[0], bugX, 5)
            } else if cyc < 120 {
                p.front(f, .punch); p.dy = 0.5; p.sy = 0.95                // squash!
                addF(Art.star, bugX - 0.25, 4.5)
            } else {
                p.front(f, .raised); p.eyes = .happy
                add(Art.check, 4.25, -4)
            }
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
        add([String(repeating: "c", count: puddle)], 6 - CGFloat(puddle) * 0.25, 9.5)

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
        // Paces, then stops to tap its chin. The thought bubble cycles: dots, turning gear, "?", light bulb.
        let phase = (t / 24) % 4
        if phase == 0 || phase == 2 {
            fr.vx = 0.25 * f; p.walk(t, every: 4); p.eyes = .look(f, -1)
        } else {
            p.front(f, (t / 6) % 2 == 0 ? .raised : .out)
            p.eyes = (t / 8) % 2 == 0 ? .look(-1, -1) : .look(1, -1)
        }
        addF(Art.puffSmall, 8.5, 0.5)
        addF(Art.puffMedium, 9.25, -1.25)
        addF(Art.thoughtBubble, 8, -6.5)
        switch phase {
        case 0:
            for i in 0..<((t / 6) % 4) { addF(Art.thoughtDot, 9.75 + CGFloat(i) * 1.25, -4) }
        case 1:
            addF(Art.gear[(t / 4) % 2], 9.75, -5.25)
        case 2:
            addF(Art.blueQuestion, 10.25, -5)
        default:
            addF(Art.bulb, 9.75, -5.25)
            p.eyes = .big
            if t % 24 < 6 { p.dy = -1 }
        }

    case .typing:
        let swap = (t / 2) % 2 == 0
        p.left = swap ? .raised : .out; p.right = swap ? .out : .raised; p.eyes = .look(0, 1)
        add(Art.laptop[(t / 4) % 2], 3.5, 7)

    case .searching:
        // Scans with the magnifier held to its eye, then stops to read a found document.
        let cyc = t % 48
        p.front(f, .raised); p.eyes = .look(f, 0)
        var lensX: CGFloat = 6.75, lensY: CGFloat = 1.75
        if cyc < 32 {
            fr.vx = 0.18 * f; p.walk(t, every: 4)
            lensY += (t / 6) % 2 == 0 ? 0 : 0.5
            for k in 0..<3 where (t / 4 + k) % 3 == 0 {
                addF(Art.pixel("y"), 10.5 + CGFloat(k) * 0.6, 5.5 + CGFloat(k) * 1.1)   // scanning glint
            }
        } else {
            p.dx = 0.5 * f; lensX += 0.5
            addF(Art.document(highlight: (t / 3) % 2 == 0), 13, 1.5)
            if cyc >= 40 { addF(Art.star, 15.75, 0) }
        }
        addF(Art.lens, lensX, lensY)

    case .studying:
        var frame = render(.read, t, f)
        if (t / 8) % 2 == 0 { frame.props.append(Prop(art: Art.star, x: 10.5, y: 1)) }
        else { frame.props.append(Prop(art: Art.star, x: 0, y: 2)) }
        return frame

    case .planning:
        // Ticks off a to-do list on a clipboard, one box at a time.
        p.front(f, .raised); p.eyes = .look(f, 1)
        let checked = (t % 48) / 12
        addF(Art.clipboard(checked: checked), 11.5, 1.5)
        if t % 12 >= 9 && checked < 3 { p.back(f, .raised); p.dy = -0.25 }

    case .testing:
        // Shakes a bubbling test tube; the liquid changes colour as the tests run.
        let liquids: [Character] = ["g", "c", "p", "y"]
        p.front(f, .raised); p.eyes = .look(f, 0)
        p.dx = (t / 2) % 2 == 0 ? 0.15 : -0.15
        addF(Art.flask(liquids[(t / 16) % 4]), 11.5, 1)
        for k in 0..<3 {
            let ph = CGFloat((t + k * 5) % 15)
            addF(Art.pixel(liquids[(t / 16) % 4]), 12.5 + CGFloat(k % 2) * 0.5, 0.5 - ph * 0.25)
        }

    case .git:
        // A branch tree grows commit by commit next to it.
        p.front(f, .raised); p.eyes = .look(f, -1)
        let shown = min(12, (t % 72) / 5 + 1)
        let graph = Art.gitGraph.enumerated().map { r, row in r >= 12 - shown ? row : String(repeating: ".", count: row.count) }
        addF(graph, 12.5, -2.5, 0.75)
        if shown == 12 && (t / 4) % 2 == 0 { addF(Art.star, 12.5, -4) }

    case .packaging:
        // Parcels drop in front of it and stack up.
        let cyc = t % 72
        p.left = .raised; p.right = .raised
        let landed = min(3, cyc / 18)
        for i in 0..<landed { addF(Art.box, 13, 7.5 - CGFloat(i) * 2.5) }
        if landed < 3 {
            let fall = CGFloat(cyc % 18) / 18
            addF(Art.box, 13, -8 + fall * (15.5 - CGFloat(landed) * 2.5))
            p.eyes = .look(f, -1)
        } else {
            p.eyes = .happy
        }

    case .plugging:
        // Plugs a cable into a socket; it buzzes with power once connected.
        let cyc = t % 36
        p.front(f, .raised); p.eyes = .look(f, 1)
        addF(Art.socket, 17, 8)
        let plugX = cyc < 12 ? 12 + CGFloat(cyc) * 0.25 : 15
        addF(Art.plug, plugX, 8.5)
        for x in stride(from: CGFloat(11), to: plugX, by: 0.5) { addF(Art.pixel("k"), x, 4.5 + (x - 11)) }
        if cyc >= 12 {
            p.eyes = .big; p.dx = (t / 2) % 2 == 0 ? 0.2 : -0.2
            if (t / 3) % 2 == 0 { addF(Art.zap, 17.25, 6); addF(Art.zap, 11.5, 1) }
        }

    case .delegating:
        // Calls out orders through a megaphone (helper clones appear while subagents run).
        p.front(f, .raised); p.eyes = .look(f, 0); p.mouth = .o
        addF(Art.megaphone, 11.5, 3)
        if (t / 4) % 2 == 0 { addF(Art.soundWave, 14.5, 3); addF(Art.soundWave, 15.75, 2.5) }

    case .blocked:
        // Walks into a stop sign, bounces back and shakes its head.
        addF(Art.stopSign, 13, 5)
        if t < 10 {
            fr.vx = 0; p.walk(t, every: 2); p.dx = CGFloat(t) * 0.12 * f; p.eyes = .look(f, 0)
        } else if t < 16 {
            p.dx = (1.2 - CGFloat(t - 10) * 0.25) * f; p.eyes = .dizzy; addF(Art.star, 12, 2)
        } else {
            p.eyes = (t / 4) % 2 == 0 ? .look(-1, 0) : .look(1, 0)
            add(Art.sweat, f > 0 ? 0 : 10.5, 0.5)
        }

    case .nudge:
        // Turns to you and waves both arms: your turn.
        let up = (t / 4) % 2 == 0
        p.left = up ? .up : .raised; p.right = up ? .raised : .up; p.eyes = .big; p.mouth = .smile
        if (t / 12) % 2 == 0 { add(Art.question, 10.5, -2.5) }

    case .rateLimited:
        // Sits and waits next to an hourglass, tapping a foot.
        p.legs = [2, 2, 2, (t / 4) % 2 == 0 ? 1 : 2]; p.eyes = .sad
        p.front(f, .down)
        addF(Art.hourglass((t / 24) % 4), 13, 4.75, 0.75)

    case .building:
        p.eyes = .look(f, 1)
        addF(Art.brick, 14.5, 9)
        if (t / 5) % 2 == 0 {
            p.front(f, .up); addF(Art.hammerUp, 9.5, -2.5)
        } else {
            p.sy = 0.95; addF(Art.hammerDown, 12, 3.5); addF(Art.star, 14.5, 7.5)
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
        p.rot = f * .pi / 2; p.dy = -1; p.eyes = .dizzy
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

/// Draws the pet in body-grid space: a 12x10 grid with the feet on row 10.
func drawBody(_ ctx: CGContext, _ p: Pose, at origin: CGPoint, scale s: CGFloat = 1) {
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: p.dx, y: p.dy)
    ctx.translateBy(x: 6, y: 10); ctx.scaleBy(x: p.sx, y: p.sy); ctx.translateBy(x: -6, y: -10)
    ctx.translateBy(x: 6, y: 5); ctx.rotate(by: p.rot); ctx.translateBy(x: -6, y: -5)

    var shape = [CGRect(x: 2, y: 2, width: 8, height: 6)]
    if let r = armRect(p.left) { shape.append(r) }
    if let r = armRect(p.right) { shape.append(CGRect(x: 12 - r.maxX, y: r.minY, width: r.width, height: r.height)) }
    for (i, col) in [2, 4, 7, 9].enumerated() where p.legs[i] > 0 {
        shape.append(CGRect(x: CGFloat(col), y: 8, width: 1, height: p.legs[i]))
    }
    // A faint outline keeps the pet visible on wallpapers close to its own colour.
    ctx.setFillColor(outlineColor.cgColor)
    for (ox, oy) in [(-0.4, 0.0), (0.4, 0.0), (0.0, -0.4), (0.0, 0.4)] {
        shape.forEach { ctx.fill($0.offsetBy(dx: ox, dy: oy)) }
    }
    ctx.setFillColor(p.color.cgColor)
    shape.forEach { ctx.fill($0) }

    ctx.setFillColor(eyeColor.cgColor)
    if p.profile <= 0 { drawEye(ctx, p.eyes, 3, 3) }
    if p.profile >= 0 { drawEye(ctx, p.eyes, 8, 3) }
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
    /// Left and right edges of the walking area in view coordinates; nothing is drawn outside them.
    var clipX: ClosedRange<CGFloat>?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        if let clip = clipX {
            ctx.clip(to: CGRect(x: clip.lowerBound, y: bounds.minY, width: clip.upperBound - clip.lowerBound, height: bounds.height))
        }
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
    var onDragMove: (() -> Void)?
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
        if moved { window?.setFrameOrigin(NSPoint(x: p.x - grab.x, y: p.y - grab.y)); onDragMove?() }
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

/// The walking area drawn as a dashed outline with a solid floor; red when the pet is outside it.
final class AreaOutlineView: NSView {
    var inside = true { didSet { if inside != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        let color = inside ? rgb(0.85, 0.47, 0.34) : NSColor.systemRed
        let rect = bounds.insetBy(dx: 3, dy: 3)
        let box = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        color.withAlphaComponent(0.10).setFill()
        box.fill()
        box.lineWidth = 2.5
        box.setLineDash([8, 5], count: 2, phase: 0)
        color.setStroke()
        box.stroke()
        let floor = NSBezierPath()
        floor.move(to: NSPoint(x: rect.minX + 6, y: rect.minY))
        floor.line(to: NSPoint(x: rect.maxX - 6, y: rect.minY))
        floor.lineWidth = 4
        floor.lineCapStyle = .round
        floor.stroke()
        let label = inside ? "Walking area" : "Outside the walking area"
        label.draw(at: NSPoint(x: rect.minX + 10, y: rect.maxY - 22),
                   withAttributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: color])
    }
}

// MARK: - Pet

final class Pet: NSObject, NSMenuDelegate {
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
    var loginCheckbox: NSButton?
    var themePicker: NSPopUpButton?
    var timer: Timer?
    var speed: Double = {
        let saved = UserDefaults.standard.double(forKey: "speed")
        return saved > 0 ? saved : 1
    }()
    var updateCheckbox: NSButton?
    var availableUpdate: (version: String, zip: URL)?
    var updating = false
    var areaLabel: NSTextField?
    var pickerWindows: [NSWindow] = []
    var outlineWindow: NSWindow?
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
        // U starts at 8 for the README images; the pet itself defaults to the second step of the size slider.
        let savedSize = UserDefaults.standard.double(forKey: "size")
        U = savedSize > 0 ? CGFloat(savedSize) : 4
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
            if count >= 2 { self.interrupt([.backflip]); return }
            if self.clickAction == "Default" { self.heartTicks = 24 }   // the heart belongs to the default hop only
            self.interrupt([self.clickAct()])
            self.playClickSound()
        }
        view.onDrag = { [weak self] down in
            guard let self = self else { return }
            self.dragging = down
            if down {
                self.showAreaOutline()
            } else {
                self.posX = self.window.frame.origin.x
                self.keepInArea()
                self.hideAreaOutline(after: 0.2)
            }
        }
        view.onDragMove = { [weak self] in self?.updateAreaOutline() }
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
        // Look for a new release shortly after launch, then once a day.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.autoCheckForUpdates() }
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in self?.autoCheckForUpdates() }
        startTimer()
    }

    // MARK: Menu

    /// A small one-colour version of the pet; macOS tints it to match the menu bar.
    func menuBarIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let s: CGFloat = 1.5
            let rows = ["..########..", "..#.####.#..", "############", "############", "..########..",
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
        menu.delegate = self
        menus.append(menu)
        @discardableResult
        func item(_ title: String, _ action: Selector?, _ symbol: String? = nil, _ key: String = "", in m: NSMenu) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
            it.target = self
            if let symbol = symbol { it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            m.addItem(it)
            return it
        }
        func submenu(_ title: String, _ symbol: String, _ sub: NSMenu, in m: NSMenu) {
            let it = item(title, nil, symbol, in: m)
            sub.delegate = self
            it.submenu = sub
        }

        // What the minion is doing right now (kept up to date each time the menu opens).
        let status = item("", nil, "circle.fill", in: menu)
        status.tag = Pet.statusTag
        status.isEnabled = false
        menu.addItem(.separator())

        // The minion
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
        submenu("Play", "play.circle", play, in: menu)

        let themeMenu = NSMenu()
        for name in themes { item(name, #selector(themeChanged(_:)), in: themeMenu).image = themeSwatch(name) }
        submenu("Theme", "paintpalette", themeMenu, in: menu)

        let area = NSMenu()
        item("Anywhere", #selector(clearArea), "rectangle.bottomthird.inset.filled", in: area)
        item("Custom Area", #selector(useCustomArea), "rectangle.dashed", in: area)
        area.addItem(.separator())
        item("Draw New Area…", #selector(pickArea), "pencil.and.outline", in: area)
        submenu("Walking Area", "figure.walk", area, in: menu)

        let clickActions = NSMenu()
        fillClickActionMenu(clickActions)
        submenu("Click Action", "hand.tap", clickActions, in: menu)
        let sounds = NSMenu()
        soundMenus.append(sounds)
        submenu("Click Sound", "speaker.wave.2", sounds, in: menu)
        item("Stay in Place", #selector(toggleStill(_:)), "pin", in: menu)
        item("Hide Pet", #selector(toggleVisible), "eye.slash", in: menu)
        menu.addItem(.separator())

        // Claude
        let claude = NSMenu()
        let connection = item("", nil, nil, in: claude)
        connection.tag = Pet.connectionTag
        connection.isEnabled = false
        claude.addItem(.separator())
        item("React to Claude", #selector(toggleReact(_:)), "bolt", in: claude)
        item("Connect to Claude…", #selector(toggleClaudeHooks), "link", in: claude)
        submenu("Claude", "sparkles", claude, in: menu)
        menu.addItem(.separator())

        // App
        item("Settings…", #selector(openSettings), "gearshape", ",", in: menu)
        item("Check for Updates…", #selector(updateMenuClicked), "arrow.down.circle", in: menu)
        item("About Claudinion", #selector(openAbout), "info.circle", in: menu)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Claudinion", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quit)
        return menu
    }

    static let statusTag = 101
    static let connectionTag = 102

    /// A one-line description of what the minion is up to, for the top of the menu.
    func statusText() -> String {
        func claudeDoing(_ a: Act) -> String {
            let what = a.title.components(separatedBy: "– ").last ?? a.title
            return "Claude: " + what.prefix(1).uppercased() + what.dropFirst()
        }
        if !window.isVisible { return "Hidden" }
        if dragging { return "Being carried" }
        if reactToClaude, let l = loop { return claudeDoing(l) }
        if transient && Act.claude.contains(act) { return claudeDoing(act) }
        return act == .idle ? "Resting" : "Playing: \(act.title)"
    }

    /// A tiny minion in a theme's colours, for the Theme menu.
    func themeSwatch(_ name: String) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let saved = theme
            theme = name
            defer { theme = saved }
            let s: CGFloat = 1.5
            let rows = ["..########..", "..#.####.#..", "############", "############",
                        "..########..", "..########..", "..#.#..#.#..", "..#.#..#.#.."]
            let top = (18 - CGFloat(rows.count) * s) / 2
            func fill(_ color: NSColor, dx: CGFloat = 0, dy: CGFloat = 0, _ match: Character) {
                color.setFill()
                for (r, row) in rows.enumerated() {
                    for (c, ch) in row.enumerated() where ch == match {
                        NSRect(x: CGFloat(c) * s + dx, y: top + CGFloat(r) * s + dy, width: s, height: s).fill()
                    }
                }
            }
            if name != "Classic" {
                for (dx, dy) in [(-0.6, 0.0), (0.6, 0.0), (0.0, -0.6), (0.0, 0.6)] { fill(outlineColor, dx: CGFloat(dx), dy: CGFloat(dy), "#") }
            }
            fill(name == "Classic" ? rgb(0.85, 0.47, 0.34) : orange, "#")
            eyeColor.setFill()
            for c in [3, 8] { NSRect(x: CGFloat(c) * s, y: top + s, width: s, height: s).fill() }
            return true
        }
        return img
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if soundMenus.contains(where: { $0 === menu }) { fillSoundMenu(menu) }
        refreshMenus()
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
        let outdated = needsUpdate()
        func allItems(_ m: NSMenu) -> [NSMenuItem] { m.items.flatMap { [$0] + ($0.submenu.map(allItems) ?? []) } }
        loginCheckbox?.state = startsAtLogin ? .on : .off
        themePicker?.selectItem(withTitle: theme)
        for menu in menus {
            for item in allItems(menu) {
                if item.tag == Pet.statusTag {
                    item.title = statusText()
                    let dot = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                        .withSymbolConfiguration(.init(paletteColors: [loop != nil && reactToClaude ? .systemGreen : .secondaryLabelColor]))
                    item.image = dot
                }
                if item.tag == Pet.connectionTag {
                    item.title = outdated ? "Connection needs an update" : connected ? "Connected to Claude Code" : "Not connected"
                }
                switch item.action {
                case #selector(toggleReact(_:)): item.state = reactToClaude ? .on : .off
                case #selector(toggleStill(_:)): item.state = stayStill ? .on : .off
                case #selector(clearArea): item.state = walkArea == nil ? .on : .off
                case #selector(useCustomArea):
                    item.state = walkArea == nil ? .off : .on
                case #selector(toggleLogin): item.state = startsAtLogin ? .on : .off
                case #selector(clickActionChosen(_:)): item.state = item.representedObject as? String == clickAction ? .on : .off
                case #selector(themeChanged(_:)): item.state = item.title == theme ? .on : .off
                case #selector(updateMenuClicked):
                    item.title = updating ? "Updating…" : availableUpdate.map { "Update to v\($0.version)…" } ?? "Check for Updates…"
                case #selector(toggleVisible):
                    item.image = NSImage(systemSymbolName: window.isVisible ? "eye.slash" : "eye", accessibilityDescription: nil)
                    item.title = window.isVisible ? "Hide Pet" : "Show Pet"
                case #selector(toggleClaudeHooks):
                    item.title = outdated ? "Update Claude Connection…" : connected ? "Disconnect from Claude…" : "Connect to Claude…"
                default: break
                }
            }
        }
    }

    // MARK: Claude hooks

    static let hookEvents = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
                             "PermissionRequest", "PermissionDenied", "Notification", "SubagentStart", "SubagentStop", "Stop",
                             "StopFailure", "PreCompact", "PostCompact", "TaskCompleted", "CwdChanged", "SessionEnd"]
    let claudeSettingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")

    func isPetHook(_ hook: Any) -> Bool {
        guard let command = (hook as? [String: Any])?["command"] as? String else { return false }
        return command.contains("Claudinion") && command.contains("--hook")
    }

    /// Which hook events in ~/.claude/settings.json currently point at Claudinion.
    func connectedEvents() -> Set<String> {
        guard let data = try? Data(contentsOf: claudeSettingsURL),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = root["hooks"] as? [String: Any] else { return [] }
        return Set(hooks.compactMap { event, groups in
            (groups as? [[String: Any]] ?? []).contains { ($0["hooks"] as? [Any] ?? []).contains(where: isPetHook) } ? event : nil
        })
    }

    func isConnected() -> Bool { !connectedEvents().isEmpty }

    /// Connected, but set up by an older version that didn't hook every event this one uses.
    func needsUpdate() -> Bool {
        let events = connectedEvents()
        return !events.isEmpty && !Set(Pet.hookEvents).isSubset(of: events)
    }

    @objc func toggleClaudeHooks() {
        let updating = needsUpdate()
        let connected = isConnected() && !updating
        let alert = NSAlert()
        alert.messageText = connected ? "Disconnect from Claude?" : updating ? "Update the Claude connection?" : "Connect to Claude?"
        alert.informativeText = connected
            ? "This removes the Claudinion hooks from ~/.claude/settings.json."
            : "This adds hooks to ~/.claude/settings.json so the pet reacts to Claude Code in the terminal and in the Claude app's Code tab. Your current file is backed up as settings.json.before-claudinion.\n\nStart a new Claude session afterwards."
        alert.addButton(withTitle: connected ? "Disconnect" : updating ? "Update" : "Connect")
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
        fillSoundPopup()
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

        let speedSlider = NSSlider(value: speed, minValue: 0.5, maxValue: 2, target: self, action: #selector(speedChanged(_:)))
        speedSlider.numberOfTickMarks = 7
        speedSlider.allowsTickMarkValuesOnly = true
        speedSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let speedRow = NSStackView(views: [NSTextField(labelWithString: "Slower"), speedSlider, NSTextField(labelWithString: "Faster")])

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
        let themePicker = NSPopUpButton(frame: .zero, pullsDown: false)
        themePicker.addItems(withTitles: themes)
        themePicker.selectItem(withTitle: theme)
        themePicker.target = self
        themePicker.action = #selector(themeChanged(_:))
        self.themePicker = themePicker
        let pickerHint = NSTextField(labelWithString: "Classic orange, Charcoal with an orange glow, or a Shadow silhouette.")
        pickerHint.font = .systemFont(ofSize: 11)
        pickerHint.textColor = .secondaryLabelColor
        let pickerRow = NSStackView(views: [NSTextField(labelWithString: "Theme:"), themePicker, pickerHint])
        let themeRow = NSStackView(views: [NSTextField(labelWithString: "Light / Dark:"), themePopup, themeHint])
        let themeBlock = NSStackView(views: [pickerRow, themeRow])
        themeBlock.orientation = .vertical
        themeBlock.alignment = .leading

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

        let login = NSButton(checkboxWithTitle: "Start Claudinion when you log in", target: self, action: #selector(toggleLogin))
        login.state = startsAtLogin ? .on : .off
        loginCheckbox = login
        let autoUpdate = NSButton(checkboxWithTitle: "Check for updates automatically", target: self, action: #selector(toggleAutoUpdates(_:)))
        autoUpdate.state = autoUpdateChecks ? .on : .off
        updateCheckbox = autoUpdate
        let version = NSTextField(labelWithString: "Version \(currentVersion)")
        version.font = .systemFont(ofSize: 11)
        version.textColor = .secondaryLabelColor
        let updateRow = NSStackView(views: [autoUpdate, NSButton(title: "Check Now", target: self, action: #selector(checkNow)), version])

        let soundPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        soundPicker.target = self
        soundPicker.action = #selector(soundPopupChanged(_:))
        soundPopup = soundPicker
        let volume = NSSlider(value: Double(soundVolume), minValue: 0, maxValue: 1, target: self, action: #selector(volumeChanged(_:)))
        volume.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let actionPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        actionPicker.menu?.removeAllItems()
        if let m = actionPicker.menu { fillClickActionMenu(m) }
        actionPopup = actionPicker
        if let item = actionPicker.itemArray.first(where: { $0.representedObject as? String == clickAction }) { actionPicker.select(item) }
        let actionRow = NSStackView(views: [NSTextField(labelWithString: "Action:"), actionPicker])

        let soundRow = NSStackView(views: [
            NSTextField(labelWithString: "Sound:"), soundPicker,
            NSImageView(image: NSImage(systemSymbolName: "speaker.wave.1", accessibilityDescription: nil)!), volume,
            NSButton(title: "Open Sounds Folder", target: self, action: #selector(openSoundsFolder)),
        ])

        let stack = NSStackView(views: [login, updateRow, heading("Size"), sizeRow, heading("Speed"), speedRow,
                                        heading("When clicked"), actionRow, soundRow, heading("Appearance"), themeBlock,
                                        heading("Where it walks"), areaRow, heading("Actions it does on its own"), grid, buttons, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(24, after: updateRow)
        stack.setCustomSpacing(24, after: sizeRow)
        stack.setCustomSpacing(24, after: speedRow)
        stack.setCustomSpacing(24, after: soundRow)
        stack.setCustomSpacing(24, after: themeBlock)
        stack.setCustomSpacing(24, after: areaRow)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        w.contentView = stack
        w.setContentSize(stack.fittingSize)
        w.center()
        return w
    }

    // MARK: Click action

    var clickAction = UserDefaults.standard.string(forKey: "clickAction") ?? "Default"   // "Default", "Random" or an action
    var actionPopup: NSPopUpButton?

    /// What a single click makes the pet do.
    func clickAct() -> Act {
        switch clickAction {
        case "Default": return .hop
        case "Random": return Act.freePlay.randomElement()!
        default: return Act(rawValue: clickAction) ?? .hop
        }
    }

    func setClickAction(_ value: String) {
        clickAction = value
        UserDefaults.standard.set(value, forKey: "clickAction")
        if let popup = actionPopup, let item = popup.itemArray.first(where: { $0.representedObject as? String == value }) {
            popup.select(item)
        }
        refreshMenus()
    }

    @objc func clickActionChosen(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? String { setClickAction(value) }
    }

    /// Default and Random first, then every action by category. Used for both the menu and the settings popup.
    func fillClickActionMenu(_ menu: NSMenu) {
        func add(_ title: String, _ value: String, _ symbol: String? = nil) {
            let it = NSMenuItem(title: title, action: #selector(clickActionChosen(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = value
            if let symbol = symbol { it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            menu.addItem(it)
        }
        add("Default (Hop with a Heart)", "Default", "heart")
        add("Random", "Random", "shuffle")
        for c in Act.categories {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: c.name))
            c.acts.forEach { add($0.title, $0.rawValue) }
        }
    }

    // MARK: Click sounds

    /// Sounds the user adds here show up under "My Sounds"; macOS's built-in sounds are always offered too.
    let soundsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claudinion/Sounds")
    var clickSound = UserDefaults.standard.string(forKey: "clickSound") ?? "Pop"   // "Off", "Random" or a sound name
    var soundVolume: Float = {
        let saved = UserDefaults.standard.object(forKey: "soundVolume") as? Double
        return Float(saved ?? 0.6)
    }()
    var currentSound: NSSound?
    var soundMenus: [NSMenu] = []
    var soundPopup: NSPopUpButton?

    func soundFiles(in dir: URL, types: [String]) -> [(name: String, url: URL)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { types.contains($0.pathExtension.lowercased()) }
            .map { ($0.deletingPathExtension().lastPathComponent, $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var mySounds: [(name: String, url: URL)] {
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        return soundFiles(in: soundsDir, types: ["mp3", "wav", "m4a", "aiff", "aif", "caf"])
    }

    var macSounds: [(name: String, url: URL)] {
        soundFiles(in: URL(fileURLWithPath: "/System/Library/Sounds"), types: ["aiff"])
    }

    func playClickSound() {
        guard clickSound != "Off" else { return }
        let all = mySounds + macSounds
        let pick = clickSound == "Random" ? all.randomElement() : all.first { $0.name == clickSound }
        guard let url = pick?.url, let sound = NSSound(contentsOf: url, byReference: true) else { return }
        currentSound?.stop()
        currentSound = sound
        sound.volume = soundVolume
        sound.play()
    }

    func setClickSound(_ name: String) {
        clickSound = name
        UserDefaults.standard.set(name, forKey: "clickSound")
        playClickSound()                  // preview the choice
        soundPopup?.selectItem(withTitle: name)
    }

    @objc func soundChosen(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { setClickSound(name) }
    }

    @objc func soundPopupChanged(_ sender: NSPopUpButton) {
        if let name = sender.selectedItem?.representedObject as? String { setClickSound(name) }
    }

    @objc func volumeChanged(_ sender: NSSlider) {
        soundVolume = Float(sender.doubleValue)
        UserDefaults.standard.set(sender.doubleValue, forKey: "soundVolume")
    }

    @objc func openSoundsFolder() {
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(soundsDir)
    }

    /// Rebuilt each time it opens, so files added to the Sounds folder appear straight away.
    func fillSoundMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ value: String, _ symbol: String? = nil) {
            let it = NSMenuItem(title: title, action: #selector(soundChosen(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = value
            it.state = clickSound == value ? .on : .off
            if let symbol = symbol { it.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
            menu.addItem(it)
        }
        add("Off", "Off", "speaker.slash")
        add("Random", "Random", "shuffle")
        let mine = mySounds
        if !mine.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "My Sounds"))
            mine.forEach { add($0.name, $0.name) }
        }
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "macOS Sounds"))
        macSounds.forEach { add($0.name, $0.name) }
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open Sounds Folder…", action: #selector(openSoundsFolder), keyEquivalent: "")
        open.target = self
        open.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(open)
    }

    func fillSoundPopup() {
        guard let popup = soundPopup else { return }
        popup.removeAllItems()
        let names = ["Off", "Random"] + mySounds.map(\.name) + macSounds.map(\.name)
        for name in names {
            popup.addItem(withTitle: name)
            popup.lastItem?.representedObject = name
        }
        popup.selectItem(withTitle: clickSound)
    }

    // MARK: Start at login

    var startsAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    @objc func toggleLogin() {
        do {
            if startsAtLogin { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
        if SMAppService.mainApp.status == .requiresApproval {
            let alert = NSAlert()
            alert.messageText = "Allow Claudinion to start at login"
            alert.informativeText = "macOS needs your OK. Turn Claudinion on under Login Items in System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
        }
        refreshMenus()
    }

    // MARK: Updates

    static let repo = "tarek-89/Claudinion"
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    var autoUpdateChecks: Bool {
        get { UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoCheckUpdates") }
    }

    /// True when version `a` (like "1.10.0" or "v1.2") is newer than `b`.
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: ".").map { Int($0) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    func autoCheckForUpdates() {
        if autoUpdateChecks { checkForUpdates(quietly: true) }
    }

    @objc func updateMenuClicked() {
        if availableUpdate != nil { installUpdate() } else { checkForUpdates(quietly: false) }
    }

    @objc func toggleAutoUpdates(_ sender: NSButton) {
        autoUpdateChecks = sender.state == .on
    }

    @objc func checkNow() { checkForUpdates(quietly: false) }

    /// Asks GitHub for the latest release. With `quietly`, only an available update is announced (in the menu).
    func checkForUpdates(quietly: Bool) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Pet.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            let release = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
            let tag = release?["tag_name"] as? String
            let zip = (release?["assets"] as? [[String: Any]])?
                .first { ($0["name"] as? String) == "Claudinion.zip" }
                .flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
            DispatchQueue.main.async {
                if let tag = tag, let zip = zip, Pet.isNewer(tag, than: self.currentVersion) {
                    let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    self.availableUpdate = (version, zip)
                    self.refreshMenus()
                    if !quietly { self.installUpdate() }
                } else if !quietly {
                    self.showAlert(tag == nil ? "Couldn't check for updates" : "You're up to date",
                                   tag == nil ? (error?.localizedDescription ?? "GitHub didn't return a release.")
                                              : "Claudinion \(self.currentVersion) is the latest version.")
                }
            }
        }.resume()
    }

    func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// Downloads the new release, swaps it in for the running app and relaunches.
    func installUpdate() {
        guard let update = availableUpdate, !updating else { return }
        let alert = NSAlert()
        alert.messageText = "Update to Claudinion \(update.version)?"
        alert.informativeText = "You have \(currentVersion). Claudinion will download the new version, replace itself and restart. Your settings are kept."
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: break
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(URL(string: "https://github.com/\(Pet.repo)/releases/latest")!)
            return
        default: return
        }

        updating = true
        refreshMenus()
        URLSession.shared.downloadTask(with: update.zip) { file, _, error in
            let result = Result { () -> URL in
                guard let file = file else { throw error ?? CocoaError(.fileReadUnknown) }
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("claudinion-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzip.arguments = ["-x", "-k", file.path, work.path]
                try unzip.run()
                unzip.waitUntilExit()
                let app = work.appendingPathComponent("Claudinion.app")
                let version = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                guard unzip.terminationStatus == 0, version == update.version else {
                    throw NSError(domain: "Claudinion", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded update looks incomplete. Please try again later."])
                }
                return app
            }
            DispatchQueue.main.async { self.finishUpdate(result) }
        }.resume()
    }

    func finishUpdate(_ result: Result<URL, Error>) {
        do {
            let newApp = try result.get()
            _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: newApp)
            // Reopen the new copy once this one has quit.
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 1; open \"$0\"", Bundle.main.bundleURL.path]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            updating = false
            refreshMenus()
            showAlert("Update failed", error.localizedDescription)
        }
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
        showAreaOutline()
        hideAreaOutline(after: 1.5)
    }

    /// Shows the custom walking area (if there is one) while the pet is being dragged.
    func showAreaOutline() {
        guard let area = walkArea else { return }
        let frame = area.insetBy(dx: -3, dy: -3)
        let w = outlineWindow ?? {
            let w = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .floating
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            w.contentView = AreaOutlineView(frame: NSRect(origin: .zero, size: frame.size))
            return w
        }()
        outlineWindow = w
        w.setFrame(frame, display: true)
        w.alphaValue = 1
        w.orderFrontRegardless()
        window.orderFrontRegardless()      // keep the pet above the outline
        updateAreaOutline()
    }

    func updateAreaOutline() {
        guard let area = walkArea, let view = outlineWindow?.contentView as? AreaOutlineView else { return }
        let feet = NSPoint(x: window.frame.minX + (bodyX + 6) * U, y: window.frame.minY)
        view.inside = area.insetBy(dx: -1, dy: -1).contains(feet)
    }

    func hideAreaOutline(after delay: TimeInterval) {
        guard let w = outlineWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.dragging else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                w.animator().alphaValue = 0
            }, completionHandler: { if !self.dragging { w.orderOut(nil) } })
        }
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

    @objc func themeChanged(_ sender: NSObject) {
        if let popup = sender as? NSPopUpButton { theme = popup.titleOfSelectedItem ?? "Classic" }
        if let item = sender as? NSMenuItem { theme = item.title }
        UserDefaults.standard.set(theme, forKey: "theme")
        refreshMenus()
    }

    @objc func appearanceChanged(_ sender: NSPopUpButton) {
        appearance = sender.titleOfSelectedItem ?? "Auto"
        UserDefaults.standard.set(appearance, forKey: "appearance")
    }

    /// Runs the animation at 12 frames per second, scaled by the speed setting.
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / (12.0 * speed), repeats: true) { [weak self] _ in self?.step() }
    }

    @objc func speedChanged(_ sender: NSSlider) {
        speed = (sender.doubleValue * 4).rounded() / 4
        UserDefaults.standard.set(speed, forKey: "speed")
        startTimer()
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

    func toolAct(_ tool: String, command kind: String?) -> Act {
        switch tool {
        case "Bash", "BashOutput", "KillShell", "Monitor":
            switch kind {
            case "test": return .testing
            case "git": return .git
            case "install", "build": return .packaging
            default: return .typing
            }
        case "Read", "Grep", "Glob", "LS", "NotebookRead", "ToolSearch": return .searching
        case "Edit", "Write", "MultiEdit", "NotebookEdit": return .building
        case "WebFetch", "WebSearch": return .browsing
        case "TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "EnterPlanMode": return .planning
        case "Agent", "Task": return .delegating
        case "Skill": return .studying
        case "AskUserQuestion", "ExitPlanMode": return .alert
        default:
            let name = tool.lowercased()
            if name.contains("browser") || name.contains("chrome") || name.contains("web") { return .browsing }
            if name.contains("search") || name.contains("read") || name.contains("find") || name.contains("query") {
                return .searching
            }
            if name.hasPrefix("mcp__") { return .plugging }
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
            loop = toolAct(e["tool_name"] as? String ?? "", command: e["command_kind"] as? String)
        case "PostToolUse":
            if loop != .squish { loop = .thinking }
        case "PostToolUseFailure":
            loop = .thinking; interrupt([.sad])
        case "PermissionRequest":
            loop = .alert
        case "PermissionDenied":
            loop = .thinking; interrupt([.blocked])
        case "Notification":
            let type = e["notification_type"] as? String ?? ""
            if type == "permission_prompt" || type == "elicitation_dialog" { loop = .alert }
            if type == "idle_prompt" { loop = nil; interrupt([.nudge]) }
        case "SubagentStart":
            subagents += 1
        case "SubagentStop":
            subagents = max(0, subagents - 1)
        case "Stop":
            loop = nil; subagents = 0; interrupt([.celebrate])
        case "StopFailure":
            loop = nil; subagents = 0
            let error = (e["error"] as? String ?? "").lowercased()
            interrupt([error.contains("rate") ? .rateLimited : .dizzy])
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
            return (p, CGPoint(x: i == 0 ? -6.5 : 12.5, y: 5))
        }

        if !dragging { move(fr) }
        if let area = walkArea, !dragging {
            let lo = area.minX - window.frame.minX, hi = area.maxX - window.frame.minX
            view.clipX = lo < hi ? lo...hi : nil
        } else {
            view.clipX = nil
        }
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
        ctx.translateBy(x: 512 - 6 * 52, y: 512 - 6 * 52)
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
                                .typing: 4, .coding: 20, .shower: 8, .read: 4, .juggle: 6, .meditate: 10, .sleep: 20,
                                .thinking: 74, .searching: 40, .studying: 4, .planning: 30, .testing: 6, .git: 60,
                                .packaging: 50, .plugging: 20, .delegating: 2, .blocked: 13, .nudge: 2, .rateLimited: 30]
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
