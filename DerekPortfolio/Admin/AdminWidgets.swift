//
//  AdminWidgets.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  관리자 화면 공용 부품. Flutter lib/admin/admin_widgets.dart 자리.
//

import SwiftUI

/// 여러 줄 입력을 문자열 리스트로 바꾼다. 빈 줄은 버린다.
func linesToList(_ text: String) -> [String] {
    text.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty }
}

func listToLines(_ items: [String]) -> String {
    items.joined(separator: "\n")
}

/// 관리자 화면의 기본 묶음 카드.
struct AdminCard<Trailing: View, Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMd) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    heading.frame(maxWidth: .infinity, alignment: .leading)
                    trailing()
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    trailing()
                }
            }
            content()
        }
        .padding(AppTheme.spacingLg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
        .cardShadow()
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFonts.sans(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppFonts.sans(12.5))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }
}

extension AdminCard where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }
}

/// 라벨이 붙은 텍스트 입력.
struct AdminField: View {
    let label: String
    @Binding var text: String
    var hint: String?
    var required = false
    /// 1 이면 한 줄 입력, 그보다 크면 그만큼의 높이를 가진 여러 줄 입력.
    var lines = 1
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(label)
                    .font(AppFonts.sans(12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                if required {
                    Text(" *")
                        .font(AppFonts.sans(12.5, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                if let hint {
                    Text(hint)
                        .font(AppFonts.sans(11.5))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.leading, 8)
                }
            }

            Group {
                if lines > 1 {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: CGFloat(lines) * 22 + 16)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                }
            }
            .font(AppFonts.sans(14))
            .foregroundStyle(AppTheme.textPrimary)
            .paperCard(fill: AppTheme.surface, radius: AppTheme.radiusSm, stroke: AppTheme.border, lineWidth: 1)
        }
        .padding(.bottom, AppTheme.spacingMd)
    }
}

/// 관리자 화면의 주 동작 버튼.
struct AdminButton: View {
    let label: String
    var icon: String?
    var outlined = false
    var color: Color = AppTheme.primary
    var busy = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        let foreground: Color = outlined ? color : .white
        let active = enabled && !busy

        Button(action: action) {
            HStack(spacing: 8) {
                // 아이콘과 같은 크기라 진행 중으로 바뀌어도 버튼 크기가 그대로다.
                if busy {
                    DerekSpinner(size: 16, color: foreground, strokeWidth: 1.6)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                }
                Text(label).font(AppFonts.sans(13.5, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .paperCard(fill: outlined ? AppTheme.surfaceCard : color, radius: AppTheme.radiusSm, stroke: color)
        }
        .buttonStyle(PressableStyle())
        .disabled(!active)
        .opacity(active ? 1 : 0.5)
    }
}

/// 리스트 항목 하나를 감싸는 박스. 우측 상단에 삭제/이동 버튼을 붙인다.
struct AdminListItem<Actions: View, Content: View>: View {
    let heading: String
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(heading)
                    .font(AppFonts.mono(11.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                actions()
            }
            content()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 2)
        .paperCard(fill: AppTheme.surface, radius: AppTheme.radiusSm, stroke: AppTheme.borderLight)
        .padding(.bottom, AppTheme.spacingMd)
    }
}

/// 작은 아이콘 버튼 (삭제, 위/아래 이동 등).
struct AdminIconButton: View {
    let icon: String
    let label: String
    var color: Color = AppTheme.textMuted
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

/// 진행 표시가 이만큼 이어지면 '느리다' 는 것을 화면에도 적는다.
struct AdminBusyView: View {
    let message: String
    var slow = false

    var body: some View {
        VStack(spacing: 0) {
            DerekSpinner(size: 64)
            Text(message)
                .font(AppFonts.sans(13))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.top, 16)
            if slow {
                Text("응답이 느립니다. 잠시 더 기다려 주세요.")
                    .font(AppFonts.sans(12))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 아이콘 + 안내 문구 자리.
struct AdminPlaceholder: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.textMuted)
            Text(message)
                .font(AppFonts.sans(13))
                .lineHeight(1.7, fontSize: 13)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.spacingLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
