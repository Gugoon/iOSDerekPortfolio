//
//  ResumePDFBuilder.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  포트폴리오 콘텐츠(SiteContent)를 A4 이력서 PDF 로 조판한다.
//  Flutter lib/services/resume_pdf.dart 자리.
//
//  화면용 카드 레이아웃을 그대로 옮기지 않고 인쇄물 관례(좌측 라벨 / 우측 본문,
//  얇은 구분선, 넉넉한 행간)에 맞춰 다시 짰다. 내용은 Firestore 에서 내려온 값 그대로다.
//

import UIKit

// MARK: - 캐시

/// 마지막으로 만든 문서. 같은 콘텐츠면 조판을 반복하지 않는다.
actor ResumePDFService {
    static let shared = ResumePDFService()

    private var cachedContent: SiteContent?
    private var cachedTask: Task<Data, Error>?

    func pdf(for content: SiteContent) async throws -> Data {
        if let cachedTask, cachedContent == content {
            return try await cachedTask.value
        }
        let task = Task.detached(priority: .userInitiated) {
            try ResumePDFBuilder(content: content).render()
        }
        cachedContent = content
        cachedTask = task

        do {
            return try await task.value
        } catch {
            // 실패한 결과를 남겨 두면 다시 열어도 같은 실패만 돌아온다.
            if cachedContent == content {
                cachedContent = nil
                cachedTask = nil
            }
            throw error
        }
    }

    /// 미리보기를 열기 전에 미리 조판해 둔다. 실패는 삼킨다 — 실제로 열 때 다시 시도한다.
    nonisolated func warmUp(_ content: SiteContent) {
        Task(priority: .utility) { _ = try? await self.pdf(for: content) }
    }
}

// MARK: - 조판

struct ResumePDFBuilder {
    let content: SiteContent

    // 사이트 테마와 같은 잉크 색.
    private static let ink = UIColor(argb: 0xFF1E1C1A)
    private static let inkSoft = UIColor(argb: 0xFF48443F)
    private static let inkMuted = UIColor(argb: 0xFF868077)
    private static let primary = UIColor(argb: 0xFF1F3A60)
    private static let rule = UIColor(argb: 0xFFD9D3C7)
    private static let ruleLight = UIColor(argb: 0xFFEFEAE1)
    private static let chipBg = UIColor(argb: 0xFFF3F0E9)

    /// 본문 좌측 라벨 열의 폭. 섹션마다 어긋나면 시선이 튀므로 공유한다.
    private static let labelWidth: CGFloat = 104
    /// 기술 분류명은 '하드웨어 통신 & 솔루션 공통'처럼 길어 조금 더 넉넉히 준다.
    private static let skillLabelWidth: CGFloat = 146
    private static let labelGutter: CGFloat = 12

    private let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private let margin = UIEdgeInsets(top: 40, left: 42, bottom: 40, right: 42)
    private let footerHeight: CGFloat = 24

    private var contentWidth: CGFloat { page.width - margin.left - margin.right }
    private var bodyTop: CGFloat { margin.top }
    private var bodyBottom: CGFloat { page.height - margin.bottom - footerHeight }

    // MARK: 조각

    /// 세로로 쌓이는 한 조각. draw 는 조각의 왼쪽 위 y 를 받는다.
    private struct Atom {
        let height: CGFloat
        let draw: (CGFloat) -> Void
    }

    /// 한 페이지에 함께 두고 싶은 조각 묶음.
    private struct Group {
        var atoms: [Atom]
        var keepTogether: Bool
        var height: CGFloat { atoms.reduce(0) { $0 + $1.height } }
    }

    func render() throws -> Data {
        let profile = content.profile
        let groups = buildGroups(profile: profile, projects: sortedProjects())
        let pages = paginate(groups)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(profile.name) 이력서",
            kCGPDFContextAuthor as String: profile.name,
            kCGPDFContextSubject as String: profile.title,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        return renderer.pdfData { context in
            for (index, placed) in pages.enumerated() {
                context.beginPage()
                for (atom, y) in placed { atom.draw(y) }
                drawFooter(pageNumber: index + 1, pageCount: pages.count, profile: profile)
            }
        }
    }

    /// 묶음을 페이지에 나눠 담는다.
    ///
    /// 먼저 묶음을 통째로 옮기고, 한 묶음이 한 페이지보다 크면 그때만 조각 단위로 쪼갠다.
    /// 프로젝트 제목만 페이지 끝에 덩그러니 남는 일을 막기 위해서다.
    private func paginate(_ groups: [Group]) -> [[(Atom, CGFloat)]] {
        var pages: [[(Atom, CGFloat)]] = [[]]
        var y = bodyTop
        let pageHeight = bodyBottom - bodyTop

        func newPage() {
            pages.append([])
            y = bodyTop
        }
        func place(_ atom: Atom) {
            pages[pages.count - 1].append((atom, y))
            y += atom.height
        }

        for group in groups {
            if group.keepTogether, group.height <= pageHeight {
                if y + group.height > bodyBottom, y > bodyTop { newPage() }
                group.atoms.forEach(place)
            } else {
                for atom in group.atoms {
                    if y + atom.height > bodyBottom, y > bodyTop { newPage() }
                    place(atom)
                }
            }
        }
        return pages
    }

    /// 사이트 목록과 같은 순서(order 오름차순, 동률이면 원래 순서).
    private func sortedProjects() -> [ProjectData] {
        content.projects.enumerated()
            .sorted { $0.element.order != $1.element.order ? $0.element.order < $1.element.order : $0.offset < $1.offset }
            .map(\.element)
    }

    private func buildGroups(profile: ProfileData, projects: [ProjectData]) -> [Group] {
        var groups: [Group] = [Group(atoms: [headerAtom(profile)], keepTogether: true)]

        // 섹션 제목은 첫 조각과 묶어 페이지 끝에 홀로 남지 않게 한다.
        func section(_ title: String, _ atoms: [Atom], groupEach: Bool = false) {
            guard let first = atoms.first else { return }
            groups.append(Group(atoms: [sectionTitle(title), first], keepTogether: true))
            for atom in atoms.dropFirst() {
                groups.append(Group(atoms: [atom], keepTogether: groupEach))
            }
        }

        if !profile.bio.trimmed.isEmpty {
            section("소개", bioParagraphs(profile.bio))
        }
        if !profile.careers.isEmpty {
            section("경력 사항", profile.careers.map(careerRow))
        }

        let direct = profile.directSkillGroups.filter { !$0.skills.isEmpty }
        let ai = profile.aiSkillGroups.filter { !$0.skills.isEmpty }
        if !direct.isEmpty || !ai.isEmpty {
            var atoms: [Atom] = []
            if !direct.isEmpty {
                atoms.append(skillsSubtitle("직접 개발 부문"))
                atoms += direct.map(skillGroupRow)
            }
            if !ai.isEmpty {
                atoms.append(skillsSubtitle("AI 활용 부문", topGap: direct.isEmpty ? 0 : 8))
                atoms += ai.map(skillGroupRow)
            }
            section("보유 기술", atoms)
        }

        if !profile.certificate.trimmed.isEmpty {
            section("자격증", [labeledRow("공인 자격증", profile.certificate)])
        }

        if !projects.isEmpty {
            let blocks = projects.enumerated().map { projectBlock($1, isLast: $0 == projects.count - 1) }
            groups.append(Group(atoms: [sectionTitle("주요 프로젝트")] + blocks[0], keepTogether: true))
            for block in blocks.dropFirst() {
                groups.append(Group(atoms: block, keepTogether: true))
            }
        }
        return groups
    }

    // MARK: 텍스트 도구

    private func text(
        _ string: String,
        _ font: UIFont,
        _ color: UIColor,
        lineSpacing: CGFloat = 0,
        tracking: CGFloat = 0,
        align: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = align
        paragraph.lineBreakStrategy = .hangulWordPriority
        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: tracking,
            .paragraphStyle: paragraph,
        ])
    }

    private func height(_ string: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(string.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height)
    }

    private func width(_ string: NSAttributedString) -> CGFloat {
        ceil(string.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).width)
    }

    private func draw(_ string: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat) {
        string.draw(
            with: CGRect(x: x, y: y, width: width, height: height(string, width: width) + 2),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }

    private func fill(_ rect: CGRect, _ color: UIColor) {
        color.setFill()
        UIRectFill(rect)
    }

    private func link(_ url: String?, rect: CGRect) {
        guard let url, let target = URL(string: url) else { return }
        UIGraphicsSetPDFContextURLForRect(target, rect)
    }

    private func font(_ family: AppFontFamily, _ size: CGFloat, _ weight: FontWeightStep) -> UIFont {
        AppFonts.uiFont(family, size, weight: weight)
    }

    private var left: CGFloat { margin.left }

    // MARK: 첫 화면 이름 블록

    private func headerAtom(_ profile: ProfileData) -> Atom {
        let label = text("이력서", font(.sans, 9, .medium), Self.inkMuted, tracking: 1)
        let name = text(profile.name, font(.serif, 26, .bold), Self.ink)
        let titleLine = profile.experience.trimmed.isEmpty
            ? profile.title
            : "\(profile.title)  ·  경력 \(profile.experience)"
        let title = text(titleLine, font(.sans, 10.5, .medium), Self.primary)

        // 연락처 줄. Notion 은 넣지 않는다 — 이력서는 그 자체로 완결된 문서여야 한다.
        var contacts: [(NSAttributedString, String?)] = []
        func contact(_ label: String, _ value: String, _ url: String?) {
            let line = NSMutableAttributedString(attributedString: text("\(label)  ", font(.sans, 7.5, .medium), Self.inkMuted, tracking: 0.5))
            line.append(text(value, font(.sans, 9.5, .medium), url == nil ? Self.inkSoft : Self.primary))
            contacts.append((line, url))
        }
        if !profile.email.trimmed.isEmpty { contact("Email", profile.email, "mailto:\(profile.email)") }
        if !profile.phone.trimmed.isEmpty { contact("Phone", profile.phone, nil) }
        if let github = profile.github { contact("GitHub", shortURL(github), github) }

        let contactWidth = min(contacts.map { width($0.0) }.max() ?? 0, contentWidth * 0.45)
        let leftWidth = contentWidth - contactWidth - 20

        let leftHeight = height(label, width: leftWidth) + 6 + height(name, width: leftWidth) + 5 + height(title, width: leftWidth)
        let lineHeights = contacts.map { height($0.0, width: contactWidth) + 3 }
        let rightHeight = lineHeights.reduce(0, +)
        let bodyHeight = max(leftHeight, rightHeight)

        return Atom(height: bodyHeight + 14 + 1.6) { top in
            // 왼쪽: 아래쪽 정렬
            var y = top + bodyHeight - leftHeight
            draw(label, x: left, y: y, width: leftWidth)
            y += height(label, width: leftWidth) + 6
            draw(name, x: left, y: y, width: leftWidth)
            y += height(name, width: leftWidth) + 5
            draw(title, x: left, y: y, width: leftWidth)

            // 오른쪽: 오른쪽 끝에 붙인다
            var cy = top + bodyHeight - rightHeight
            for (index, (line, url)) in contacts.enumerated() {
                let w = min(width(line), contactWidth)
                let x = left + contentWidth - w
                draw(line, x: x, y: cy, width: w)
                link(url, rect: CGRect(x: x, y: cy, width: w, height: lineHeights[index]))
                cy += lineHeights[index]
            }

            fill(CGRect(x: left, y: top + bodyHeight + 14, width: contentWidth, height: 1.6), Self.primary)
        }
    }

    /// 링크 텍스트가 줄을 먹지 않도록 스킴과 www 를 걷어낸다.
    private func shortURL(_ url: String) -> String {
        url.replacingOccurrences(of: "^https?://", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
            .replacingOccurrences(of: "/$", with: "", options: .regularExpression)
    }

    // MARK: 공통 조판 조각

    private func sectionTitle(_ title: String) -> Atom {
        let label = text(title, font(.sans, 11.5, .bold), Self.primary, tracking: 0.3)
        let labelHeight = height(label, width: contentWidth)
        let labelWidth = width(label)
        return Atom(height: 20 + labelHeight + 10) { top in
            let y = top + 20
            draw(label, x: left, y: y, width: contentWidth)
            let lineX = left + labelWidth + 10
            fill(CGRect(x: lineX, y: y + labelHeight / 2, width: left + contentWidth - lineX, height: 0.8), Self.rule)
        }
    }

    /// 좌측 라벨 + 우측 본문 한 줄. 경력/기술/자격증이 모두 이 형태를 공유한다.
    private func labeledRow(
        _ label: String,
        _ value: String,
        body: NSAttributedString? = nil,
        bottomGap: CGFloat = 8,
        labelWidth: CGFloat = labelWidth
    ) -> Atom {
        let labelText = text(label, font(.sans, 9, .medium), Self.inkMuted, lineSpacing: 1.5)
        let bodyText = body ?? text(value, font(.sans, 10, .regular), Self.inkSoft, lineSpacing: 2.5)
        let bodyX = labelWidth + Self.labelGutter
        let bodyWidth = contentWidth - bodyX
        let rowHeight = max(height(labelText, width: labelWidth), height(bodyText, width: bodyWidth))

        return Atom(height: rowHeight + bottomGap) { top in
            draw(labelText, x: left, y: top, width: labelWidth)
            draw(bodyText, x: left + bodyX, y: top, width: bodyWidth)
        }
    }

    // MARK: 소개

    /// bio 는 화면 줄바꿈 기준으로 \n 이 박혀 있다. PDF 폭은 다르므로 문단(\n\n)만 살린다.
    private func bioParagraphs(_ bio: String) -> [Atom] {
        bio.components(separatedBy: "\n")
            .split(whereSeparator: { $0.trimmed.isEmpty })
            .map { $0.map(\.trimmed).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .map { paragraph in
                let body = text(paragraph, font(.sans, 10, .regular), Self.inkSoft, lineSpacing: 3.2)
                return Atom(height: height(body, width: contentWidth) + 7) { top in
                    draw(body, x: left, y: top, width: contentWidth)
                }
            }
    }

    // MARK: 경력 사항

    private func careerRow(_ career: CareerHistory) -> Atom {
        let period = text(career.period, font(.sans, 9.5, .medium), Self.inkMuted)
        let company = text(career.company, font(.sans, 10.5, .bold), Self.ink)
        let duration = text(career.duration, font(.sans, 9.5, .medium), Self.inkMuted)
        let role = text(career.role, font(.sans, 9.5, .regular), Self.inkSoft)

        let durationWidth = career.duration.trimmed.isEmpty ? 0 : width(duration)
        let companyWidth = contentWidth - Self.labelWidth - durationWidth - 8
        let firstRow = max(height(period, width: Self.labelWidth), height(company, width: companyWidth))
        let roleHeight = career.role.trimmed.isEmpty ? 0 : 2 + height(role, width: contentWidth - Self.labelWidth)

        return Atom(height: firstRow + roleHeight + 9) { top in
            draw(period, x: left, y: top, width: Self.labelWidth)
            draw(company, x: left + Self.labelWidth, y: top, width: companyWidth)
            if durationWidth > 0 {
                draw(duration, x: left + contentWidth - durationWidth, y: top, width: durationWidth)
            }
            if roleHeight > 0 {
                draw(role, x: left + Self.labelWidth, y: top + firstRow + 2, width: contentWidth - Self.labelWidth)
            }
        }
    }

    // MARK: 보유 기술

    private func skillsSubtitle(_ title: String, topGap: CGFloat = 0) -> Atom {
        let label = text(title, font(.sans, 9.5, .bold), Self.ink, tracking: 0.4)
        return Atom(height: topGap + height(label, width: contentWidth) + 6) { top in
            draw(label, x: left, y: top + topGap, width: contentWidth)
        }
    }

    private func skillGroupRow(_ group: SkillGroup) -> Atom {
        labeledRow(
            group.category,
            "",
            body: text(group.skills.joined(separator: "  ·  "), font(.sans, 9.5, .regular), Self.inkSoft, lineSpacing: 2.6),
            bottomGap: 6,
            labelWidth: Self.skillLabelWidth
        )
    }

    // MARK: 주요 프로젝트

    private func projectBlock(_ project: ProjectData, isLast: Bool) -> [Atom] {
        var atoms: [Atom] = []

        // 제목 + 기간
        let title = text(project.title, font(.sans, 11, .bold), Self.ink, lineSpacing: 1.5)
        let period = text(project.period, font(.sans, 9, .medium), Self.inkMuted)
        let periodWidth = width(period)
        let titleWidth = contentWidth - periodWidth - 12
        let titleHeight = max(height(title, width: titleWidth), height(period, width: periodWidth))

        // 카테고리 칩 + 회사 · 역할
        let chip = text(project.category.label, font(.sans, 8, .medium), Self.inkSoft)
        let chipSize = CGSize(width: width(chip) + 10, height: height(chip, width: .greatestFiniteMagnitude) + 3)
        let meta = text(
            [project.company, project.role].filter { !$0.trimmed.isEmpty }.joined(separator: "  ·  "),
            font(.sans, 9.5, .medium),
            Self.primary
        )
        let metaWidth = contentWidth - chipSize.width - 6
        let metaHeight = max(chipSize.height, height(meta, width: metaWidth))

        atoms.append(Atom(height: titleHeight + 4 + metaHeight) { top in
            draw(title, x: left, y: top, width: titleWidth)
            draw(period, x: left + contentWidth - periodWidth, y: top, width: periodWidth)

            let rowY = top + titleHeight + 4
            let chipRect = CGRect(x: left, y: rowY + (metaHeight - chipSize.height) / 2, width: chipSize.width, height: chipSize.height)
            let path = UIBezierPath(roundedRect: chipRect, cornerRadius: 2.5)
            Self.chipBg.setFill()
            path.fill()
            Self.rule.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            draw(chip, x: chipRect.minX + 5, y: chipRect.minY + 1.5, width: chipSize.width)
            draw(meta, x: left + chipSize.width + 6, y: rowY, width: metaWidth)
        })

        let description = project.description
            .replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression)
            .trimmed
        if !description.isEmpty {
            let body = text(description, font(.sans, 9.5, .regular), Self.inkSoft, lineSpacing: 2.8)
            atoms.append(Atom(height: 6 + height(body, width: contentWidth)) { top in
                draw(body, x: left, y: top + 6, width: contentWidth)
            })
        }

        for (index, achievement) in project.achievements.enumerated() {
            let gap: CGFloat = index == 0 ? 6 : 0
            let indent: CGFloat = 2 + 2.6 + 6
            let body = text(achievement, font(.sans, 9.5, .regular), Self.inkSoft, lineSpacing: 2.6)
            atoms.append(Atom(height: gap + height(body, width: contentWidth - indent) + 3) { top in
                let y = top + gap
                let dot = UIBezierPath(ovalIn: CGRect(x: left + 2, y: y + 4.6, width: 2.6, height: 2.6))
                Self.primary.setFill()
                dot.fill()
                draw(body, x: left + indent, y: y, width: contentWidth - indent)
            })
        }

        if !project.techStack.isEmpty {
            let label = text("Tech  ", font(.sans, 8.5, .medium), Self.inkMuted)
            let labelWidth = width(label)
            let body = text(project.techStack.joined(separator: ", "), font(.sans, 8.5, .regular), Self.inkMuted, lineSpacing: 2)
            atoms.append(Atom(height: 5 + height(body, width: contentWidth - labelWidth)) { top in
                draw(label, x: left, y: top + 5, width: labelWidth)
                draw(body, x: left + labelWidth, y: top + 5, width: contentWidth - labelWidth)
            })
        }

        let links = projectLinks(project)
        if !links.isEmpty {
            let items = links.map { name, url -> (NSAttributedString, String) in
                let string = NSMutableAttributedString(attributedString: text(name, font(.sans, 8.5, .medium), Self.primary))
                string.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: string.length))
                return (string, url)
            }
            let rowHeight = items.map { height($0.0, width: .greatestFiniteMagnitude) }.max() ?? 0
            atoms.append(Atom(height: 4 + rowHeight) { top in
                var x = left
                for (string, url) in items {
                    let w = width(string)
                    draw(string, x: x, y: top + 4, width: w)
                    link(url, rect: CGRect(x: x, y: top + 4, width: w, height: rowHeight))
                    x += w + 10
                }
            })
        }

        // 블록 사이 구분선
        if !isLast {
            atoms.append(Atom(height: 14 + 0.8 + 14) { top in
                fill(CGRect(x: left, y: top + 14, width: contentWidth, height: 0.8), Self.ruleLight)
            })
        }
        return atoms
    }

    private func projectLinks(_ project: ProjectData) -> [(String, String)] {
        var links: [(String, String)] = []
        if let url = project.liveUrl { links.append(("서비스 링크", url)) }
        if let url = project.appStoreUrl { links.append(("App Store", url)) }
        if let url = project.playStoreUrl { links.append(("Google Play", url)) }
        if let url = project.githubUrl { links.append(("GitHub", url)) }
        return links
    }

    // MARK: 꼬리말

    /// 쪽마다 반복되는 유일한 줄. 이름 · 이메일과 쪽 번호.
    private func drawFooter(pageNumber: Int, pageCount: Int, profile: ProfileData) {
        let identity = [profile.name, profile.email]
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
        let leftText = text(identity, font(.sans, 8, .regular), Self.inkMuted)
        let rightText = text("\(pageNumber) / \(pageCount)", font(.sans, 8, .medium), Self.inkMuted)
        let y = page.height - margin.bottom - footerHeight + 14
        let rightWidth = width(rightText)
        draw(leftText, x: left, y: y, width: contentWidth - rightWidth - 12)
        draw(rightText, x: left + contentWidth - rightWidth, y: y, width: rightWidth)
    }
}

// MARK: - 도움

private extension UIColor {
    convenience init(argb: UInt32) {
        self.init(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255
        )
    }
}

extension StringProtocol {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
