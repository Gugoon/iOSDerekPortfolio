//
//  DerekPortfolioApp.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Mobile & Full-Stack Portfolio (iOS 네이티브).
//  Flutter 웹 포트폴리오와 같은 Firestore 콘텐츠를 REST 로 읽고 쓴다.
//

import SwiftUI

@main
struct DerekPortfolioApp: App {
    var body: some Scene {
        WindowGroup {
            PortfolioView()
                .preferredColorScheme(.light)
                .tint(AppTheme.primary)
                // 방문 기록은 화면을 띄운 뒤에 조용히 남긴다. IP 조회가 끼어 있어 몇백 ms 가
                // 걸릴 수 있는데, 그걸 기다리느라 첫 화면이 늦어질 이유는 없다.
                .task { await VisitLogger.shared.recordVisit() }
        }
    }
}
