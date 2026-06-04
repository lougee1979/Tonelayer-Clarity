// Copyright (c) 2026 Alden Lougee. All rights reserved.
// Proprietary and confidential. Unauthorized copying, modification,
// distribution, or derivative use is prohibited.

//
//  ToneLayerClarityApp.swift
//  ToneLayer Clarity
//
//  Created by Alden-Edwin Lougee on 5/3/26.
//

import SwiftUI

@main
struct ToneLayerClarityApp: App {
    var body: some Scene {
        WindowGroup {
            if hasAcceptedClarityAgreement() {
                ContentView()
            } else {
                ClarityAgreementGate()
            }
        }
    }
}
