// Copyright (c) 2026 Alden Lougee. All rights reserved.
// Proprietary and confidential. Unauthorized copying, modification,
// distribution, or derivative use is prohibited.

import UIKit
import SwiftUI

// MARK: - Colors

extension Color {
    static let clarityAccent     = Color(red: 0.435, green: 0.310, blue: 0.745)
    static let clarityBackground = Color(red: 0.89,  green: 0.85,  blue: 0.99)
    static let claritySpecialKey = Color(UIColor.systemGray4)
    static let keyboardKey       = Color.white
    static let keyboardText      = Color(red: 0.08, green: 0.10, blue: 0.12)
}

// MARK: - Principal class

class KeyboardViewController: UIInputViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
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
        [top, bot].forEach  { $0.priority = .defaultHigh }
        [lead, trail].forEach { $0.priority = .required }
        NSLayoutConstraint.activate([top, bot, lead, trail])
    }
}

// MARK: - SwiftUI keyboard view

struct KeyboardView: View {
    let inputVC: UIInputViewController

    private let appGroupID = "group.com.alden.ndclarity"
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private let serverURL = "https://tonelayer.app/rewrite"
    private let appToken  = "d731136d97cdd46453e7581465537e0d9aee811512b885c2"

    @State private var profileADHD   = false
    @State private var profileAutism  = false
    @State private var profilePTSD    = false
    @State private var profileCPTSD   = false
    @State private var level              = "Medium"
    @State private var isRewriting        = false
    @State private var status             = ""
    @State private var explanation        = ""
    @State private var showExpl           = true
    @State private var spiralEnabled      = true
    @State private var isShifted          = false
    @State private var isNumbers          = false
    @State private var keyboardTypedText  = ""
    @State private var previewText        = ""
    @State private var pendingDeleteCount = 0

    // Spiral state
    @State private var showSpiral          = false
    @State private var spiralNT            = ""
    @State private var spiralGrammar       = ""
    @State private var spiralOriginal      = ""
    @State private var spiralOriginalCount = 0

    private var activeProfiles: String {
        var p: [String] = []
        if profileADHD   { p.append("ADHD") }
        if profileAutism { p.append("AUT") }
        if profilePTSD   { p.append("PTSD") }
        if profileCPTSD  { p.append("CPTSD") }
        return p.isEmpty ? "General ND" : p.joined(separator: "+")
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            mainPanel
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "yin.yang")
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
            HStack(spacing: 2) {
                Button { inputVC.advanceToNextInputMode() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                Button { inputVC.dismissKeyboard() } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Main panel

    private var mainPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(["Light", "Medium", "Strong"], id: \.self) { l in
                    Button {
                        level = l
                        defaults?.set(l, forKey: "rewriteLevel")
                    } label: {
                        Text(levelKeyTitle(l))
                            .font(.system(size: 14, weight: level == l ? .bold : .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(level == l ? Color.clarityAccent : Color.claritySpecialKey)
                            .foregroundStyle(level == l ? Color.white : Color.keyboardText)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(l) rewrite level")
                }
            }
            .padding(.horizontal, 8)

            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            rewriteWindow
                .padding(.horizontal, 6)

            rewriteActionRow
                .padding(.horizontal, 4)

            qwertyKeyboard
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Action row

    private var rewriteActionRow: some View {
        HStack(spacing: 5) {
            rewriteChip("Rewrite", systemImage: "sparkles") { rewrite(style: "Rewrite") }
            rewriteChip("Brief",   systemImage: nil)         { rewrite(style: "Shorter") }
            rewriteChip("Soften",  systemImage: nil)         { rewrite(style: "Warmer") }
            rewriteChip("Direct",  systemImage: nil)         { rewrite(style: "Direct") }
            rewriteChip("Paste",   systemImage: "doc.on.clipboard") { pasteClipboard() }
        }
    }

    // MARK: - Preview window

    private var rewriteWindow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.clarityAccent)
                Text("Clarity preview")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.keyboardText)
                Spacer()
                if !previewText.isEmpty {
                    Button {
                        previewText = ""
                        pendingDeleteCount = 0
                        showSpiral = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.keyboardText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                if showSpiral {
                    Text("This may land differently than intended \u{2014} choose a version:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        chipButton("Keep original", primary: false) {
                            previewText = ""
                            pendingDeleteCount = 0
                            showSpiral = false
                        }
                        chipButton("Grammar only", primary: false) {
                            previewText = spiralGrammar.isEmpty ? spiralOriginal : spiralGrammar
                            showSpiral = false
                        }
                        chipButton("ND version", primary: true) {
                            previewText = spiralNT
                            showSpiral = false
                        }
                    }
                } else {
                    if showExpl && !explanation.isEmpty {
                        Text(explanation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Button(action: applyPreview) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Insert").fontWeight(.semibold)
                        }
                        .font(.system(size: 13))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.clarityAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("NT \u{2192} ND: make your message explicit and easy to parse.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.clarityAccent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Keyboard

    private var qwertyKeyboard: some View {
        VStack(spacing: 6) {
            if isNumbers {
                keyRow(["1","2","3","4","5","6","7","8","9","0"])
                keyRow(["-","/",":",";","(",")","$","&","@","\""])
                HStack(spacing: 5) {
                    specialKey("ABC", width: 52) { isNumbers = false }
                    keyRow([".",",","?","!","'"], flexible: true)
                    specialKey("\u{232b}", width: 52) {
                        inputVC.textDocumentProxy.deleteBackward()
                        if !keyboardTypedText.isEmpty { keyboardTypedText.removeLast() }
                    }
                }
            } else {
                keyRow(["q","w","e","r","t","y","u","i","o","p"])
                keyRow(["a","s","d","f","g","h","j","k","l"]).padding(.horizontal, 18)
                HStack(spacing: 5) {
                    specialKey(isShifted ? "\u{21e7}" : "\u{21e7}", width: 44, highlighted: isShifted) { isShifted.toggle() }
                    keyRow(["z","x","c","v","b","n","m"], flexible: true)
                    specialKey("\u{232b}", width: 44) {
                        inputVC.textDocumentProxy.deleteBackward()
                        if !keyboardTypedText.isEmpty { keyboardTypedText.removeLast() }
                    }
                }
            }
            HStack(spacing: 5) {
                specialKey(isNumbers ? "ABC" : "123", width: 50) { isNumbers.toggle() }
                specialKey("\u{1f310}", width: 44) { inputVC.advanceToNextInputMode() }
                Button {
                    inputVC.textDocumentProxy.insertText(" ")
                    keyboardTypedText += " "
                } label: {
                    Text("space")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.keyboardKey)
                        .foregroundStyle(Color.keyboardText)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .shadow(color: Color.black.opacity(0.30), radius: 0, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                specialKey("return", width: 72) {
                    inputVC.textDocumentProxy.insertText("\n")
                    keyboardTypedText += "\n"
                }
            }
        }
    }

    private func keyRow(_ keys: [String], flexible: Bool = false) -> some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                letterKey(key).if(flexible) { $0.frame(maxWidth: .infinity) }
            }
        }
    }

    private func letterKey(_ key: String) -> some View {
        Button {
            let output = isShifted ? key.uppercased() : key
            inputVC.textDocumentProxy.insertText(output)
            keyboardTypedText += output
            if isShifted { isShifted = false }
        } label: {
            Text(isShifted ? key.uppercased() : key)
                .font(.system(size: 22))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.keyboardKey)
                .foregroundStyle(Color.keyboardText)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: Color.black.opacity(0.30), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func specialKey(_ title: String, width: CGFloat, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: width, height: 44)
                .background(highlighted ? Color.clarityAccent : Color.claritySpecialKey)
                .foregroundStyle(highlighted ? Color.white : Color.keyboardText)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 0, x: 0, y: 1)
        }
        .buttonStyle(.plain)
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
        showExpl = defaults?.object(forKey: "showExplanation") == nil
            ? true : (defaults?.bool(forKey: "showExplanation") ?? true)
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
        let shouldUseTypedText = !typedText.isEmpty && (cursorText.isEmpty || before.hasSuffix(keyboardTypedText))
        let full          = shouldUseTypedText ? typedText  : cursorText
        let totalToDelete = shouldUseTypedText ? keyboardTypedText.count : before.count

        guard !full.isEmpty else { showStatus("Type some text first"); return }

        incrementMetric("keyboard.clarity.rewrite.requested")
        incrementMetric("keyboard.clarity.rewrite.style.\(style)")
        showStatus("Sending \(full.count) chars\u{2026}")
        isRewriting = true
        previewText = ""
        pendingDeleteCount = 0
        explanation = ""
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

                    if spiralEnabled && result.isSpiraling {
                        spiralNT            = result.rewrite
                        spiralGrammar       = result.grammarOnly
                        spiralOriginal      = full
                        spiralOriginalCount = totalToDelete
                        withAnimation { showSpiral = true }
                    } else {
                        if showExpl && !result.explanation.isEmpty { explanation = result.explanation }
                        incrementMetric("keyboard.clarity.rewrite.success")
                        showStatus("Review and tap Insert")
                        saveLog(original: full, result: result)
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

    private func applyPreview() {
        guard !previewText.isEmpty else { return }
        let text = previewText
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { status = "" }
    }

    // MARK: - Server API

    struct ClaudeResult {
        let rewrite: String
        let explanation: String
        let distortions: [String]
        let grammarOnly: String
        var isSpiraling: Bool { !distortions.isEmpty }
    }

    private func callServer(text: String, style: String = "Clarify") async throws -> ClaudeResult {
        let mode = "clarity"
        let profile = activeProfiles
        var req = URLRequest(url: URL(string: serverURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appToken,           forHTTPHeaderField: "x-app-token")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text":    text,
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
            rewrite:     rewrite,
            explanation: parsed["teaching_explanation"] as? String ?? parsed["explanation"] as? String ?? "",
            distortions: parsed["distortions"] as? [String] ?? [],
            grammarOnly: parsed["grammar_only"] as? String ?? ""
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

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
