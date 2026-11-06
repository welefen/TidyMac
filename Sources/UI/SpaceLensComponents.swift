import SwiftUI
import AppKit

// MARK: - Palette

enum SpaceLensPalette {
    static let tones: [AccentTone] = [.mint, .blue, .purple, .orange, .pink, .teal, .yellow, .blue]

    static func tone(at index: Int) -> AccentTone {
        tones[abs(index) % tones.count]
    }
}

// MARK: - Squarified treemap layout

enum SquarifiedTreemap {
    /// Returns one rect per positive value, laid out inside `rect`.
    static func layout(values: [Int64], in rect: CGRect) -> [CGRect] {
        guard !values.isEmpty, rect.width > 1, rect.height > 1 else { return [] }
        let doubles = values.map { max(0, Double($0)) }
        guard doubles.reduce(0, +) > 0 else { return [] }

        var remaining = doubles
        var result: [CGRect] = []
        var area = rect

        while !remaining.isEmpty {
            if area.width < 1 || area.height < 1 {
                result.append(contentsOf: remaining.map { _ in .zero })
                break
            }
            let remainingSum = remaining.reduce(0, +)
            guard remainingSum > 0 else {
                result.append(contentsOf: remaining.map { _ in .zero })
                break
            }
            let unitArea = Double(area.width * area.height) / remainingSum
            let shortSide = min(area.width, area.height)
            let shortSideD = Double(shortSide)

            var row: [Double] = [remaining[0]]
            var rowArea = remaining[0] * unitArea
            var worst = worstAspect(row: row, rowArea: rowArea, unitArea: unitArea, shortSide: shortSideD)
            var index = 1
            while index < remaining.count {
                let candidateRow = row + [remaining[index]]
                let candidateArea = rowArea + remaining[index] * unitArea
                let candidateWorst = worstAspect(row: candidateRow,
                                                 rowArea: candidateArea,
                                                 unitArea: unitArea,
                                                 shortSide: shortSideD)
                if candidateWorst <= worst {
                    row = candidateRow
                    rowArea = candidateArea
                    worst = candidateWorst
                    index += 1
                } else {
                    break
                }
            }

            let thickness = CGFloat(rowArea / shortSideD)
            var offset: CGFloat = 0
            for value in row {
                let length = CGFloat(value * unitArea * shortSideD / rowArea)
                let cell: CGRect
                if area.width >= area.height {
                    // Wider than tall: lay the row out as a vertical strip on the left.
                    cell = CGRect(x: area.minX, y: area.minY + offset,
                                  width: thickness, height: length)
                } else {
                    // Taller than wide: lay the row out as a horizontal strip on top.
                    cell = CGRect(x: area.minX + offset, y: area.minY,
                                  width: length, height: thickness)
                }
                result.append(cell)
                offset += length
            }

            remaining.removeFirst(row.count)
            if area.width >= area.height {
                area = CGRect(x: area.minX + thickness, y: area.minY,
                              width: max(0, area.width - thickness), height: area.height)
            } else {
                area = CGRect(x: area.minX, y: area.minY + thickness,
                              width: area.width, height: max(0, area.height - thickness))
            }
        }

        return result
    }

    private static func worstAspect(row: [Double], rowArea: Double,
                                    unitArea: Double, shortSide: Double) -> Double {
        guard rowArea > 0, shortSide > 0, unitArea > 0 else { return .infinity }
        let thickness = rowArea / shortSide
        guard thickness > 0 else { return .infinity }
        var worst = 0.0
        for value in row {
            let length = value * unitArea / thickness
            guard length > 0 else { continue }
            worst = max(worst, max(length / thickness, thickness / length))
        }
        return worst
    }
}

// MARK: - Treemap

struct SpaceTreemapView: View {
    let node: SpaceNode
    var onEnter: (SpaceNode) -> Void

    private var children: [SpaceNode] {
        node.children.filter { $0.byteCount > 0 }.sorted { $0.byteCount > $1.byteCount }
    }

    var body: some View {
        GeometryReader { proxy in
            let sizedChildren = children
            let rects = SquarifiedTreemap.layout(values: sizedChildren.map(\.byteCount),
                                                 in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.field.opacity(0.5))
                ForEach(sizedChildren.indices, id: \.self) { index in
                    if index < rects.count {
                        let padded = Self.paddedRect(rects[index])
                        TreemapCellView(node: sizedChildren[index],
                                        size: padded.size,
                                        tone: SpaceLensPalette.tone(at: index),
                                        isEnterable: !sizedChildren[index].children.isEmpty) {
                            onEnter(sizedChildren[index])
                        }
                        .position(x: padded.midX, y: padded.midY)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    static func paddedRect(_ rect: CGRect) -> CGRect {
        let insetX = min(2, rect.width * 0.08)
        let insetY = min(2, rect.height * 0.08)
        return rect.insetBy(dx: insetX, dy: insetY)
    }
}

private struct TreemapCellView: View {
    let node: SpaceNode
    let size: CGSize
    let tone: AccentTone
    let isEnterable: Bool
    var onEnter: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: min(9, min(size.width, size.height) * 0.18),
                             style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.tint(tone).opacity(hovering ? 0.56 : 0.36),
                                 Theme.tint(tone).opacity(hovering ? 0.34 : 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: min(9, min(size.width, size.height) * 0.18),
                             style: .continuous)
                .strokeBorder(Theme.tint(tone).opacity(hovering ? 0.75 : 0.38), lineWidth: 1)
            label
                .padding(size.width >= 130 ? 9 : 6)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if isEnterable { onEnter() }
        }
        .animation(.easeInOut(duration: 0.16), value: hovering)
    }

    @ViewBuilder
    private var label: some View {
        if size.width >= 130 && size.height >= 62 {
            VStack(alignment: .leading, spacing: 3) {
                Text(L(node.name))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(Format.bytes(node.byteCount))
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else if size.width >= 58 && size.height >= 30 {
            Text(L(node.name))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Breadcrumb

struct SpaceLensBreadcrumb: View {
    let path: [SpaceNode]
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "house.fill")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
            ForEach(Array(path.enumerated()), id: \.offset) { index, node in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                Button {
                    onSelect(index)
                } label: {
                    Text(L(node.name))
                        .font(.system(size: 12, weight: index == path.count - 1 ? .semibold : .medium))
                        .foregroundStyle(index == path.count - 1 ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 8)
        }
        .frame(height: 26)
    }
}

// MARK: - Stat card

struct LensStatCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var caption: String? = nil
    let symbol: String
    let tone: AccentTone

    var body: some View {
        HStack(spacing: 10) {
            ToneIcon(symbol: symbol, tone: tone, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(L(title))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(L(value))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let unit {
                        Text(L(unit))
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                if let caption {
                    Text(L(caption))
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Ranking row

struct SpaceRankRowView: View {
    let node: SpaceNode
    let tone: AccentTone
    let fraction: Double
    let isLast: Bool
    let isHovered: Bool
    var onEnter: () -> Void
    var onReveal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ToneIcon(symbol: node.isDirectory ? "folder.fill" : "doc.fill",
                         tone: tone, size: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L(node.name))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(L(subtitle))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 164, alignment: .leading)

                StorageBar(usedFraction: fraction, tone: tone, height: 5)
                    .frame(width: 128)

                Text(Format.percent(fraction))
                    .font(.system(size: 10.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 38, alignment: .trailing)

                Spacer(minLength: 8)

                Text(Format.bytes(node.byteCount))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 80, alignment: .trailing)

                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.field))
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .help("在 Finder 中显示")
                .opacity(isHovered ? 1 : 0.45)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 10)
                    .opacity(node.children.isEmpty ? 0 : (isHovered ? 1 : 0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Theme.cardHover : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !node.children.isEmpty { onEnter() }
            }

            if !isLast {
                DividerLine()
                    .padding(.leading, 56)
                    .padding(.trailing, 14)
            }
        }
    }

    private var subtitle: String {
        if !node.isDirectory { return "文件" }
        if node.children.isEmpty {
            return node.byteCount > 0 ? "文件夹" : "空目录"
        }
        return L("\(node.children.count) 个子项目")
    }
}

// MARK: - Scanning

struct SpaceLensScanningView: View {
    let progress: Double
    let status: String
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressRing(progress: max(progress, 0.03), lineWidth: 10, size: 108, tone: .mint)
                .overlay(
                    Text(Format.percent(progress))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                )
            VStack(spacing: 4) {
                Text(L(status))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text("正在分析目录大小，可以随时取消")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Button("取消扫描", action: onCancel)
                .buttonStyle(SecondaryButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
