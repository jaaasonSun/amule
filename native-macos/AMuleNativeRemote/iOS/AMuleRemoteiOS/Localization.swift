#if canImport(UIKit)
import Foundation

func L(_ key: String) -> String {
    String(localized: String.LocalizationValue(key), bundle: .main)
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: L(key), locale: .current, arguments: arguments)
}
#endif
