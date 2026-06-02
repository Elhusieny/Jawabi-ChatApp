//import Foundation
//
//// MARK: - Message Time Formatting
//extension Message {
//   
//    /// Returns a short date/time for voice notes: "3:45 PM"  or "Mon 3:45 PM" if older than today
//    var formattedTimeWithDate: String {
//        let calendar = Calendar.current
//        if calendar.isDateInToday(date) {
//            return formattedTime
//        } else if calendar.isDateInYesterday(date) {
//            return "Yesterday \(formattedTime)"
//        } else {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "EEE h:mm a"
//            formatter.amSymbol = "AM"
//            formatter.pmSymbol = "PM"
//            return formatter.string(from: date)
//        }
//    }
//}
