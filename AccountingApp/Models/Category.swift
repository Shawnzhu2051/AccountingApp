import Foundation

/// 分类字典
/// - 支出: 一级+二级
/// - 收入: 只有一个层级(具体收入来源)。为兼容 Transaction 的 categoryL1/categoryL2 结构：
///   - categoryL1 固定为 "收入"
///   - categoryL2 为具体收入分类(工资收入/红包收入/奖金收入/其他收入)
struct Category {
    let level1: String
    let level2: [String]
}

struct CategoryDictionary {
    // MARK: - Expense

    static let expenseCategories: [Category] = [
        Category(level1: "娱乐", level2: ["聚会", "运动", "旅游", "看剧"]),
        Category(level1: "购物", level2: ["数码产品", "衣物", "酒", "书", "虚拟产品", "其他"]),
        Category(level1: "日常", level2: ["吃饭", "日用品", "水电气网", "话费", "理发", "赌博", "其他"]),
        Category(level1: "出行", level2: ["地铁", "打车", "机票", "高铁"]),
        Category(level1: "人情", level2: ["孝敬家长", "红包", "礼物"]),
        Category(level1: "金融", level2: ["投资", "税", "罚款", "其他"]),
        Category(level1: "医疗", level2: ["看病", "药物"]),
        Category(level1: "住房", level2: ["房租", "物管费", "其他"])
    ]

    static var expenseLevel1List: [String] {
        expenseCategories.map { $0.level1 }
    }

    static func expenseLevel2List(for level1: String) -> [String] {
        expenseCategories.first { $0.level1 == level1 }?.level2 ?? []
    }

    // MARK: - Income

    static let incomeCategories: [String] = [
        "工资收入",
        "红包收入",
        "奖金收入",
        "其他收入"
    ]
}
