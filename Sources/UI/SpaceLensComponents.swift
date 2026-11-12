import SwiftUI
import AppKit

// MARK: - Palette

enum SpaceLensPalette {
    /// One accent hue, stepped down for quieter cells.
    static func opacity(at index: Int) -> Double {
        let steps: [Double] = [0.92, 0.72, 0.58, 0.46, 0.36, 0.28, 0.22, 0.18]
        return steps[abs(index) % steps.count]
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
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(Theme.field.opacity(0.4))
                ForEach(sizedChildren.indices, id: \.self) { index in
                    if index < rects.count {
                        let padded = Self.paddedRect(rects[index])
                        TreemapCellView(node: sizedChildren[index],
                                        size: padded.size,
                                        accentOpacity: SpaceLensPalette.opacity(at: index),
                                        isLeading: index == 0,
                                        isEnterable: sizedChildren[index].canDrillInLens) {
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
    let accentOpacity: Double
    let isLeading: Bool
    let isEnterable: Bool
    var onEnter: () -> Void

    @State private var hovering = false

    private var fill: Color {
        isLeading
            ? Theme.accent.opacity(hovering ? min(1, accentOpacity + 0.06) : accentOpacity)
            : Theme.field.opacity(hovering ? 0.85 : 0.5)
    }

    private var labelColor: Color {
        isLeading ? Theme.textOnAccent : Theme.textPrimary
    }

    private var secondaryLabelColor: Color {
        isLeading ? Theme.textOnAccent.opacity(0.75) : Theme.textTertiary
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: min(7, min(size.width, size.height) * 0.16),
                             style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: min(7, min(size.width, size.height) * 0.16),
                             style: .continuous)
                .strokeBorder(isLeading ? Color.clear : Theme.stroke, lineWidth: 1)
            label
                .padding(size.width >= 130 ? 8 : 6)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            if isEnterable { onEnter() }
        }
        .animation(.easeOut(duration: 0.14), value: hovering)
    }

    @ViewBuilder
    private var label: some View {
        if size.width >= 130 && size.height >= 62 {
            VStack(alignment: .leading, spacing: 3) {
                Text(L(node.name))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(Format.bytes(node.byteCount))
                    .font(Theme.monoFont(10))
                    .foregroundStyle(secondaryLabelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        } else if size.width >= 58 && size.height >= 30 {
            Text(L(node.name))
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(labelColor)
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
            Image(systemName: "house")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textTertiary)
            ForEach(Array(path.enumerated()), id: \.offset) { index, node in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(Theme.textTertiary)
                }
                Button {
                    onSelect(index)
                } label: {
                    Text(L(node.name))
                        .font(.system(size: 12, weight: index == path.count - 1 ? .medium : .regular))
                        .foregroundStyle(index == path.count - 1 ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 8)
        }
        .frame(height: 24)
    }
}

// MARK: - Stat card

struct LensStatCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L(title))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(L(value))
                    .font(Theme.figureFont(24))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let unit {
                    Text(L(unit))
                        .font(Theme.monoFont(11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            if let caption {
                Text(L(caption))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Ranking row

struct SpaceRankRowView: View {
    let node: SpaceNode
    let fraction: Double
    let isLast: Bool
    let isHovered: Bool
    var onEnter: () -> Void
    var onReveal: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: node.isDirectory ? "folder" : "doc")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L(node.name))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(L(subtitle))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(width: 168, alignment: .leading)

                CapacityRuler(fraction: fraction, height: 5)
                    .frame(width: 132)

                Text(Format.percent(fraction))
                    .font(Theme.monoFont(10.5))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 38, alignment: .trailing)

                Spacer(minLength: 8)

                Text(Format.bytes(node.byteCount))
                    .font(Theme.monoFont(11.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 80, alignment: .trailing)

                Button(action: onReveal) {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isHovered ? Theme.field : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                .help("在 Finder 中显示")
                .opacity(isHovered ? 1 : 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 10)
                    .opacity(node.canDrillInLens ? (isHovered ? 1 : 0.5) : 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous)
                    .fill(isHovered ? Theme.cardHover : Color.clear)
                    .padding(.horizontal, 5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if node.canDrillInLens { onEnter() }
            }

            if !isLast {
                DividerLine()
                    .padding(.leading, 43)
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
        VStack(spacing: 14) {
            Text(Format.percent(progress))
                .font(Theme.monoFont(44, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            CapacityRuler(fraction: progress, height: 5)
                .frame(width: 260)
            VStack(spacing: 3) {
                Text(L(status))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text(L("正在分析目录大小，可以随时取消"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            Button("取消扫描", action: onCancel)
                .buttonStyle(SecondaryButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
