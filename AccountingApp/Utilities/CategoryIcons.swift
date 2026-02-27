import SwiftUI

struct CategoryIcons {
    // 二级分类图标映射
    static func icon(for level2Category: String) -> String {
        switch level2Category {
        // 娱乐类
        case "聚会": return "wineglass.fill"
        case "运动": return "figure.run"
        case "旅游": return "airplane"
        case "看剧": return "tv.fill"
        
        // 购物类
        case "数码产品": return "laptopcomputer"
        case "衣物": return "tshirt.fill"
        case "酒": return "wineglass"
        case "书": return "book.fill"
        case "虚拟产品": return "app.badge"
        
        // 日常类
        case "吃饭": return "fork.knife"
        case "日用品": return "cart.fill"
        case "水电气网": return "bolt.fill"
        case "话费": return "phone.fill"
        case "理发": return "scissors"
        case "赌博": return "suit.spade.fill"
        
        // 出行类
        case "地铁": return "tram.fill"
        case "打车": return "car.fill"
        case "机票": return "airplane.departure"
        case "高铁": return "train.side.front.car"
        
        // 人情类
        case "孝敬家长": return "heart.fill"
        case "红包": return "envelope.fill"
        case "礼物": return "gift.fill"
        
        // 金融类
        case "投资": return "chart.line.uptrend.xyaxis"
        case "税": return "doc.text.fill"
        case "罚款": return "exclamationmark.triangle.fill"
        
        // 医疗类
        case "看病": return "cross.case.fill"
        case "药物": return "pills.fill"
        
        // 住房类
        case "房租": return "house.fill"
        case "物管费": return "building.2.fill"
        
        // 其他/默认
        case "其他": return "ellipsis.circle.fill"
        default: return "circle.fill"
        }
    }
    
    // 一级分类颜色映射
    static func color(for level1Category: String) -> Color {
        switch level1Category {
        case "娱乐": return .accentPurple
        case "购物": return .accentOrange
        case "日常": return .accentBlue
        case "出行": return .accentGreen
        case "人情": return Color(red: 1.0, green: 0.4, blue: 0.5)
        case "金融": return Color(red: 0.9, green: 0.7, blue: 0.3)
        case "医疗": return .accentRed
        case "住房": return Color(red: 0.5, green: 0.6, blue: 0.8)
        default: return .gray
        }
    }
}
