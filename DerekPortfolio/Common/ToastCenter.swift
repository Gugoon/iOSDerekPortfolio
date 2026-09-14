//
//  ToastCenter.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Flutter 의 SnackBar 자리. 한 번에 한 줄만 보이고, 새 알림이 오면 앞의 것을 치운다.
//

import SwiftUI
import Combine

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    @Published private(set) var current: ToastMessage?

    private var dismissal: AnyCancellable?

    func show(_ text: String, type: ToastType = .normal) {
        let toast = ToastMessage(text: text, type: type)
        withAnimation(.easeOut(duration: 0.2)) { current = toast }

        // 오류는 읽을 시간을 더 준다.
        // RunLoop.main 은 기본 모드에서만 돌아 스크롤하는 동안 타이머가 멈춘다. 그래서 큐를 쓴다.
        dismissal = Just(toast.id)
            .delay(for: .seconds(type == .error ? 5 : 2), scheduler: DispatchQueue.main)
            .sink { [weak self] id in
                guard let self, self.current?.id == id else { return }
                withAnimation(.easeIn(duration: 0.2)) { self.current = nil }
            }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = center.current {
                Text(toast.text)
                    .font(AppFonts.sans(13.5, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 420, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.radiusSm)
                            .fill(toast.type == .error ? AppTheme.accent : AppTheme.primary)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
