import SwiftUI

private let clarityAppGroupID    = "group.com.alden.ndclarity"
private let clarityAgreementKey  = "clarityBetaAgreementAccepted.v1"

func hasAcceptedClarityAgreement() -> Bool {
    UserDefaults(suiteName: clarityAppGroupID)?.bool(forKey: clarityAgreementKey) ?? false
}

struct ClarityAgreementGate: View {
    @State private var accepted = false
    @State private var showApp  = false

    var body: some View {
        if showApp {
            ContentView()
        } else {
            agreementScreen
        }
    }

    private var agreementScreen: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.878, green: 0.855, blue: 0.988), Color(red: 0.769, green: 0.729, blue: 0.976)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "yin.yang")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(Color(red: 0.435, green: 0.310, blue: 0.745))
                    Text("Clarity").font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 0.300, green: 0.200, blue: 0.600))
                    Text("Beta Testing Agreement").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                }
                .padding(.top, 52).padding(.bottom, 24)

                ScrollView {
                    Text(agreementText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.22))
                        .lineSpacing(5)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
                .frame(maxHeight: 380)
                .background(Color.white.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    Button {
                        accepted.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: accepted ? "checkmark.square.fill" : "square")
                                .font(.system(size: 22))
                                .foregroundStyle(accepted ? Color(red: 0.435, green: 0.310, blue: 0.745) : .secondary)
                                .frame(width: 28)
                            Text("I have read and agree to the Clarity Beta Testing Agreement, including use of the Clarity keyboard extension.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.22))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Button {
                        guard accepted else { return }
                        UserDefaults(suiteName: clarityAppGroupID)?.set(true, forKey: clarityAgreementKey)
                        withAnimation(.easeInOut(duration: 0.3)) { showApp = true }
                    } label: {
                        Text("Enter Clarity")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                accepted
                                    ? Color(red: 0.435, green: 0.310, blue: 0.745)
                                    : Color(red: 0.6, green: 0.6, blue: 0.7)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!accepted)
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private let agreementText = """
Clarity Beta Testing Agreement

Last updated: June 2026

Thank you for testing Clarity. This agreement covers the Clarity app and the Clarity keyboard extension. By accepting and entering the app you agree to the following.

1. YOU OWN WHAT YOU PROCESS
You confirm that you have the right to share and process any text you enter into Clarity or the Clarity keyboard. Do not paste or submit text that belongs to someone else or that you do not have explicit permission to use. Clarity is not responsible for any copyright or intellectual-property claims arising from text you submit.

2. BETA SOFTWARE — NO WARRANTIES
Clarity is beta software. Features may change, crash, or produce unexpected results at any time without notice. Outputs are provided as-is and accuracy is not guaranteed. The developer is not liable for any direct or indirect loss, harm, or misunderstanding resulting from use during the beta period.

3. NOT A SUBSTITUTE FOR PROFESSIONAL HELP
Clarity is a communication aid. It is not a medical device, therapy tool, diagnostic service, or source of legal advice. It does not provide clinical, psychological, or legal guidance. If you need professional support, please speak with a qualified professional.

4. YOUR TEXT IS PROCESSED ON OUR SERVER
Messages you type in the app or keyboard are sent to tonelayer.app for AI processing. Your text is not permanently stored on the server. Do not enter sensitive personal information such as passwords, financial data, or private medical details. By using Clarity you consent to this processing.

5. FEEDBACK
As a beta tester you agree to report bugs, usability issues, and unexpected behavior using the feedback option in the app. Your feedback directly improves the app.

6. CONFIDENTIALITY
Please do not share screenshots or video of beta features publicly without permission from the developer.

7. CHANGES TO THIS AGREEMENT
This agreement may be updated before general release. You will be asked to re-read and accept any material changes.

If you have questions, contact the developer through the app or at the support email provided on the App Store listing.

Thank you for helping make Clarity better.
"""
}
