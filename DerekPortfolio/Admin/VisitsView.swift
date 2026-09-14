//
//  VisitsView.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  관리자 화면의 '방문 기록' 탭. Flutter lib/admin/visits_view.dart 자리.
//
//  방문자가 남긴 visits 문서를 최근 순으로 보여 준다. 쓰기는 방문자 기기가 하고
//  (VisitLogger), 여기서는 읽기와 정리만 한다.
//

import SwiftUI

@MainActor
final class VisitsViewModel: NetworkViewModel {
    /// 한 번에 읽어올 최대 건수. 최근 흐름을 훑는 화면이라 넉넉히 한 번만 읽는다.
    static let loadLimit = 300
    /// 기록 정리에서 '오래된 기록' 으로 치는 기준(일).
    static let retentionDays = 90

    @Published private(set) var records: [VisitRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var cleaning = false

    var todayCount: Int {
        records.filter { $0.at.map(Calendar.current.isDateInToday) ?? false }.count
    }

    var uniqueIps: Int { records.map(\.ip).filter { !$0.isEmpty }.uniques.count }
    var countries: Int { records.map(\.country).filter { !$0.isEmpty }.uniques.count }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            records = try await loadRecentVisits(limit: Self.loadLimit)
        } catch {
            records = []
            self.error = error.localizedDescription
        }
    }

    /// days 가 0 이면 전부 지운다.
    ///
    /// 전체 삭제가 따로 있는 이유: visits 는 로그인 없이 create 가 열려 있어서, 누가 가짜
    /// 기록을 밀어 넣으면 그 문서들은 방금 찍힌 시각을 달고 있다. 오래된 것만 지우는
    /// 수단뿐이면 90일을 기다려야 치울 수 있다.
    func cleanUp(days: Int) async {
        cleaning = true
        defer { cleaning = false }
        do {
            let result = try await deleteVisits(olderThan: TimeInterval(days) * 86_400)
            await setToastMessage(
                result.hasMore
                    ? "\(result.deleted)건을 지웠습니다. 아직 남아 있으니 한 번 더 눌러 주세요."
                    : "\(result.deleted)건을 지웠습니다."
            )
            await load()
        } catch {
            await setToastMessage("기록을 지우지 못했습니다: \(error.localizedDescription)", type: .error)
        }
    }
}

struct VisitsView: View {
    @StateObject private var viewModel = VisitsViewModel()
    @State private var confirmCleanUp = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(AppTheme.border).frame(height: 1)
            content
        }
        .task { await viewModel.load() }
        .confirmationDialog("방문 기록 정리", isPresented: $confirmCleanUp, titleVisibility: .visible) {
            Button("\(VisitsViewModel.retentionDays)일 이전 기록만 지우기") {
                Task { await viewModel.cleanUp(days: VisitsViewModel.retentionDays) }
            }
            Button("전체 삭제", role: .destructive) {
                Task { await viewModel.cleanUp(days: 0) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(VisitsViewModel.retentionDays)일 이전 · 오래된 기록만 지웁니다.\n전체 삭제 · 지금까지 쌓인 방문 기록을 모두 지웁니다.\n\n어느 쪽이든 되돌릴 수 없습니다.")
        }
    }

    /// 상단 요약 + 동작 버튼. 좁은 화면에서는 위아래로 나뉜다.
    private var toolbar: some View {
        let busy = viewModel.isLoading || viewModel.cleaning

        return FlowLayout(spacing: AppTheme.spacingLg, lineSpacing: 12) {
            HStack(spacing: AppTheme.spacingLg) {
                stat("불러온 기록", viewModel.records.count)
                stat("오늘", viewModel.todayCount)
                stat("고유 IP", viewModel.uniqueIps)
                stat("국가", viewModel.countries)
            }
            HStack(spacing: 8) {
                AdminButton(label: "새로고침", icon: "arrow.clockwise", outlined: true, enabled: !busy) {
                    Task { await viewModel.load() }
                }
                AdminButton(label: "기록 정리", icon: "trash", outlined: true, color: AppTheme.accent, enabled: !busy) {
                    confirmCleanUp = true
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingLg)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(AppFonts.sans(11.5)).foregroundStyle(AppTheme.textMuted)
            Text("\(value)").font(AppFonts.mono(16, weight: .bold)).foregroundStyle(AppTheme.textPrimary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading || viewModel.cleaning {
            DerekSpinner(size: 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            AdminPlaceholder(icon: "exclamationmark.circle", message: "방문 기록을 불러오지 못했습니다.\n\(error)")
        } else if viewModel.records.isEmpty {
            AdminPlaceholder(
                icon: "globe.asia.australia",
                message: "아직 남은 방문 기록이 없습니다.\n사이트나 앱을 다른 기기에서 열면 한 줄이 쌓입니다.\n(관리자로 로그인한 상태의 접속은 기록하지 않습니다.)"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.records) { record in
                        VisitTile(record: record)
                    }
                }
                .padding(AppTheme.spacingLg)
            }
            .refreshable { await viewModel.load() }
        }
    }
}

/// 방문 한 줄.
private struct VisitTile: View {
    let record: VisitRecord

    var body: some View {
        let location = record.location
        let detail = [record.org, record.timezone].filter { !$0.isEmpty }

        AdminListItem(heading: formatTime(record.at)) {
            // 포트폴리오('/')가 대부분이라 그건 굳이 표시하지 않는다.
            if !record.path.isEmpty && record.path != "/" {
                PaperBadge(
                    text: record.path,
                    font: AppFonts.mono(11),
                    fill: AppTheme.surfaceHover,
                    horizontal: 8,
                    vertical: 3
                )
            }
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Text(record.ip.isEmpty ? "IP 확인 실패" : record.ip)
                    .font(AppFonts.mono(14, weight: .semibold))
                    .foregroundStyle(record.ip.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary)
                    .textSelection(.enabled)
                Text(location.isEmpty ? "위치를 확인하지 못했습니다." : location)
                    .font(AppFonts.sans(13.5))
                    .foregroundStyle(location.isEmpty ? AppTheme.textMuted : AppTheme.textSecondary)
                    .padding(.top, 4)
                if !detail.isEmpty {
                    Text(detail.joined(separator: " · "))
                        .font(AppFonts.sans(12))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.top, 2)
                }
                Text(["유입 \(record.source)", describeUserAgent(record.userAgent)].filter { !$0.isEmpty }.joined(separator: "  ·  "))
                    .font(AppFonts.sans(12))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// '2026-09-10 14:22' 형태.
    private func formatTime(_ date: Date?) -> String {
        guard let date else { return "시각 미확인" }
        return date.toString(format: "yyyy-MM-dd HH:mm")
    }
}
