// Copyright (c) 2026 Alden Lougee. All rights reserved.
// Proprietary and confidential. Unauthorized copying, modification,
// distribution, or derivative use is prohibited.

import UIKit
import SwiftUI
import Combine
import Speech
import AVFoundation

/// The speech-bubble shape behind a key's press-preview popup. Was
/// referenced by `letterKey` without ever being defined in this target —
/// a pre-existing build break unrelated to any redaction/keyboard work in
/// this session, just never caught because this target hadn't been built
/// standalone recently. Mirrors ToneLayer iOS's identical shape.
struct KeyPopupBubble: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 8
        let tailWidth: CGFloat = 16
        let tailHeight: CGFloat = 7
        let bodyRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)

        var path = Path(roundedRect: bodyRect, cornerRadius: cornerRadius, style: .continuous)
        var tail = Path()
        tail.move(to: CGPoint(x: rect.midX - tailWidth / 2, y: bodyRect.maxY))
        tail.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        tail.addLine(to: CGPoint(x: rect.midX + tailWidth / 2, y: bodyRect.maxY))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

// MARK: - Dictation

@MainActor
final class ClarityDictationManager: ObservableObject {
    @Published var isRecording = false
    @Published var partialText = ""

    private let recognizer = SFSpeechRecognizer(locale: .current)
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle(onInsert: @escaping (String) -> Void) {
        if isRecording { finish(onInsert: onInsert) } else { start(onInsert: onInsert) }
    }

    private func start(onInsert: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized, let self else { return }
            Task { @MainActor in self.beginRecording(onInsert: onInsert) }
        }
    }

    private func beginRecording(onInsert: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buf, _ in
            self?.request?.append(buf)
        }
        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.partialText = result.bestTranscription.formattedString
                if result.isFinal { self.finish(onInsert: onInsert) }
            }
            if error != nil { self.finish(onInsert: onInsert) }
        }
    }

    func finish(onInsert: @escaping (String) -> Void) {
        let text = partialText
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        if !text.isEmpty { onInsert(text); partialText = "" }
    }
}

// MARK: - Native key styling

/// The subtle bottom-edge "keycap" shadow every native iOS keyboard key
/// has, matching ToneLayer's keyboard (see that project's
/// KeyboardViewController.swift for the shared origin of this styling).
extension View {
    func keycapShadow() -> some View {
        shadow(color: Color.black.opacity(0.30), radius: 0, x: 0, y: 1)
    }

    /// Extends a key's invisible tap target out to the midpoint of the
    /// gaps around it, so a tap landing between two keys still registers
    /// on the nearer one, matching Apple's own keyboard.
    func keyTapTarget(h: CGFloat = 2.5, v: CGFloat = 3) -> some View {
        self
            .padding(.horizontal, h)
            .padding(.vertical, v)
            .contentShape(Rectangle())
            .padding(.horizontal, -h)
            .padding(.vertical, -v)
    }
}

// MARK: - Colors

extension Color {
    static let clarityAccent     = Color(red: 0.435, green: 0.310, blue: 0.745)
    static let clarityBackground = Color(red: 0.89,  green: 0.85,  blue: 0.99)
    static let claritySpecialKey = Color(UIColor.systemGray4)
    static let keyboardKey = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1.0)
            : UIColor.white
    })
    static let keyboardText = Color(UIColor.label)
}

// MARK: - Principal class

class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // The default system keyboard height is too short for our extra rows
        // (teaching strip, action bar, 4 rows of keys), which was clipping
        // the bottom row. Request a taller view so nothing gets cut off.
        let heightConstraint = view.heightAnchor.constraint(equalToConstant: 340)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true

        let host = UIHostingController(rootView: KeyboardView(inputVC: self))
        host.view.backgroundColor = .clear
        host.view.clipsToBounds = true
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        host.view.translatesAutoresizingMaskIntoConstraints = false

        let top   = host.view.topAnchor.constraint(equalTo: view.topAnchor)
        let bot   = host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let lead  = host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let trail = host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        NSLayoutConstraint.activate([top, bot, lead, trail])
    }
}

// MARK: - SwiftUI keyboard view

struct KeyboardView: View {
    let inputVC: UIInputViewController

    private let appGroupID = "group.com.alden.ndclarity"
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private let serverURL = "https://tonelayer-server-production.up.railway.app/rewrite"
    private let appToken  = "d731136d97cdd46453e7581465537e0d9aee811512b885c2"

    @State private var profileADHD   = false
    @State private var profileAutism  = false
    @State private var profilePTSD    = false
    @State private var profileCPTSD   = false
    @State private var level              = "Medium"
    @State private var isRewriting        = false
    @StateObject private var dictation    = ClarityDictationManager()
    @State private var status             = ""
    @State private var spiralEnabled      = true
    @State private var isShifted          = false
    @State private var capsLocked         = false
    @State private var lastShiftTap: Date?
    @State private var isNumbers          = false
    @State private var isSymbols          = false
    @State private var pressedKeyTitle: String?
    @State private var deleteTimer: Timer?
    @State private var spaceDragAccumulated: CGFloat = 0
    @State private var keyboardTypedText  = ""
    @State private var keyboardWidth       = CGFloat(0)
    @State private var previewText        = ""
    @State private var previewGrammar     = ""
    @State private var pendingDeleteCount = 0
    @State private var teachingBody       = ""
    @State private var showTeachingExpanded = false
    @State private var showSpiral          = false

    private var activeProfiles: String {
        var p: [String] = []
        if profileADHD   { p.append("ADHD") }
        if profileAutism { p.append("AUT") }
        if profilePTSD   { p.append("PTSD") }
        if profileCPTSD  { p.append("CPTSD") }
        return p.isEmpty ? "General ND" : p.joined(separator: "+")
    }

    var body: some View {
        let agreed = defaults?.bool(forKey: "clarityBetaAgreementAccepted.v1") ?? false
        return VStack(spacing: 0) {
            topBar
            Divider()
            if !agreed {
                agreementRequiredView
            } else if showTeachingExpanded {
                clarityTeachingExpandedView.transition(.move(edge: .top).combined(with: .opacity))
            } else if !previewText.isEmpty {
                clarityRewriteResultView.transition(.move(edge: .top).combined(with: .opacity))
            } else {
                mainPanel
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .background(
            Color(UIColor.systemGroupedBackground)
                .overlay(Color.clarityAccent.opacity(0.06))
        )
        .preferredColorScheme(.light)
        .onAppear { loadSettings() }
    }

    private var agreementRequiredView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.clarityAccent)
            Text("Open the Clarity app to accept the Beta Agreement before using the keyboard.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "yinyang")
                .foregroundStyle(Color.clarityAccent)
                .font(.system(size: 15))
            VStack(alignment: .leading, spacing: 1) {
                Text("Clarity")
                    .font(.system(size: 11, weight: .bold))
                Text(activeProfiles)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("NT \u{2192} ND")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.clarityAccent)
                    .lineLimit(1)
                Text(levelKeyTitle(level))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { inputVC.dismissKeyboard() } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    // MARK: - Main panel

    private var mainPanel: some View {
        VStack(spacing: 2) {
            clarityTeachingStrip
            clarityActionBar.padding(.horizontal, 4)
            if dictation.isRecording && !dictation.partialText.isEmpty {
                Text("🎤 " + dictation.partialText)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .lineLimit(2)
            } else if !status.isEmpty {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .lineLimit(1)
            }
            keyboardSection.padding(.horizontal, 4).padding(.bottom, 4)
        }
        .padding(.top, 2)
    }

    private var clarityTeachingStrip: some View {
        Button {
            if !teachingBody.isEmpty { withAnimation { showTeachingExpanded = true } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.clarityAccent)
                Text(teachingBody.isEmpty ? "Tap Rewrite to see a teaching note" : teachingBody)
                    .font(.system(size: 10))
                    .foregroundStyle(teachingBody.isEmpty ? Color(UIColor.tertiaryLabel) : Color.keyboardText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !teachingBody.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.clarityAccent)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(UIColor.systemBackground).opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private var clarityTeachingExpandedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clarityAccent)
                    Text("Teaching note")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.clarityAccent)
                }
                Spacer()
                Button { withAnimation { showTeachingExpanded = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.vertical, showsIndicators: true) {
                Text(teachingBody)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.keyboardText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            }
            .frame(maxHeight: 170)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.clarityAccent.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private var clarityRewriteResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showSpiral {
                Text("\u{1F49A} Pause for a sec?")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clarityAccent)
                Text("This phrasing might land differently than you intend. Here's an ND-friendly version \u{2014} or pick another option.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("\u{2728} Here's the rewrite")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.clarityAccent)
            }
            ScrollView(.vertical, showsIndicators: true) {
                Text(previewText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.keyboardText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 140)
            HStack(spacing: 8) {
                chipButton("Original", primary: false) {
                    previewText = ""
                    previewGrammar = ""
                    pendingDeleteCount = 0
                    showSpiral = false
                    showStatus("Kept your original")
                }
                chipButton("Grammar", primary: false) {
                    applyPreview(previewGrammar.isEmpty ? previewText : previewGrammar)
                }
                chipButton("Use ND \u{2713}", primary: true) {
                    applyPreview(previewText)
                }
            }
            if !teachingBody.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.clarityAccent.opacity(0.8))
                    Text(teachingBody)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.clarityAccent.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var clarityActionBar: some View {
        HStack(spacing: 4) {
            ForEach(["Light", "Medium", "Strong"], id: \.self) { l in
                Button {
                    level = l
                    defaults?.set(l, forKey: "rewriteLevel")
                } label: {
                    Text(levelKeyTitle(l))
                        .font(.system(size: 10, weight: level == l ? .bold : .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(level == l ? Color.clarityAccent : Color.claritySpecialKey)
                        .foregroundStyle(level == l ? Color.white : Color.keyboardText)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 20)
            rewriteChip("Rewrite", systemImage: "arrow.triangle.2.circlepath") { rewrite(style: "Rewrite") }
            rewriteChip("Brief", systemImage: nil) { rewrite(style: "Shorter") }
            rewriteChip("Warm", systemImage: nil) { rewrite(style: "Warmer") }
            rewriteChip("Direct", systemImage: nil) { rewrite(style: "Direct") }
            Button {
                dictation.toggle { text in
                    inputVC.textDocumentProxy.insertText(text)
                    keyboardTypedText += text
                }
            } label: {
                Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(dictation.isRecording ? Color.red : Color.keyboardText)
                    .frame(width: 28, height: 26)
                    .background(dictation.isRecording ? Color.red.opacity(0.12) : Color.claritySpecialKey)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Button { pasteClipboard() } label: {
                Image(systemName: "doc.on.clipboard").font(.system(size: 12))
                    .frame(width: 28, height: 26)
                    .background(Color.claritySpecialKey)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    // MARK: - Keyboard
    //
    // Ported from ToneLayer's keyboard (see that project's
    // KeyboardViewController.swift), which was built to match Apple's real
    // iPad/iPhone keyboard exactly: same key positions (Tab, dedicated Caps
    // Lock, the §/± key, a permanently-visible iPad number row), same
    // all-white key coloring, and edge keys (Tab/Caps Lock/Return/Shift)
    // widened to exactly fill each row's leftover width instead of a fixed
    // ratio. Clarity's own action buttons (Rewrite/Brief/Warm/Direct/
    // mic/paste, Light/Medium/Strong) now live in `clarityActionBar` above
    // the keys on every device, rather than iPad-only side panels — that
    // freed the full width for the same real-Apple-layout keys ToneLayer
    // has, with Clarity's own colors/dictation manager underneath.

    /// iPad gets the larger, Apple-iPad-style layout (permanently-visible
    /// number row, Tab, Caps Lock); iPhone keeps the original compact layout.
    private var isIPadLayout: Bool { keyboardWidth >= 600 }

    /// Letter keys are square — measured off Apple's own keyboard. Apple
    /// reaches that size by filling the width with MORE columns, not by
    /// stretching fewer, wider keys.
    private var keySize: CGFloat {
        guard keyboardWidth > 0 else { return 34 }
        guard isIPadLayout else { return (keyboardWidth - 5 * 9) / 10 }
        // The number row is the widest row: "§/±" dual + 12 digit/symbol
        // duals + 1 delete key (1.4x) = 14.4 key-widths, across 13 gaps.
        let widthBased = (keyboardWidth - 13 * 5) / 14.4
        return min(widthBased, 72)
    }

    private var keyHeight: CGFloat { isIPadLayout ? keySize : 48 }
    private var keyAreaWidth: CGFloat { keySize * 10 + 5 * 9 }

    /// Width for the shift/delete keys on the iPhone z-row so that row
    /// totals keyAreaWidth exactly (matches the q-row and a-row above it).
    private var letterEdgeKeyWidth: CGFloat { keySize * 1.5 + 2.5 }

    /// Width for the "#+="/delete keys on the numbers page's bottom row so
    /// that row totals keyAreaWidth exactly.
    private var numberEdgeKeyWidth: CGFloat { keySize * 2.5 + 7.5 }

    /// Key size for the numbers page's top row (1234567890-=), sized so
    /// those 12 keys plus the delete key at the end fill keyAreaWidth.
    private var numberTopKeySize: CGFloat {
        (keyAreaWidth - 12 * 5 - numberEdgeKeyWidth) / 12
    }

    /// The iPad letters page's non-letter edge keys (Tab, Caps Lock, Return,
    /// Shift) are widened to exactly absorb the leftover width those rows
    /// have vs. the number row — the same "solve for the edge key" approach
    /// `numberEdgeKeyWidth`/`numberTopKeySize` use for the numbers page, and
    /// how Apple's own keyboard sizes these keys.
    private var qRowEdgeKeyWidth: CGFloat { keySize * 1.4 }
    private var returnKeyWidth: CGFloat { keySize * 2 + 5 }
    private var zRowShiftWidth: CGFloat { keySize * 1.7 + 2.5 }

    private var keyboardSection: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 0)
            if isIPadLayout && !isNumbers {
                centerKeyRows
            } else {
                centerKeyRows.frame(width: keyboardWidth > 0 ? keyAreaWidth : nil)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { keyboardWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in keyboardWidth = newWidth }
            }
        )
    }

    private var centerKeyRows: some View {
        VStack(spacing: 6) {
            if isNumbers {
                if isIPadLayout {
                    HStack(spacing: 5) {
                        letterRow(isSymbols ? ["[","]","{","}","#","%","^","*","+","=","_","\\"] : ["1","2","3","4","5","6","7","8","9","0","-","="], width: numberTopKeySize)
                        deleteKey(width: numberEdgeKeyWidth)
                    }
                    letterRow(isSymbols ? ["§","|","~","≠","<",">","€","£","¥","·"] : ["-","/",":",";","(",")","$","&","@","\""])
                    HStack(spacing: 5) {
                        modifierKey(
                            isSymbols ? "123" : "#+=", width: numberEdgeKeyWidth,
                            accessibilityLabel: isSymbols ? "Numbers" : "More symbols",
                            accessibilityHint: isSymbols ? "Switches back to numbers." : "Switches to more symbols."
                        ) { isSymbols.toggle(); playKeyClick() }
                        letterRow([".",",","?","!","'"])
                        Color.clear.frame(width: numberEdgeKeyWidth, height: keyHeight)
                    }
                } else {
                    letterRow(isSymbols ? ["[","]","{","}","#","%","^","*","+","="] : ["1","2","3","4","5","6","7","8","9","0"])
                    letterRow(isSymbols ? ["_","\\","|","~","<",">","€","£","¥","•"] : ["-","/",":",";","(",")","$","&","@","\""])
                    HStack(spacing: 5) {
                        modifierKey(
                            isSymbols ? "123" : "#+=", width: numberEdgeKeyWidth,
                            accessibilityLabel: isSymbols ? "Numbers" : "More symbols",
                            accessibilityHint: isSymbols ? "Switches back to numbers." : "Switches to more symbols."
                        ) { isSymbols.toggle(); playKeyClick() }
                        letterRow([".",",","?","!","'"])
                        deleteKey(width: numberEdgeKeyWidth)
                    }
                }
            } else {
                if isIPadLayout {
                    // Apple's iPad keyboard keeps a number row permanently
                    // visible above the letters, and gives Tab/Caps Lock/
                    // §/± their own dedicated keys.
                    compactNumberRow
                    HStack(spacing: 5) {
                        tabKey(width: qRowEdgeKeyWidth)
                        letterRow(["q","w","e","r","t","y","u","i","o","p"])
                        dualCharKey("[", "{", width: keySize)
                        dualCharKey("]", "}", width: keySize)
                        dualCharKey("\\", "|", width: keySize)
                    }
                    HStack(spacing: 5) {
                        capsLockKey(width: qRowEdgeKeyWidth)
                        letterRow(["a","s","d","f","g","h","j","k","l"])
                        dualCharKey(";", ":", width: keySize)
                        dualCharKey("'", "\"", width: keySize)
                        modifierKey(
                            systemImage: "return", width: returnKeyWidth,
                            accessibilityLabel: "Return",
                            accessibilityHint: "Inserts a new line."
                        ) { insertCharacter("\n") }
                    }
                    HStack(spacing: 5) {
                        shiftKey(width: zRowShiftWidth)
                        dualCharKey("`", "~", width: keySize)
                        letterRow(["z","x","c","v","b","n","m"])
                        dualCharKey(",", "<", width: keySize)
                        dualCharKey(".", ">", width: keySize)
                        dualCharKey("/", "?", width: keySize)
                        shiftKey(width: zRowShiftWidth)
                    }
                } else {
                    letterRow(["q","w","e","r","t","y","u","i","o","p"])
                    letterRow(["a","s","d","f","g","h","j","k","l"]).padding(.horizontal, (keySize + 5) / 2)
                    HStack(spacing: 5) {
                        shiftKey(width: letterEdgeKeyWidth)
                        letterRow(["z","x","c","v","b","n","m"])
                        deleteKey(width: letterEdgeKeyWidth)
                    }
                }
            }
            if isIPadLayout {
                // Matches Apple's iPad bottom row: globe, .?123, dictation
                // mic, space, .?123, then the dismiss-keyboard chevron
                // (already offered separately in Clarity's top bar, but
                // Apple's own keyboard puts one here too). Return already
                // lives at the end of the a-row above.
                HStack(spacing: 5) {
                    modifierKey(
                        systemImage: "globe", width: keySize,
                        accessibilityLabel: "Next keyboard",
                        accessibilityHint: "Switches to your other installed keyboards."
                    ) {
                        playKeyClick()
                        inputVC.advanceToNextInputMode()
                    }
                    modeSwitchKey
                    dictationMicKey(width: keySize)
                    spaceKey
                    modeSwitchKey
                    modifierKey(
                        systemImage: "keyboard.chevron.compact.down", width: keySize,
                        accessibilityLabel: "Dismiss keyboard",
                        accessibilityHint: "Hides the keyboard."
                    ) {
                        playKeyClick()
                        inputVC.dismissKeyboard()
                    }
                }
            } else {
                HStack(spacing: 5) {
                    modifierKey(
                        isNumbers ? "ABC" : "123", width: keySize * 1.3,
                        accessibilityLabel: isNumbers ? "Letters" : "Numbers and symbols",
                        accessibilityHint: isNumbers ? "Switches back to the letter keys." : "Switches to numbers and symbols."
                    ) {
                        isNumbers.toggle(); isSymbols = false
                        if !capsLocked { isShifted = false }
                        playKeyClick()
                    }
                    modifierKey(
                        systemImage: "globe", width: keySize,
                        accessibilityLabel: "Next keyboard",
                        accessibilityHint: "Switches to your other installed keyboards."
                    ) {
                        playKeyClick()
                        inputVC.advanceToNextInputMode()
                    }
                    spaceKey
                    modifierKey(".", width: keySize, accessibilityLabel: "Period", accessibilityHint: "Types a period.") { insertCharacter(".") }
                    modifierKey(
                        systemImage: "return", width: keySize * 1.6,
                        accessibilityLabel: "Return",
                        accessibilityHint: "Inserts a new line."
                    ) { insertCharacter("\n") }
                }
            }
        }
    }

    /// The iPad number row: each key doubles as its shifted punctuation
    /// twin, with delete at the end — matching Apple's iPad keyboard, which
    /// keeps this whole row visible above the letters.
    private var compactNumberRow: some View {
        let pairs: [(String, String)] = [
            ("1", "!"), ("2", "@"), ("3", "#"), ("4", "$"), ("5", "%"), ("6", "^"),
            ("7", "&"), ("8", "*"), ("9", "("), ("0", ")"), ("-", "_"), ("=", "+")
        ]
        return HStack(spacing: 5) {
            dualCharKey("§", "±", width: keySize)
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                dualCharKey(pair.0, pair.1, width: keySize)
            }
            deleteKey(width: keySize * 1.4)
        }
    }

    private func letterRow(_ letters: [String], width: CGFloat? = nil) -> some View {
        HStack(spacing: 5) {
            ForEach(letters, id: \.self) { letter in
                letterKey(isShifted && !isNumbers ? letter.uppercased() : letter, id: letter, width: width) {
                    tapLetter(letter)
                }
            }
        }
    }

    private func tapLetter(_ letter: String) {
        let output = isShifted && !isNumbers ? letter.uppercased() : letter
        insertCharacter(output)
        if isShifted && !capsLocked { isShifted = false }
    }

    private func insertCharacter(_ text: String) {
        inputVC.textDocumentProxy.insertText(text)
        keyboardTypedText += text
        playKeyClick()
    }

    private func deleteBackward() {
        inputVC.textDocumentProxy.deleteBackward()
        if !keyboardTypedText.isEmpty { keyboardTypedText.removeLast() }
        playKeyClick()
    }

    private func playKeyClick() {
        UIDevice.current.playInputClick()
    }

    /// `id` tracks the press independently of `title`. Tapping a letter can
    /// itself flip `isShifted` back off mid-gesture (auto-capitalization
    /// turning off after one letter — see `tapLetter`), which re-renders
    /// this same key with a new lowercase `title` *before the finger
    /// lifts*. If `pressedKeyTitle` were tracked by `title`, `onEnded`'s
    /// comparison would then compare the OLD uppercase value against the
    /// NEW lowercase one, never match, and never reset — permanently
    /// jamming that key so it silently stops registering presses for the
    /// rest of the session. `id` defaults to `letter` (case-invariant) at
    /// the call site that passes it, so the identity used for tracking
    /// never changes mid-press even though the visible `title` does.
    private func letterKey(_ title: String, id: String? = nil, width: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        let keyID = id ?? title
        return Text(title).font(.system(size: 18, weight: .regular))
            .frame(width: width ?? keySize, height: keyHeight)
            .foregroundStyle(Color.keyboardText)
            .background(Color.keyboardKey, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .keycapShadow()
            .keyTapTarget()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard pressedKeyTitle != keyID else { return }
                        pressedKeyTitle = keyID
                        action()
                    }
                    .onEnded { _ in if pressedKeyTitle == keyID { pressedKeyTitle = nil } }
            )
            .accessibilityAddTraits(.isButton)
        .overlay(alignment: .top) {
            if pressedKeyTitle == keyID {
                Text(title)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Color.keyboardText)
                    .frame(width: (width ?? keySize) + 14, height: keyHeight + 16)
                    .background(Color.keyboardKey, in: KeyPopupBubble())
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(y: -(keyHeight + 12))
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeOut(duration: 0.08)))
            }
        }
        .accessibilityLabel("\(title) key")
        .accessibilityHint("Types the letter \(title).")
    }

    /// Apple's iPad keyboard keeps every key white, including function
    /// keys — only iPhone's keyboard two-tones them gray.
    private func modifierKey(_ title: String, active: Bool = false, width: CGFloat, accessibilityLabel: String? = nil, accessibilityHint: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .frame(width: width, height: keyHeight)
                .foregroundStyle(Color.keyboardText)
                .background(isIPadLayout || active ? Color.keyboardKey : Color.claritySpecialKey, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .keycapShadow()
                .keyTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(accessibilityHint)
    }

    private func modifierKey(systemImage: String, active: Bool = false, width: CGFloat, accessibilityLabel: String, accessibilityHint: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                .frame(width: width, height: keyHeight)
                .foregroundStyle(Color.keyboardText)
                .background(isIPadLayout || active ? Color.keyboardKey : Color.claritySpecialKey, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .keycapShadow()
                .keyTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// Switches between letters and numbers/symbols — labeled ".?123" to
    /// match Apple's iPad keyboard exactly (iPhone keeps the plain "123").
    private var modeSwitchKey: some View {
        modifierKey(
            isNumbers ? "ABC" : ".?123", width: keySize * 1.3,
            accessibilityLabel: isNumbers ? "Letters" : "Numbers and symbols",
            accessibilityHint: isNumbers ? "Switches back to the letter keys." : "Switches to numbers and symbols."
        ) {
            isNumbers.toggle(); isSymbols = false
            if !capsLocked { isShifted = false }
            playKeyClick()
        }
    }

    /// Apple's hardware-style iPad layout gives Tab its own key at the start
    /// of the q-row, distinct from shift/caps lock.
    private func tabKey(width: CGFloat) -> some View {
        modifierKey(
            systemImage: "arrow.right.to.line",
            width: width,
            accessibilityLabel: "Tab",
            accessibilityHint: "Inserts a tab character."
        ) { insertCharacter("\t") }
    }

    /// Apple's hardware-style iPad layout puts a dedicated Caps Lock key at
    /// the start of the a-row — separate from the two one-shot Shift keys
    /// on the z-row below, which only capitalize the next letter.
    private func capsLockKey(width: CGFloat) -> some View {
        modifierKey(
            systemImage: capsLocked ? "capslock.fill" : "capslock",
            active: capsLocked,
            width: width,
            accessibilityLabel: capsLocked ? "Caps lock, on" : "Caps lock",
            accessibilityHint: "Turns caps lock on or off."
        ) {
            playKeyClick()
            capsLocked.toggle()
            isShifted = capsLocked
        }
    }

    /// Apple's dictation mic slot on the bottom row, filled with Clarity's
    /// own speech-to-text dictation (same toggle used by the top action
    /// bar's mic button).
    private func dictationMicKey(width: CGFloat) -> some View {
        modifierKey(
            systemImage: dictation.isRecording ? "stop.circle.fill" : "mic.fill",
            active: dictation.isRecording,
            width: width,
            accessibilityLabel: dictation.isRecording ? "Stop recording" : "Start voice dictation",
            accessibilityHint: dictation.isRecording ? "Stops listening and types what you said." : "Starts listening and types what you say."
        ) {
            playKeyClick()
            dictation.toggle { text in
                inputVC.textDocumentProxy.insertText(text)
                keyboardTypedText += text
            }
        }
    }

    /// Single tap behaves like Apple's one-shot shift (capitalizes only the
    /// next letter); double-tap also toggles the persistent caps lock, as a
    /// muscle-memory fallback alongside the dedicated `capsLockKey`.
    private func shiftKey(width: CGFloat) -> some View {
        modifierKey(
            systemImage: capsLocked ? "capslock.fill" : (isShifted ? "shift.fill" : "shift"),
            active: capsLocked || isShifted,
            width: width,
            accessibilityLabel: capsLocked ? "Caps lock, on" : (isShifted ? "Shift, on" : "Shift"),
            accessibilityHint: "Tap once to capitalize only the next letter. Tap twice quickly to turn on caps lock."
        ) {
            playKeyClick()
            let now = Date()
            if let last = lastShiftTap, now.timeIntervalSince(last) < 0.35 {
                capsLocked.toggle()
                isShifted = capsLocked
                lastShiftTap = nil
            } else {
                if capsLocked {
                    capsLocked = false
                    isShifted = false
                } else {
                    isShifted.toggle()
                }
                lastShiftTap = now
            }
        }
    }

    /// A physical-keyboard-style punctuation key showing two characters:
    /// tapping types the bottom one (or the top one when shift is on);
    /// long-pressing always types the top one directly.
    private func dualCharKey(_ bottom: String, _ top: String, width: CGFloat, height: CGFloat? = nil) -> some View {
        VStack(spacing: 0) {
            Text(top).font(.system(size: 10, weight: .regular)).opacity(0.55)
            Text(bottom).font(.system(size: 15, weight: .regular))
        }
        .frame(width: width, height: height ?? keyHeight)
        .foregroundStyle(Color.keyboardText)
        .background(Color.keyboardKey, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .keycapShadow()
        .keyTapTarget()
        .onTapGesture {
            let typed = isShifted ? top : bottom
            insertCharacter(typed)
            if isShifted && !capsLocked { isShifted = false }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            insertCharacter(top)
        }
        .accessibilityLabel("\(bottom) key")
        .accessibilityHint("Types \(bottom). Long-press to type \(top) directly.")
        .accessibilityAddTraits(.isButton)
    }

    /// Delete key with Apple's long-press auto-repeat behavior.
    private func deleteKey(width: CGFloat, height: CGFloat? = nil) -> some View {
        Image(systemName: "delete.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.keyboardText)
            .frame(width: width, height: height ?? keyHeight)
            .background(isIPadLayout ? Color.keyboardKey : Color.claritySpecialKey, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .keycapShadow()
            .keyTapTarget()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard deleteTimer == nil else { return }
                        deleteBackward()
                        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { _ in
                            deleteTimer?.invalidate()
                            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
                                deleteBackward()
                            }
                        }
                    }
                    .onEnded { _ in
                        deleteTimer?.invalidate()
                        deleteTimer = nil
                    }
            )
            .accessibilityLabel("Delete")
            .accessibilityHint("Removes the character before the cursor. Press and hold to delete repeatedly.")
            .accessibilityAddTraits(.isButton)
    }

    /// Space bar: tap inserts a space; a horizontal drag moves the cursor,
    /// mirroring Apple's space-bar trackpad gesture. Blank, matching Apple's
    /// iPad keyboard (no "space" text label).
    private var spaceKey: some View {
        Text("").font(.system(size: 13, weight: .regular))
            .frame(maxWidth: .infinity).frame(height: keyHeight)
            .foregroundStyle(Color.keyboardText)
            .background(Color.keyboardKey, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .keycapShadow()
            .keyTapTarget()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.translation.width
                        let step: CGFloat = 8
                        let target = Int((dx - spaceDragAccumulated) / step)
                        if target != 0 {
                            inputVC.textDocumentProxy.adjustTextPosition(byCharacterOffset: target)
                            spaceDragAccumulated += CGFloat(target) * step
                        }
                    }
                    .onEnded { value in
                        if abs(value.translation.width) < 4 {
                            insertCharacter(" ")
                        }
                        spaceDragAccumulated = 0
                    }
            )
            .accessibilityLabel("Space")
            .accessibilityHint("Inserts a space. Drag left or right to move the cursor.")
            .accessibilityAddTraits(.isButton)
    }

    private func rewriteChip(_ title: String, systemImage: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isRewriting && title == "Rewrite" {
                    ProgressView().scaleEffect(0.6).tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 11))
                }
                Text(isRewriting ? "Working" : title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isRewriting ? Color.clarityAccent.opacity(0.55) : Color.keyboardKey)
            .foregroundStyle(title == "Rewrite" ? Color.clarityAccent : Color.keyboardText)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(isRewriting)
    }

    @ViewBuilder
    private func chipButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(primary ? Color.clarityAccent : Color.claritySpecialKey)
                .foregroundStyle(primary ? Color.white : Color.keyboardText)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func levelKeyTitle(_ value: String) -> String {
        switch value {
        case "Light":  return "L"
        case "Medium": return "M"
        case "Strong": return "S"
        default:       return value
        }
    }

    // MARK: - Load settings

    private func loadSettings() {
        profileADHD   = defaults?.bool(forKey: "ndprofile.adhd")   ?? false
        profileAutism = defaults?.bool(forKey: "ndprofile.autism") ?? false
        profilePTSD   = defaults?.bool(forKey: "ndprofile.ptsd")   ?? false
        profileCPTSD  = defaults?.bool(forKey: "ndprofile.cptsd")  ?? false

        // Fallback: parse legacy selectedProfile string
        if !profileADHD && !profileAutism && !profilePTSD && !profileCPTSD {
            let p = defaults?.string(forKey: "selectedProfile") ?? ""
            if p.contains("ADHD")                    { profileADHD   = true }
            if p.contains("Autism") || p.contains("AUT") { profileAutism = true }
            if p.contains("PTSD")                    { profilePTSD   = true }
            if p.contains("CPTSD")                   { profileCPTSD  = true }
        }

        let stored = defaults?.string(forKey: "rewriteLevel") ?? "Medium"
        level = ["Light", "Medium", "Strong"].contains(stored) ? stored : "Medium"
        spiralEnabled = defaults?.object(forKey: "spiralPauseEnabled") == nil
            ? true : (defaults?.bool(forKey: "spiralPauseEnabled") ?? true)
        teachingBody = defaults?.string(forKey: "lastClarityTeachingNote") ?? ""
    }

    // MARK: - Rewrite

    private func incrementMetric(_ key: String, by amount: Int = 1) {
        let fullKey = "metrics.\(key)"
        defaults?.set((defaults?.integer(forKey: fullKey) ?? 0) + amount, forKey: fullKey)
        defaults?.set(Date(), forKey: "metrics.lastUpdated")
    }

    private func rewrite(style: String = "Rewrite") {
        let proxy = inputVC.textDocumentProxy
        defaults?.synchronize()
        let before     = proxy.documentContextBeforeInput ?? ""
        let typedText  = keyboardTypedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cursorText = before.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldUseTypedText = !typedText.isEmpty && (cursorText.isEmpty || keyboardTypedText.hasSuffix(before))
        let full          = shouldUseTypedText ? typedText  : cursorText
        let totalToDelete = shouldUseTypedText ? keyboardTypedText.count : before.count

        guard !full.isEmpty else { showStatus("Type some text first"); return }

        incrementMetric("keyboard.clarity.rewrite.requested")
        incrementMetric("keyboard.clarity.rewrite.style.\(style)")
        showStatus("Sending \(full.count) chars\u{2026}")
        isRewriting = true
        previewText = ""
        previewGrammar = ""
        pendingDeleteCount = 0
        showSpiral = false
        defaults?.set(true, forKey: "keyboardRewriteInProgress")
        defaults?.synchronize()

        Task {
            do {
                let result = try await callServer(text: full, style: style)
                await MainActor.run {
                    isRewriting = false
                    defaults?.set(false, forKey: "keyboardRewriteInProgress")
                    defaults?.synchronize()
                    pendingDeleteCount = totalToDelete
                    previewText = result.rewrite
                    previewGrammar = result.grammarOnly

                    let note = result.explanation.isEmpty ? "Rewritten at \(level) for \(activeProfiles)." : result.explanation
                    teachingBody = note
                    defaults?.set(note, forKey: "lastClarityTeachingNote")
                    incrementMetric("keyboard.clarity.rewrite.success")
                    saveLog(original: full, result: result)

                    if spiralEnabled && result.isSpiraling {
                        withAnimation { showSpiral = true }
                    } else {
                        showStatus(result.redactionNotice ?? "Review the rewrite above \u{2191}")
                    }
                }
            } catch {
                await MainActor.run {
                    incrementMetric("keyboard.clarity.rewrite.failed")
                    isRewriting = false
                    defaults?.set(false, forKey: "keyboardRewriteInProgress")
                    defaults?.synchronize()
                    showStatus(error.localizedDescription)
                }
            }
        }
    }

    private func applyPreview(_ text: String) {
        guard !text.isEmpty else { return }
        let deleteCount = pendingDeleteCount
        defaults?.set(true, forKey: "keyboardRewriteInProgress")
        defaults?.synchronize()
        Task {
            await deleteBackwardChunked(proxy: inputVC.textDocumentProxy, count: deleteCount)
            await insertTextChunked(proxy: inputVC.textDocumentProxy, text: text)
            await MainActor.run {
                keyboardTypedText = text
                defaults?.set(text, forKey: "testBoxFullText")
                defaults?.set(false, forKey: "keyboardRewriteInProgress")
                defaults?.synchronize()
                previewText = ""
                previewGrammar = ""
                pendingDeleteCount = 0
                showSpiral = false
                showStatus("Applied \u{2713}")
            }
        }
    }

    private func pasteClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showStatus("Clipboard is empty")
            return
        }
        keyboardTypedText = text
        inputVC.textDocumentProxy.insertText(text)
        showStatus("Pasted \u{2014} tap Rewrite")
    }

    private func deleteBackwardChunked(proxy: UITextDocumentProxy, count: Int) async {
        let chunkSize = 50
        var remaining = count
        while remaining > 0 {
            let chunk = min(chunkSize, remaining)
            await MainActor.run { for _ in 0..<chunk { proxy.deleteBackward() } }
            remaining -= chunk
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func insertTextChunked(proxy: UITextDocumentProxy, text: String) async {
        let chunkSize = 400
        var index = text.startIndex
        while index < text.endIndex {
            let next  = text.index(index, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[index..<next])
            await MainActor.run { proxy.insertText(chunk) }
            index = next
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private func showStatus(_ msg: String) {
        status = msg
        let readingTime = max(2.5, Double(msg.count) * 0.05)
        DispatchQueue.main.asyncAfter(deadline: .now() + readingTime) {
            if status == msg { status = "" }
        }
    }

    // MARK: - Server API

    struct ClaudeResult {
        let rewrite: String
        let explanation: String
        let distortions: [String]
        let grammarOnly: String
        let redactionNotice: String?
        var isSpiraling: Bool { !distortions.isEmpty }
    }

    private func callServer(text: String, style: String = "Clarify") async throws -> ClaudeResult {
        let mode = "clarity"
        let profile = activeProfiles
        let redactor = PIIRedactor()
        let (redactedText, mapping, flaggedKinds) = redactor.redact(text)
        var req = URLRequest(url: URL(string: serverURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appToken,           forHTTPHeaderField: "x-app-token")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text":    redactedText,
            "profile": profile,
            "level":   level,
            "mode":    mode,
            "style":   style
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw NBError.apiFailed(0) }
        if http.statusCode != 200 {
            if let e = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = e["error"] as? String {
                throw NBError.apiMessage("\(http.statusCode): \(msg.prefix(120))")
            }
            throw NBError.apiFailed(http.statusCode)
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw NBError.badResponse }
        let rewrite: String
        if let cv = parsed["clearer_version"] as? String, !cv.isEmpty {
            rewrite = cv
        } else if let paras = parsed["paragraphs"] as? [String], !paras.isEmpty {
            rewrite = paras.joined(separator: "\n\n")
        } else if let r = parsed["rewrite"] as? String, !r.isEmpty {
            rewrite = r
        } else {
            throw NBError.badResponse
        }
        return ClaudeResult(
            rewrite:     redactor.rehydrate(rewrite, mapping: mapping),
            explanation: redactor.rehydrate(parsed["teaching_explanation"] as? String ?? parsed["explanation"] as? String ?? "", mapping: mapping),
            distortions: parsed["distortions"] as? [String] ?? [],
            grammarOnly: redactor.rehydrate(parsed["grammar_only"] as? String ?? "", mapping: mapping),
            redactionNotice: PIIRedactor.friendlyNotice(for: flaggedKinds)
        )
    }

    // MARK: - Log

    private func saveLog(original: String, result: ClaudeResult) {
        let entry = RewriteEntry(
            id: UUID(), timestamp: Date(),
            profile: activeProfiles, mode: level,
            originalText: original, rewrittenText: result.rewrite,
            explanation: result.explanation,
            distortions: result.distortions, spiraling: result.isSpiraling
        )
        DispatchQueue.global(qos: .background).async { LogStore.shared.append(entry) }
    }
}

// MARK: - Errors

enum NBError: LocalizedError {
    case apiFailed(Int)
    case apiMessage(String)
    case badResponse
    var errorDescription: String? {
        switch self {
        case .apiFailed(let code): return "API failed (HTTP \(code))"
        case .apiMessage(let s):   return s
        case .badResponse:         return "Unexpected API response"
        }
    }
}

// MARK: - Shared log model

struct RewriteEntry: Codable {
    let id: UUID
    let timestamp: Date
    let profile: String
    let mode: String
    let originalText: String
    let rewrittenText: String
    let explanation: String
    let distortions: [String]
    let spiraling: Bool
}

final class LogStore {
    static let shared = LogStore()
    private let appGroupID = "group.com.alden.ndclarity"
    private let fileName   = "rewrite_log.json"

    private var logURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    func load() -> [RewriteEntry] {
        guard let url = logURL,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RewriteEntry].self, from: data)
        else { return [] }
        return entries
    }

    func append(_ entry: RewriteEntry) {
        var entries = load()
        entries.append(entry)
        if entries.count > 500 { entries = Array(entries.suffix(500)) }
        guard let url = logURL, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func topPatterns(limit: Int = 40) -> [(pattern: String, count: Int)] {
        let recent = Array(load().suffix(limit))
        let all = recent.flatMap { $0.distortions }.filter { !$0.isEmpty }
        return Dictionary(grouping: all, by: { $0 })
            .mapValues { $0.count }
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (pattern: $0.key, count: $0.value) }
    }
}
