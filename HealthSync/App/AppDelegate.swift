import UIKit

/// HealthKit background delivery and background `URLSession` lifecycle.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundSyncCoordinator.shared.startIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        if identifier == BackgroundWebDAVSession.sessionIdentifier {
            BackgroundWebDAVSession.shared.handleBackgroundEvents(completionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }
}
