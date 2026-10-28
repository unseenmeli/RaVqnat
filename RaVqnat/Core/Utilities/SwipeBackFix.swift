import UIKit

/// Screens with custom top bars hide the system navigation bar, which normally disables the
/// interactive edge-swipe "back" gesture. This keeps it working whenever there is a screen to pop.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
