// Copyright (c) 2026 Alden Lougee. All rights reserved.
// Proprietary and confidential. Unauthorized copying, modification,
// distribution, or derivative use is prohibited.

//
//  ContentView.swift
//  ToneLayer Clarity
//

import SwiftUI
import UIKit

extension Color {
    static let toneLayerBlue     = Color(red: 0.376, green: 0.722, blue: 0.973)
    static let toneLayerBlueSoft = Color(red: 0.859, green: 0.941, blue: 0.996)
    static let clarityGreen      = Color(red: 0.482, green: 0.333, blue: 0.847)
    static let clarityGreenSoft  = Color(red: 0.918, green: 0.898, blue: 0.980)
    static let appNeutral  = Color(red: 0.322, green: 0.322, blue: 0.357)
    static let appSurface  = Color(red: 0.945, green: 0.941, blue: 0.984)
    static let cardSurface = Color.white

    static let brandVioletDark  = clarityGreen
    static let brandViolet      = toneLayerBlue
    static let brandGreen       = clarityGreen
    static let brandWhite       = cardSurface
    static let brandVioletMist  = clarityGreenSoft
    static let brandGreenMist   = toneLayerBlueSoft
}

struct GlassCard: ViewModifier {
    var tint: Color = .brandVioletDark
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard(tint: Color = .brandVioletDark, cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassCard(tint: tint, cornerRadius: cornerRadius))
    }
}

struct ContentView: View {
    @State private var draft = ""
    @State private var profileADHD   = false
    @State private var profileAutism  = false
    @State private var profileAUDHD   = false
    @State private var profilePTSD    = false
    @State private var profileCPTSD   = false
    @State private var goal = "Make clearer"
    @State private var isRewriting = false
    @State private var status = ""
    @State private var clearerVersion = ""
    @State private var interpretationRisk = ""
    @State private var changeNotes = ""
    @State private var learningTakeaway = ""
    @State private var teachingExplanation = ""
    @State private var selectedResult = "Rewrite"
    @State private var showingOptions = false
    @State private var showTeaching = true
    @State private var aiConsent = false
    @State private var exportURL: URL?
    @State private var activityItems: [Any] = []
    @State private var showingExportSheet = false

    // Decoder
    @State private var decodeContactName   = ""
    @State private var decodeText          = ""
    @State private var decodeSensitivity   = "Low"
    @State private var isDecoding          = false
    @State private var decodeTranslation   = ""
    @State private var decodePatterns: [String] = []
    @State private var decodeBaseline      = ""
    @State private var decodeTentative     = false
    @State private var decodeStatus        = ""

    private let serverURL = "https://tonelayer-server-production.up.railway.app/rewrite"
    private let decodeURL = "https://tonelayer-server-production.up.railway.app/decode"
    private let appToken  = "d731136d97cdd46453e7581465537e0d9aee811512b885c2"

    private let showTeachingKey = "ntClarityShowTeaching"
    private let aiConsentKey    = "toneLayerAIProcessingConsent"
    private let appGroupID      = "group.com.alden.ndclarity"
    private var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
    private let goals      = ["Make clearer", "Reduce anxiety", "Make actionable"]
    private let resultTabs = ["Original", "Rewrite", "Tone"]
    private let dailyTips: [(title: String, body: String)] = [
        (
            "A blocked call may not feel neutral",
            "For someone with ADHD, trauma history, or rejection sensitivity, being blocked or repeatedly sent to voicemail can feel like rejection before there is any explanation. A short text like \"I cannot talk now, but I will reply later\" is usually safer."
        ),
        (
            "Hinting creates extra work",
            "Many neurodivergent people communicate better when the request is explicit. Instead of hoping they infer the problem, name what you need, when you need it, and whether it is urgent."
        ),
        (
            "Short can sound angry",
            "A message like \"fine\" or \"whatever\" may land as punishment or shutdown. If you mean reassurance, say it plainly: \"We are okay. I just need a little time.\""
        ),
        (
            "Unclear urgency can trigger panic",
            "Messages like \"call me\" or \"we need to talk\" can create anxiety because the person has to guess the emotional stakes. Add context when you can."
        ),
        (
            "Autistic processing may need precision",
            "Concrete language is often easier than social shorthand. Saying exactly what changed, what you expect, and what is optional reduces confusion."
        ),
        (
            "PTSD can read threat quickly",
            "A nervous system shaped by trauma may detect danger before logic catches up. Calm wording, predictable timing, and clear reassurance can reduce escalation."
        ),
        (
            "Repair beats perfect wording",
            "If your message lands badly, explain your intention without blaming the person for reacting. Repair sounds like: \"I see how that came across. What I meant was...\""
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                dailyTipCard
                composerCard
                teachingCard
                decoderCard
                optionsCard
            }
            .padding()
        }
        .background(Color.appSurface)
        .preferredColorScheme(.light)
        .onAppear {
            showTeaching = true
            if UserDefaults.standard.object(forKey: showTeachingKey) != nil {
                showTeaching = UserDefaults.standard.bool(forKey: showTeachingKey)
            }
            UserDefaults.standard.set(showTeaching, forKey: showTeachingKey)
            aiConsent     = UserDefaults.standard.bool(forKey: aiConsentKey)
            profileADHD   = UserDefaults.standard.bool(forKey: "ndprofile.adhd")
            profileAutism = UserDefaults.standard.bool(forKey: "ndprofile.autism")
            profileAUDHD  = UserDefaults.standard.bool(forKey: "ndprofile.audhd")
            profilePTSD   = UserDefaults.standard.bool(forKey: "ndprofile.ptsd")
            profileCPTSD  = UserDefaults.standard.bool(forKey: "ndprofile.cptsd")
            syncKeyboardSettings()
        }
        .sheet(isPresented: $showingExportSheet) {
            if !activityItems.isEmpty {
                ActivityView(activityItems: activityItems)
            } else if let exportURL {
                ActivityView(activityItems: [exportURL])
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image("ToneLayerLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("ToneLayer Clarity")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.clarityGreen)

            Text("Rewrite NT speech so it lands more clearly for neurodivergent readers.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                statusPill(label: "Mode",      value: "Clarity")
                statusPill(label: "Direction", value: "NT \u{2192} ND")
                statusPill(label: "Server",    value: "\u{2713} railway.app")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard(tint: .clarityGreen, cornerRadius: 18)
    }

    private func statusPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.clarityGreen)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.clarityGreenSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dailyTipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("FYI of the day", systemImage: "sparkle.magnifyingglass")
                .font(.headline)
                .foregroundStyle(Color.brandGreen)

            Text(todayTip.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)

            Text(todayTip.body)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.22, green: 0.26, blue: 0.30))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(tint: .clarityGreen, cornerRadius: 18)
    }

    private var todayTip: (title: String, body: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return dailyTips[(day - 1) % dailyTips.count]
    }

    // Teaching card \u{2014} always visible below the result, never a tab
    // Only hidden when toggled off in Options
    private var teachingCard: some View {
        Group {
            if showTeaching {
                VStack(alignment: .leading, spacing: 14) {
                    Label("How this lands", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(Color.clarityGreen)

                    if hasOutput {
                        if !teachingExplanation.isEmpty {
                            Text(teachingExplanation)
                                .font(.body)
                                .foregroundStyle(Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !interpretationRisk.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("How this may sound:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(interpretationRisk)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !changeNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("What changed:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(changeNotes)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !learningTakeaway.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(Color.clarityGreen)
                                    .font(.subheadline)
                                    .padding(.top, 2)
                                Text(learningTakeaway)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.clarityGreenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    } else {
                        Text("Paste a message above and tap Rewrite to see how it may land for a neurodivergent reader.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.clarityGreenSoft.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.clarityGreen.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Message Check", systemImage: "text.bubble")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !draft.isEmpty {
                    Text("\(draft.count) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Goal", selection: $goal) {
                ForEach(goals, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .topLeading) {
                UIKitTextView(text: $draft)
                    .frame(minHeight: 220, maxHeight: 360)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                if draft.isEmpty {
                    Text("Paste what you were going to say...")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            messageLengthNotice

            HStack(spacing: 10) {
                Button { pasteFromClipboard() } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button { clearDraft() } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(draft.isEmpty)
            }

            Button(action: rewriteMessage) {
                HStack {
                    if isRewriting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isRewriting ? "Tuning\u{2026}" : "Rewrite")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isRewriting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.clarityGreen.opacity(0.45) : Color.clarityGreen)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isRewriting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(resultTabs, id: \.self) { tab in
                    Button { selectedResult = tab } label: {
                        Text(tab)
                            .font(.caption.weight(selectedResult == tab ? .bold : .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedResult == tab ? Color.clarityGreen : Color(.tertiarySystemBackground))
                            .foregroundStyle(selectedResult == tab ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView {
                Text(resultWindowText)
                    .font(.body)
                    .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.18))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 220, maxHeight: 400)
            .background(Color.clarityGreenSoft.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if hasOutput {
                HStack(spacing: 10) {
                    Button { copySelectedResult() } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.clarityGreen)

                    Button { replaceDraftWithResult() } label: {
                        Label("Replace Draft", systemImage: "arrow.uturn.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 10) {
                    Button { recordSatisfaction(helpful: true) } label: {
                        Label("Helpful", systemImage: "hand.thumbsup")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { recordSatisfaction(helpful: false) } label: {
                        Label("Not Yet", systemImage: "hand.thumbsdown")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button { shareSelectedResult() } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.clarityGreen)
            .disabled(!hasOutput)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(tint: .clarityGreen, cornerRadius: 18)
    }

    private var optionsCard: some View {
        DisclosureGroup(isExpanded: $showingOptions) {
            VStack(alignment: .leading, spacing: 18) {

                VStack(alignment: .leading, spacing: 10) {
                    Label("ND Profile", systemImage: "person.2")
                        .font(.headline)
                    Text("Check all that apply. AUDHD = ADHD + Autism combined. Combinations build the AI instructions automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        profileCheckbox("ADHD",   isOn: $profileADHD)
                        profileCheckbox("Autism", isOn: $profileAutism)
                        profileCheckbox("AUDHD",  isOn: $profileAUDHD)
                        profileCheckbox("PTSD",   isOn: $profilePTSD)
                        profileCheckbox("CPTSD",  isOn: $profileCPTSD)
                    }
                    if buildProfileString() != "General ND" {
                        Label("Active: \(buildProfileString())", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.clarityGreen)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Teaching explanations", systemImage: "lightbulb")
                            .font(.headline)
                        Text("Show the teaching card below the rewrite. Turn off only when you want rewrites without explanations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showTeaching)
                        .labelsHidden()
                        .onChange(of: showTeaching) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: showTeachingKey)
                            syncKeyboardSettings()
                        }
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("AI processing consent", systemImage: "lock.shield")
                            .font(.headline)
                        Text("Clarity sends only the message text you choose to clarify to the AI provider for rewriting. Do not include passwords, secrets, or medical record numbers in test messages.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $aiConsent)
                        .labelsHidden()
                        .onChange(of: aiConsent) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: aiConsentKey)
                        }
                }

            }
            .padding(.top, 12)
        } label: {
            HStack {
                Label("Options", systemImage: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.down.circle.fill")
                    .foregroundStyle(Color.clarityGreen)
            }
        }
        .padding(20)
        .glassCard(tint: .appNeutral, cornerRadius: 18)
    }

    private func profileCheckbox(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            syncKeyboardSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn.wrappedValue ? Color.clarityGreen : Color.secondary)
                    .font(.body)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isOn.wrappedValue ? Color.clarityGreenSoft : Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isOn.wrappedValue ? Color.clarityGreen.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var messageLengthNotice: some View {
        let words = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            .split { $0.isWhitespace || $0.isNewline }
            .count
        let chars = draft.count
        return Text("\(chars) chars \u{2022} \(words) words")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var hasOutput: Bool {
        !clearerVersion.isEmpty || !interpretationRisk.isEmpty || !changeNotes.isEmpty
    }

    private var selectedResultText: String {
        switch selectedResult {
        case "Original": return draft
        case "Tone":     return interpretationRisk
        default:         return clearerVersion
        }
    }

    private var resultWindowText: String {
        if selectedResult == "Original" { return draft.isEmpty ? "Your original message will show here." : draft }
        guard hasOutput else { return "Tap Rewrite to see the rewritten version here." }
        let text = selectedResultText
        return text.isEmpty ? "Nothing to show for this tab yet." : text
    }

    private func pasteFromClipboard() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            status = "Clipboard is empty"
            return
        }
        draft = pasted
        status = "Pasted \(pasted.count) characters"
    }

    private func incrementMetric(_ key: String, by amount: Int = 1) {
        let fullKey = "metrics.\(key)"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: fullKey) + amount, forKey: fullKey)
        UserDefaults.standard.set(Date(), forKey: "metrics.lastUpdated")
    }

    private func syncKeyboardSettings() {
        UserDefaults.standard.set(profileADHD,   forKey: "ndprofile.adhd")
        UserDefaults.standard.set(profileAutism, forKey: "ndprofile.autism")
        UserDefaults.standard.set(profileAUDHD,  forKey: "ndprofile.audhd")
        UserDefaults.standard.set(profilePTSD,   forKey: "ndprofile.ptsd")
        UserDefaults.standard.set(profileCPTSD,  forKey: "ndprofile.cptsd")
        sharedDefaults?.set(showTeaching,   forKey: "showExplanation")
        sharedDefaults?.set("Clarity",      forKey: "keyboardMode")
        sharedDefaults?.set(buildProfileString(), forKey: "selectedProfile")
        sharedDefaults?.set(profileADHD,    forKey: "ndprofile.adhd")
        sharedDefaults?.set(profileAutism,  forKey: "ndprofile.autism")
        sharedDefaults?.set(profileAUDHD,   forKey: "ndprofile.audhd")
        sharedDefaults?.set(profilePTSD,    forKey: "ndprofile.ptsd")
        sharedDefaults?.set(profileCPTSD,   forKey: "ndprofile.cptsd")
        sharedDefaults?.synchronize()
    }

    private func buildProfileString() -> String {
        var p: [String] = []
        if profileAUDHD {
            p.append("AUDHD")
        } else {
            if profileADHD   { p.append("ADHD") }
            if profileAutism { p.append("Autism") }
        }
        if profilePTSD   { p.append("PTSD") }
        if profileCPTSD  { p.append("CPTSD") }
        return p.isEmpty ? "General ND" : p.joined(separator: ", ")
    }

    private func buildProfileInstructions() -> String {
        var parts: [String] = []
        if profileAUDHD || (profileADHD && profileAutism) {
            parts.append("AUDHD: combine ADHD and Autism communication traits \u{2014} put priority and next action first, use ultra-literal language, eliminate all social subtext and implied expectations, define every vague phrase (soon, later, we should talk), reduce working-memory load, make urgency and the ask fully explicit.")
        } else {
            if profileADHD {
                parts.append("ADHD: reduce working-memory load, put priority and next action first, make urgency explicit, avoid buried asks and long multi-step wording.")
            }
            if profileAutism {
                parts.append("Autism: make meaning fully literal, remove all social subtext and implied expectations, define every vague phrase (soon, later, we should talk), state the ask directly.")
            }
        }
        if profilePTSD {
            parts.append("PTSD: lower all threat signals, add reassurance where appropriate, avoid vague warnings or power-heavy phrasing, make emotional stakes explicit and calm.")
        }
        if profileCPTSD {
            parts.append("CPTSD: avoid language implying punishment, withdrawal, or conditional approval. Be warm, non-threatening, and explicit about safety and intent. Address fawn and freeze response patterns.")
        }
        return parts.isEmpty
            ? "General ND: remove all ambiguity, make the ask explicit, add necessary context, state urgency, and give a concrete next step."
            : parts.joined(separator: " ")
    }

    private func recordSatisfaction(helpful: Bool) {
        incrementMetric(helpful ? "satisfaction.helpful" : "satisfaction.notHelpful")
        status = helpful ? "Marked helpful" : "Marked for improvement"
    }

    private func clearDraft() {
        draft = ""
        clearerVersion = ""
        interpretationRisk = ""
        changeNotes = ""
        learningTakeaway = ""
        teachingExplanation = ""
        status = ""
    }

    private func copySelectedResult() {
        UIPasteboard.general.string = selectedResultText
        incrementMetric("rewrite.copied")
        incrementMetric("rewrite.accepted")
        status = "Copied \(selectedResult)"
    }

    private func replaceDraftWithResult() {
        draft = clearerVersion
        incrementMetric("rewrite.replacedDraft")
        incrementMetric("rewrite.accepted")
        status = "Draft replaced"
    }

    private func shareSelectedResult() {
        activityItems = [selectedResultText]
        exportURL = nil
        showingExportSheet = true
        status = "Choose where to share"
    }

    private func rewriteMessage() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isRewriting = true
        incrementMetric("rewrite.requested")
        status = "Checking message..."
        selectedResult = "Rewrite"

        Task {
            do {
                let result = try await callServer(text: input)
                await MainActor.run {
                    clearerVersion      = result.clearerVersion
                    interpretationRisk  = result.interpretationRisk
                    changeNotes         = result.changeNotes
                    learningTakeaway    = result.learningTakeaway
                    teachingExplanation = result.teachingExplanation
                    incrementMetric("rewrite.success")
                    isRewriting = false
                    status = "Ready"
                }
            } catch {
                await MainActor.run {
                    incrementMetric("rewrite.failed")
                    isRewriting = false
                    status = error.localizedDescription
                }
            }
        }
    }

    private struct ClarityResult {
        let clearerVersion: String
        let interpretationRisk: String
        let changeNotes: String
        let learningTakeaway: String
        let teachingExplanation: String
    }

    private func callServer(text: String) async throws -> ClarityResult {
        var req = URLRequest(url: URL(string: serverURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appToken,           forHTTPHeaderField: "x-app-token")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text, "profile": buildProfileString(), "level": goal, "mode": "clarity", "style": "Clarify"
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClarityError.apiFailed(0) }
        if http.statusCode != 200 {
            if let e = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = e["error"] as? String { throw ClarityError.apiMessage("\(http.statusCode): \(msg.prefix(120))") }
            throw ClarityError.apiFailed(http.statusCode)
        }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ClarityError.badResponse }
        let clearer: String
        if let cv = parsed["clearer_version"] as? String, !cv.isEmpty { clearer = cv }
        else if let paras = parsed["paragraphs"] as? [String], !paras.isEmpty { clearer = paras.joined(separator: "\n\n") }
        else if let r = parsed["rewrite"] as? String, !r.isEmpty { clearer = r }
        else { throw ClarityError.badResponse }
        return ClarityResult(
            clearerVersion:      clearer,
            interpretationRisk:  parsed["interpretation_risk"]  as? String ?? "",
            changeNotes:         parsed["change_notes"]         as? String ?? "",
            learningTakeaway:    parsed["learning_takeaway"]    as? String ?? "",
            teachingExplanation: parsed["teaching_explanation"] as? String ?? parsed["explanation"] as? String ?? ""
        )
    }

    // MARK: - Decoder

    private var decoderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Decoder", systemImage: "eye.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(red: 0.10, green: 0.36, blue: 0.86))
            Text("Paste a message you received. Clarity reads it \u{2014} what it actually means, and any patterns worth knowing.")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Contact name").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                TextField("Who sent this?", text: $decodeContactName).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            }
            ZStack(alignment: .topLeading) {
                UIKitTextView(text: $decodeText)
                    .frame(minHeight: 120, maxHeight: 260).padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.separator), lineWidth: 0.5))
                if decodeText.isEmpty {
                    Text("Paste message here\u{2026}").foregroundStyle(.tertiary).font(.body)
                        .padding(.horizontal, 14).padding(.vertical, 16).allowsHitTesting(false)
                }
            }
            HStack(spacing: 10) {
                Button { if let c = UIPasteboard.general.string, !c.isEmpty { decodeText = c } } label: {
                    Label("Paste", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                Button { decodeText = ""; decodeTranslation = ""; decodePatterns = []; decodeBaseline = "" } label: {
                    Label("Clear", systemImage: "xmark.circle").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).disabled(decodeText.isEmpty)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Sensitivity").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Picker("Sensitivity", selection: $decodeSensitivity) {
                    ForEach(["Low","Medium","High"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented)
                Text(decodeSensitivity == "Low" ? "Only surfaces clear, strong signals. Recommended."
                     : decodeSensitivity == "Medium" ? "Flags moderate patterns and clear signals."
                     : "Flags subtle patterns. May over-flag.").font(.caption).foregroundStyle(.secondary)
            }
            Button(action: startDecode) {
                HStack {
                    if isDecoding { ProgressView().tint(.white) } else { Image(systemName: "eye") }
                    Text(isDecoding ? "Decoding\u{2026}" : "Decode").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(isDecoding ? Color(red: 0.10, green: 0.36, blue: 0.86).opacity(0.45) : Color(red: 0.10, green: 0.36, blue: 0.86))
                .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }.disabled(isDecoding)
            if !decodeStatus.isEmpty {
                Text(decodeStatus)
                    .font(.subheadline)
                    .foregroundStyle(decodeStatus.contains("…") ? Color.secondary : Color.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(decodeStatus.contains("…") ? Color.clear : Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            if !decodeTranslation.isEmpty { decodeResultsView }
        }
        .padding(20).glassCard(tint: Color(red: 0.10, green: 0.36, blue: 0.86), cornerRadius: 18)
    }

    private var decodeResultsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("What it\u{2019}s saying", systemImage: "message.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color(red: 0.10, green: 0.36, blue: 0.86))
                Text(decodeTranslation).font(.body).foregroundStyle(Color(red: 0.08, green: 0.18, blue: 0.42))
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            if !decodePatterns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Patterns flagged", systemImage: "flag.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color(red: 0.75, green: 0.12, blue: 0.12))
                    ForEach(decodePatterns, id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15)).padding(.top, 2)
                            Text(p).font(.subheadline).foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.18))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !decodeBaseline.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.10, green: 0.36, blue: 0.86)).padding(.top, 2)
                    Text(decodeBaseline).font(.caption).foregroundStyle(Color(red: 0.10, green: 0.36, blue: 0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if decodeTentative {
                Text("Baseline still building \u{2014} read is tentative.").font(.caption).italic().foregroundStyle(.secondary)
            }
        }
        .padding(14).background(Color(red: 0.89, green: 0.93, blue: 1.00))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(red: 0.10, green: 0.36, blue: 0.86).opacity(0.25), lineWidth: 1))
    }

    private func startDecode() {
        if decodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let clip = UIPasteboard.general.string, !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                decodeText = clip
            } else {
                decodeStatus = "Nothing to decode — copy a message first."
                return
            }
        }
        let text = decodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isDecoding = true; decodeStatus = "Decoding\u{2026}"
        decodeTranslation = ""; decodePatterns = []; decodeBaseline = ""
        Task {
            do {
                let result = try await callDecode(text: text)
                await MainActor.run {
                    isDecoding = false; decodeStatus = ""
                    decodeTranslation = result.translation; decodePatterns = result.patterns
                    decodeBaseline = result.baseline; decodeTentative = result.tentative
                    let contact = decodeContactName.trimmingCharacters(in: .whitespacesAndNewlines)
                    ClarityDecodeStore.shared.append(ClarityDecodeEntry(
                        id: UUID(), timestamp: Date(), contact: contact.isEmpty ? "Unknown" : contact,
                        text: text, sensitivity: decodeSensitivity,
                        translation: result.translation, patterns: result.patterns, baseline: result.baseline
                    ))
                }
            } catch {
                await MainActor.run { isDecoding = false; decodeStatus = error.localizedDescription }
            }
        }
    }

    private struct DecodeResult { let translation: String; let patterns: [String]; let baseline: String; let tentative: Bool }

    private func callDecode(text: String) async throws -> DecodeResult {
        let contact = decodeContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let history = ClarityDecodeStore.shared.messages(for: contact)
        var req = URLRequest(url: URL(string: decodeURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(appToken, forHTTPHeaderField: "x-app-token")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text, "contact": contact.isEmpty ? "Unknown" : contact,
            "sensitivity": decodeSensitivity,
            "history": history.suffix(10).map { ["text": $0.text, "patterns": $0.patterns] }
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClarityError.apiFailed(0) }
        if http.statusCode != 200 { throw ClarityError.apiFailed(http.statusCode) }
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ClarityError.badResponse }
        let translation = parsed["translation"] as? String ?? parsed["summary"] as? String ?? parsed["analysis"] as? String ?? ""
        guard !translation.isEmpty else { throw ClarityError.badResponse }
        let patterns = parsed["patterns"] as? [String] ?? []
        let baseline = parsed["baseline"] as? String ?? parsed["note"] as? String ?? ""
        let tentative = parsed["tentative"] as? Bool ?? baseline.lowercased().contains("building")
        return DecodeResult(translation: translation, patterns: patterns, baseline: baseline, tentative: tentative)
    }
}

enum ClarityError: LocalizedError {
    case apiFailed(Int)
    case apiMessage(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .apiFailed(let code):     return "API failed (HTTP \(code))"
        case .apiMessage(let message): return message
        case .badResponse:             return "Unexpected API response"
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct UIKitTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .preferredFont(forTextStyle: .body)
        tv.delegate = context.coordinator
        tv.autocorrectionType = .yes
        tv.autocapitalizationType = .sentences
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tv.text = text
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: UIKitTextView
        init(_ parent: UIKitTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

struct ClarityDecodeEntry: Codable {
    let id: UUID; let timestamp: Date; let contact: String
    let text: String; let sensitivity: String
    let translation: String; let patterns: [String]; let baseline: String
}

final class ClarityDecodeStore {
    static let shared = ClarityDecodeStore()
    private let appGroupID = "group.com.alden.ndclarity"
    private let fileName   = "clarity_decode_log.json"
    private var logURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?.appendingPathComponent(fileName)
    }
    func load() -> [ClarityDecodeEntry] {
        guard let url = logURL, let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ClarityDecodeEntry].self, from: data) else { return [] }
        return entries
    }
    func messages(for contact: String) -> [ClarityDecodeEntry] {
        guard !contact.isEmpty else { return [] }
        return load().filter { $0.contact.lowercased() == contact.lowercased() }
    }
    func append(_ entry: ClarityDecodeEntry) {
        var entries = load(); entries.append(entry)
        if entries.count > 500 { entries = Array(entries.suffix(500)) }
        guard let url = logURL, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

#Preview {
    ContentView()
}
