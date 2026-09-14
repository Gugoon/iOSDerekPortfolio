//
//  CareerProjectsSheet.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  경력 이력 요약에서 회사를 고르면 그 회사에서 한 프로젝트를 모아 보여 주는 시트.
//  Flutter lib/widgets/career_projects_dialog.dart 자리.
//
//  카드는 프로젝트 아카이브와 같은 PaperProjectSheet 를 쓴다. 다만 여기서는 상세
//  실무 내역을 펼친 채로 연다 - 회사를 눌러 들어온 사람은 그걸 보러 온 것이다.
//

import SwiftUI

/// career 회사에서 진행한 프로젝트를 목록 순서 그대로 골라낸다.
///
/// 회사명은 자유 입력이라 표기가 어긋나 있다(경력 '디타임 (inssait)', 프로젝트 '디타임').
/// 그래서 괄호 부연과 공백을 걷어낸 뒤 비교한다. 부분 일치는 오탐만 만들어 허용하지 않는다.
/// 못 찾으면 시트가 비는 데서 그치지만, 잘못 붙으면 하지 않은 일을 한 것처럼 보여 준다.
func projectsForCareer(_ career: CareerHistory, _ projects: [ProjectData]) -> [ProjectData] {
    let key = companyKey(career.company)
    if key.isEmpty { return [] }
    return projects.filter { companyKey($0.company) == key }
}

private func companyKey(_ company: String) -> String {
    company
        .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        .lowercased()
}

struct CareerProjectsSheet: View {
    let career: CareerHistory
    let projects: [ProjectData]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutWidth) private var width

    private var isCompact: Bool { width < 640 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.border)
            ZStack {
                AppTheme.background.ignoresSafeArea()
                if projects.isEmpty {
                    emptyNotice
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(projects, id: \.listKey) { project in
                                PaperProjectSheet(project: project, initiallyExpanded: true, showCompany: false)
                            }
                        }
                        .frame(maxWidth: 780)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, isCompact ? 16 : 24)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(AppTheme.surface)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                FlowLayout(spacing: 8, lineSpacing: 6) {
                    Text(career.company)
                        .font(AppFonts.serif(isCompact ? 18 : 21))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !career.duration.trimmed.isEmpty {
                        PaperBadge(text: career.duration)
                    }
                }
                Text([career.period, career.role].filter { !$0.trimmed.isEmpty }.joined(separator: "  ·  "))
                    .font(AppFonts.sans(12.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 6)
                Text("프로젝트 \(projects.count)건")
                    .font(AppFonts.mono(11.5, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("닫기")
        }
        .padding(.leading, isCompact ? 16 : 24)
        .padding(.trailing, 12)
        .padding(.vertical, 18)
    }

    /// 회사는 눌렀는데 걸린 프로젝트가 없는 경우. 관리자 화면에서 회사명이 바뀌면 나온다.
    private var emptyNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.minus")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.textMuted)
            Text("등록된 프로젝트가 없습니다.")
                .font(AppFonts.sans(13))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 48)
    }
}
