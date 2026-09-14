//
//  ProjectsEditorView.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  프로젝트 편집. Flutter lib/admin/projects_editor.dart 자리.
//

import SwiftUI

/// 편집 중인 프로젝트 한 건. documentId 가 nil 이면 아직 Firestore 에 저장되지 않은 새 항목이다.
struct ProjectDraft: Identifiable {
    let id = UUID()
    var documentId: String?
    var title = ""
    var company = ""
    var description = ""
    var period = ""
    var role = ""
    var techText = ""
    var achieveText = ""
    var imageUrl = ""
    var githubUrl = ""
    var liveUrl = ""
    var appStoreUrl = ""
    var playStoreUrl = ""
    var category: ProjectCategory = .mobile
    var expanded = false

    init(expanded: Bool = false) {
        self.expanded = expanded
    }

    init(_ p: ProjectData) {
        documentId = p.id
        title = p.title
        company = p.company
        description = p.description
        period = p.period
        role = p.role
        techText = listToLines(p.techStack)
        achieveText = listToLines(p.achievements)
        imageUrl = p.imageUrl ?? ""
        githubUrl = p.githubUrl ?? ""
        liveUrl = p.liveUrl ?? ""
        appStoreUrl = p.appStoreUrl ?? ""
        playStoreUrl = p.playStoreUrl ?? ""
        category = p.category
    }

    private func orNil(_ value: String) -> String? {
        value.trimmed.isEmpty ? nil : value.trimmed
    }

    func model(order: Int) -> ProjectData {
        ProjectData(
            id: documentId,
            title: title.trimmed,
            company: company.trimmed,
            description: description.trimmed,
            period: period.trimmed,
            techStack: linesToList(techText),
            role: role.trimmed,
            achievements: linesToList(achieveText),
            imageUrl: orNil(imageUrl),
            githubUrl: orNil(githubUrl),
            liveUrl: orNil(liveUrl),
            appStoreUrl: orNil(appStoreUrl),
            playStoreUrl: orNil(playStoreUrl),
            category: category,
            order: order
        )
    }
}

@MainActor
final class ProjectsEditorViewModel: NetworkViewModel {
    @Published var drafts: [ProjectDraft]
    @Published private(set) var savingAll = false
    @Published private(set) var savingIds: Set<UUID> = []
    /// 삭제 · 순서 변경 요청이 나가 있는지.
    @Published private(set) var changingList = false

    /// 서버에 쓰는 중인지. 그동안은 목록을 넣고 빼거나 옮기지 못하게 한다.
    ///
    /// 저장은 요청을 보낸 시점의 위치로 순서를 매긴다. 그 사이 목록이 바뀌면 문서 ID 가
    /// 엉뚱한 초안에 붙어 같은 프로젝트가 두 번 만들어지거나, 빈 초안이 기존 문서를 덮어쓴다.
    var isBusy: Bool { savingAll || changingList || !savingIds.isEmpty }

    init(initial: [ProjectData]) {
        drafts = initial.map(ProjectDraft.init)
        super.init()
    }

    func addNew() {
        guard !isBusy else { return }
        drafts.insert(ProjectDraft(expanded: true), at: 0)
    }

    func saveOne(_ id: UUID) async {
        guard !isBusy, let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        let draft = drafts[index]
        guard !draft.title.trimmed.isEmpty else {
            await setToastMessage("프로젝트 제목은 비워 둘 수 없습니다.", type: .error)
            return
        }
        savingIds.insert(id)
        defer { savingIds.remove(id) }
        do {
            let isNew = draft.documentId == nil
            let documentId = try await saveProject(draft.model(order: index))
            if let current = drafts.firstIndex(where: { $0.id == id }) {
                drafts[current].documentId = documentId
            }
            // 새 항목은 그 자리의 순서값을 가져간다. 기존 문서들의 순서를 밀어 두지 않으면
            // 같은 순서값이 둘이 되어 사이트에서 어느 쪽이 먼저 나올지 정해지지 않는다.
            if isNew {
                try await saveProjectOrder(orderedModels)
            }
            await setToastMessage("저장했습니다: \(draft.title)")
        } catch {
            await setToastMessage("저장에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }

    func saveAll() async {
        guard !isBusy else { return }
        guard !drafts.contains(where: { $0.title.trimmed.isEmpty }) else {
            await setToastMessage("제목이 비어 있는 프로젝트가 있습니다.", type: .error)
            return
        }
        savingAll = true
        defer { savingAll = false }
        do {
            // 결과는 위치가 아니라 id 로 찾아 붙인다.
            for id in drafts.map(\.id) {
                guard let index = drafts.firstIndex(where: { $0.id == id }) else { continue }
                let documentId = try await saveProject(drafts[index].model(order: index))
                if let current = drafts.firstIndex(where: { $0.id == id }) {
                    drafts[current].documentId = documentId
                }
            }
            await setToastMessage("\(drafts.count)건을 저장했습니다.")
        } catch {
            await setToastMessage("저장에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }

    func delete(_ id: UUID) async {
        guard !isBusy, let draft = drafts.first(where: { $0.id == id }) else { return }
        changingList = true
        defer { changingList = false }
        do {
            if let documentId = draft.documentId {
                try await deleteProject(id: documentId)
            }
            drafts.removeAll { $0.id == id }
            await setToastMessage("삭제했습니다.")
        } catch {
            await setToastMessage("삭제에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }

    /// 순서를 바꾸고 곧바로 저장한다. 이미 저장된 문서만 반영되고, 새 항목은 저장 시점에 순서가 잡힌다.
    func move(_ id: UUID, by delta: Int) async {
        guard !isBusy, let index = drafts.firstIndex(where: { $0.id == id }) else { return }
        changingList = true
        defer { changingList = false }
        drafts.move(at: index, by: delta)
        do {
            try await saveProjectOrder(orderedModels)
        } catch {
            await setToastMessage("순서 저장에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }

    /// 지금 목록 순서대로 순서값을 매긴 모델.
    private var orderedModels: [ProjectData] {
        drafts.enumerated().map { $1.model(order: $0) }
    }
}

struct ProjectsEditorView: View {
    @StateObject private var viewModel: ProjectsEditorViewModel
    @State private var pendingDelete: ProjectDraft?

    init(initial: [ProjectData]) {
        _viewModel = StateObject(wrappedValue: ProjectsEditorViewModel(initial: initial))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingMd) {
                AdminCard(
                    title: "프로젝트 \(viewModel.drafts.count)건",
                    subtitle: "카드를 눌러 펼치면 내용을 수정할 수 있습니다. 위/아래 화살표로 바꾼 순서는 즉시 저장됩니다."
                ) {
                    HStack(spacing: 8) {
                        AdminButton(label: "새 프로젝트", icon: "plus", outlined: true, enabled: !viewModel.isBusy) {
                            withAnimation { viewModel.addNew() }
                        }
                        AdminButton(label: "전체 저장", icon: "square.and.arrow.down.fill", busy: viewModel.savingAll, enabled: !viewModel.isBusy) {
                            Task { await viewModel.saveAll() }
                        }
                    }
                } content: {
                    EmptyView()
                }
                .padding(.bottom, AppTheme.spacingSm)

                ForEach(Array(viewModel.drafts.enumerated()), id: \.element.id) { index, draft in
                    projectCard(draft, index: index)
                }
            }
            .padding(AppTheme.spacingLg)
            .padding(.bottom, AppTheme.spacing2xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert(
            "프로젝트 삭제",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { draft in
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task { await viewModel.delete(draft.id) }
            }
        } message: { draft in
            Text("\"\(draft.title.isEmpty ? "제목 없음" : draft.title)\" 을(를) 삭제합니다.\n이 작업은 되돌릴 수 없습니다.")
        }
    }

    private func projectCard(_ draft: ProjectDraft, index: Int) -> some View {
        let isNew = draft.documentId == nil

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { toggle(draft.id) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: draft.expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.title.isEmpty ? "(제목 없음)" : draft.title)
                                .font(AppFonts.sans(14.5, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(index + 1). \(draft.category.label)\(draft.company.isEmpty ? "" : " · \(draft.company)")\(isNew ? "  · 저장 안 됨" : "")")
                                .font(AppFonts.mono(11))
                                .foregroundStyle(isNew ? AppTheme.accent : AppTheme.textMuted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                AdminIconButton(icon: "arrow.up", label: "위로", enabled: index > 0 && !viewModel.isBusy) {
                    Task { await viewModel.move(draft.id, by: -1) }
                }
                AdminIconButton(icon: "arrow.down", label: "아래로", enabled: index < viewModel.drafts.count - 1 && !viewModel.isBusy) {
                    Task { await viewModel.move(draft.id, by: 1) }
                }
                AdminIconButton(icon: "trash", label: "삭제", color: AppTheme.accent, enabled: !viewModel.isBusy) {
                    pendingDelete = draft
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 12)

            if draft.expanded, let binding = binding(for: draft.id) {
                Rectangle().fill(AppTheme.borderLight).frame(height: 1)
                VStack(alignment: .leading, spacing: 0) {
                    AdminField(label: "제목", text: binding.title, required: true)
                    AdminField(label: "소속 / 회사", text: binding.company)
                    AdminField(label: "기간", text: binding.period, hint: "예: 2025.10 - 2026.02")
                    AdminField(label: "역할", text: binding.role)
                    categoryField(binding.category)
                    AdminField(label: "설명", text: binding.description, lines: 5)
                    AdminField(label: "기술 스택", text: binding.techText, hint: "한 줄에 하나씩", lines: 8)
                    AdminField(label: "주요 성과", text: binding.achieveText, hint: "한 줄에 하나씩", lines: 8)
                    AdminField(label: "대표 링크 (liveUrl)", text: binding.liveUrl, hint: "비워 두면 버튼이 숨겨집니다", keyboard: .URL)
                    AdminField(label: "App Store URL", text: binding.appStoreUrl, keyboard: .URL)
                    AdminField(label: "Play Store URL", text: binding.playStoreUrl, keyboard: .URL)
                    AdminField(label: "GitHub URL", text: binding.githubUrl, keyboard: .URL)
                    AdminField(label: "이미지 URL", text: binding.imageUrl, keyboard: .URL)
                    HStack {
                        Spacer()
                        AdminButton(label: "이 프로젝트 저장", icon: "square.and.arrow.down.fill", busy: viewModel.savingIds.contains(draft.id), enabled: !viewModel.isBusy) {
                            Task { await viewModel.saveOne(draft.id) }
                        }
                    }
                    .padding(.bottom, AppTheme.spacingMd)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .paperCard(stroke: isNew ? AppTheme.accent : AppTheme.border)
        .cardShadow()
    }

    private func categoryField(_ selection: Binding<ProjectCategory>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("카테고리")
                .font(AppFonts.sans(12.5, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ProjectCategory.allCases, id: \.self) { category in
                    let isSelected = selection.wrappedValue == category
                    Button { selection.wrappedValue = category } label: {
                        Text(category.label)
                            .font(AppFonts.sans(12.5, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(isSelected ? AppTheme.primary : AppTheme.surface))
                            .overlay(Capsule().strokeBorder(isSelected ? AppTheme.primary : AppTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, AppTheme.spacingMd)
    }

    private func toggle(_ id: UUID) {
        guard let index = viewModel.drafts.firstIndex(where: { $0.id == id }) else { return }
        viewModel.drafts[index].expanded.toggle()
    }

    private func binding(for id: UUID) -> Binding<ProjectDraft>? {
        guard viewModel.drafts.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { viewModel.drafts.first(where: { $0.id == id }) ?? ProjectDraft() },
            set: { newValue in
                if let index = viewModel.drafts.firstIndex(where: { $0.id == id }) {
                    viewModel.drafts[index] = newValue
                }
            }
        )
    }
}
