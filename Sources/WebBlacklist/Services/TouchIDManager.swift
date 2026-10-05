import Foundation
import AppKit
import LocalAuthentication

public final class TouchIDManager {
    public static let shared = TouchIDManager()
    
    private init() {}
    
    /// Checks if biometric authentication (Touch ID) is supported and enrolled
    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Performs Touch ID authentication with passcode fallback
    public func authenticate(
        reason: String = "Touch ID to unlock Web Blacklist and access sites",
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Ensure the application is active and key so the Touch ID prompt is presented
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        
        var authError: NSError?
        
        // Use deviceOwnerAuthentication which prompts Touch ID first, but also provides passcode fallback
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &authError) {
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        let err = error ?? NSError(domain: "TouchID", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                        completion(.failure(err))
                    }
                }
            }
        } else {
            let err = authError ?? NSError(domain: "TouchID", code: -2, userInfo: [NSLocalizedDescriptionKey: "Authentication not supported on this device"])
            DispatchQueue.main.async {
                completion(.failure(err))
            }
        }
    }
}
