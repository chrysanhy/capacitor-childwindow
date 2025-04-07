import Foundation

@objc public class ChildWindow: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
