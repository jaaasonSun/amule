import Foundation
import SharedModels
import SharedServices

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}
