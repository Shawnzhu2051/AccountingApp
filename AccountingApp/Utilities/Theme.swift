import SwiftUI
import Foundation

// MARK: - 颜色主题
extension Color {
    // 主色调
    static let accentBlue = Color(red: 0.2, green: 0.5, blue: 1.0)
    static let accentGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let accentRed = Color(red: 1.0, green: 0.3, blue: 0.3)
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let accentPurple = Color(red: 0.6, green: 0.4, blue: 0.9)

    // 背景色
    static let cardBackground = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    // 图表配色
    static let chartColors: [Color] = [
        Color(red: 0.3, green: 0.6, blue: 1.0),
        Color(red: 0.3, green: 0.8, blue: 0.5),
        Color(red: 1.0, green: 0.6, blue: 0.3),
        Color(red: 0.8, green: 0.4, blue: 0.9),
        Color(red: 1.0, green: 0.4, blue: 0.5),
        Color(red: 0.4, green: 0.7, blue: 0.9),
        Color(red: 0.9, green: 0.7, blue: 0.3),
        Color(red: 0.5, green: 0.8, blue: 0.8)
    ]
}

// MARK: - 通知
extension Notification.Name {
    static let transactionsDidChange = Notification.Name("transactionsDidChange")
}

// MARK: - 视图修饰符
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func sectionCardStyle() -> some View {
        self
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
    }
}

// MARK: - 字体样式
extension Font {
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let cardSubtitle = Font.system(size: 14, weight: .regular)
    static let currencyAmount = Font.system(size: 28, weight: .bold, design: .rounded)
    static let smallAmount = Font.system(size: 20, weight: .semibold, design: .rounded)
}

// MARK: - 导入（CSV / Excel 2003 XML .xls）
// 注意：为了保证 xcodeproj 自动包含编译（避免新文件未加入 Target），暂时放在 Theme.swift。
import SwiftData

enum TransactionImportError: LocalizedError {
    case unsupportedFile
    case empty
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "不支持的文件格式（仅支持CSV/XLS）"
        case .empty:
            return "文件内容为空"
        case .invalidFormat(let msg):
            return "文件格式不正确：\(msg)"
        }
    }
}

/// 导入：支持从本 App 导出的 CSV / Excel(2003 XML .xls) 再导入
@MainActor
enum TransactionImporter {

    struct Row {
        let datetime: Date
        let type: TransactionType
        let currency: Currency
        let amount: Decimal
        let categoryL1: String
        let categoryL2: String
        let projectName: String
        let note: String
    }

    static func importFile(url: URL, modelContext: ModelContext) throws -> Int {
        let ext = url.pathExtension.lowercased()
        if ext == "csv" {
            let rows = try parseCSV(url: url)
            return try upsert(rows: rows, modelContext: modelContext)
        } else if ext == "xls" {
            let rows = try parseXLSXML(url: url)
            return try upsert(rows: rows, modelContext: modelContext)
        } else {
            throw TransactionImportError.unsupportedFile
        }
    }

    // MARK: - Upsert

    private static func upsert(rows: [Row], modelContext: ModelContext) throws -> Int {
        guard !rows.isEmpty else { throw TransactionImportError.empty }

        let projectRepo = ProjectRepository(modelContext: modelContext)
        let existing = (try? projectRepo.fetchAll()) ?? []
        var projectByName: [String: Project] = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })

        // 如没有默认项目，尽量创建一个兜底
        let defaultProject: Project
        let fetchedDefault: Project?
        do {
            fetchedDefault = try projectRepo.fetchDefault()
        } catch {
            fetchedDefault = nil
        }

        if let dp = fetchedDefault {
            defaultProject = dp
        } else if let any = existing.first {
            defaultProject = any
        } else {
            let p = Project(name: "日常项目", isDefault: true)
            try projectRepo.save(p)
            defaultProject = p
            projectByName[p.name] = p
        }

        var inserted = 0

        for r in rows {
            let project: Project
            if let p = projectByName[r.projectName] {
                project = p
            } else if r.projectName.isEmpty || r.projectName == "未知项目" {
                project = defaultProject
            } else {
                let p = Project(name: r.projectName)
                try projectRepo.save(p)
                projectByName[p.name] = p
                project = p
            }

            let amountMinor = Int64(truncating: (r.amount * Decimal(100)) as NSNumber)

            let tx = Transaction(
                amountMinor: amountMinor,
                currency: r.currency,
                type: r.type,
                datetime: r.datetime,
                projectId: project.id,
                categoryL1: r.categoryL1,
                categoryL2: r.categoryL2,
                note: r.note
            )

            modelContext.insert(tx)
            inserted += 1
        }

        try modelContext.save()
        NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
        return inserted
    }

    // MARK: - CSV

    private static func parseCSV(url: URL) throws -> [Row] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content
            .split(whereSeparator: \.isNewline)
            .map { String($0) }

        guard let headerLine = lines.first else { throw TransactionImportError.empty }

        let headers = splitCSVLine(headerLine)
        let index = headerIndex(headers)

        var rows: [Row] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let cols = splitCSVLine(line)
            if cols.count < headers.count { continue }
            if let row = try parseRow(columns: cols, index: index) {
                rows.append(row)
            }
        }
        return rows
    }

    /// 仅需支持本 App 导出的 CSV：无引号转义，逗号已被替换为中文逗号。
    private static func splitCSVLine(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
    }

    // MARK: - XLS (Excel 2003 XML)

    private static func parseXLSXML(url: URL) throws -> [Row] {
        let xml = try String(contentsOf: url, encoding: .utf8)
        if xml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TransactionImportError.empty
        }

        let parser = Excel2003XMLParser(xml: xml)
        let table = try parser.parseTable()
        guard let headers = table.first else { throw TransactionImportError.invalidFormat("缺少表头") }
        let index = headerIndex(headers)

        var rows: [Row] = []
        for cols in table.dropFirst() {
            if let row = try parseRow(columns: cols, index: index) {
                rows.append(row)
            }
        }
        return rows
    }

    // MARK: - Row mapping

    private struct HeaderIndex {
        let datetime: Int
        let type: Int
        let currency: Int
        let amount: Int
        let categoryL1: Int
        let categoryL2: Int
        let project: Int
        let note: Int
    }

    private static func headerIndex(_ headers: [String]) -> HeaderIndex {
        func find(_ names: [String]) -> Int {
            for (i, h) in headers.enumerated() {
                if names.contains(where: { $0 == h }) { return i }
            }
            return -1
        }

        // 兼容中文/英文
        let idx = HeaderIndex(
            datetime: find(["时间", "Datetime", "Date"]),
            type: find(["类型", "Type"]),
            currency: find(["币种", "Currency"]),
            amount: find(["金额", "Amount"]),
            categoryL1: find(["一级分类", "CategoryL1", "Category1"]),
            categoryL2: find(["二级分类", "CategoryL2", "Category2"]),
            project: find(["项目", "Project"]),
            note: find(["备注", "Note", "Memo"])
        )
        return idx
    }

    private static func parseRow(columns: [String], index: HeaderIndex) throws -> Row? {
        func get(_ i: Int) -> String {
            guard i >= 0, i < columns.count else { return "" }
            return columns[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let dtStr = get(index.datetime)
        let typeStr = get(index.type)
        let curStr = get(index.currency)
        let amountStr = get(index.amount)
        let c1 = get(index.categoryL1)
        let c2 = get(index.categoryL2)
        let project = get(index.project)
        let note = get(index.note)

        if dtStr.isEmpty && amountStr.isEmpty { return nil }

        guard let type = TransactionType.fromImportString(typeStr) else {
            throw TransactionImportError.invalidFormat("无法识别类型：\(typeStr)")
        }
        guard let currency = Currency(rawValue: curStr) else {
            throw TransactionImportError.invalidFormat("无法识别币种：\(curStr)")
        }
        guard let amount = Decimal.fromLooseString(amountStr), amount > 0 else {
            throw TransactionImportError.invalidFormat("金额不正确：\(amountStr)")
        }

        let datetime = try DateParser.parseLoose(dtStr)

        return Row(
            datetime: datetime,
            type: type,
            currency: currency,
            amount: amount,
            categoryL1: c1,
            categoryL2: c2,
            projectName: project,
            note: note
        )
    }
}

private enum DateParser {
    static func parseLoose(_ s: String) throws -> Date {
        let str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty { throw TransactionImportError.invalidFormat("时间为空") }

        // 尝试几种常见格式（兼容历史导出）
        let formats = [
            "yyyy-MM-dd",
            "yyyy/M/d",
            "yyyy/M/d HH:mm",
            "M/d/yyyy",
            "M/d/yy",
            "M/d/yy, h:mm a",
            "M/d/yy h:mm a",
            "dd/MM/yyyy",
            "dd/MM/yyyy HH:mm"
        ]

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = TimeZone.current

        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: str) {
                return d
            }
        }

        // 最后用系统解析兜底
        let df2 = DateFormatter()
        df2.dateStyle = .short
        df2.timeStyle = .short
        if let d = df2.date(from: str) {
            return d
        }

        throw TransactionImportError.invalidFormat("无法解析时间：\(str)")
    }
}

private extension Decimal {
    static func fromLooseString(_ s: String) -> Decimal? {
        let str = s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        return Decimal(string: str)
    }
}

private extension TransactionType {
    static func fromImportString(_ s: String) -> TransactionType? {
        let str = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if str == TransactionType.expense.rawValue || str == "支出" { return .expense }
        if str == TransactionType.income.rawValue || str == "收入" { return .income }
        if str.lowercased() == "expense" { return .expense }
        if str.lowercased() == "income" { return .income }
        return nil
    }
}

/// 解析 Excel 2003 XML Spreadsheet: 提取第一张表的 Table->Row->Cell->Data 文本
private final class Excel2003XMLParser: NSObject, XMLParserDelegate {
    private let data: Data

    private var inTable = false
    private var inRow = false
    private var inData = false

    private var currentRow: [String] = []
    private var table: [[String]] = []

    private var currentText: String = ""

    init(xml: String) {
        self.data = Data(xml.utf8)
    }

    func parseTable() throws -> [[String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if !parser.parse() {
            throw TransactionImportError.invalidFormat(parser.parserError?.localizedDescription ?? "XML解析失败")
        }
        return table
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = elementName.lowercased()

        if name == "table" {
            inTable = true
        } else if inTable && name == "row" {
            inRow = true
            currentRow = []
        } else if inRow && name == "data" {
            inData = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inData {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()

        if name == "data" {
            inData = false
            currentRow.append(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if name == "row" {
            inRow = false
            if currentRow.contains(where: { !$0.isEmpty }) {
                table.append(currentRow)
            }
        } else if name == "table" {
            inTable = false
        }
    }
}
