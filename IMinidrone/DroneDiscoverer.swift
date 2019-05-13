import UIKit

@objc protocol DroneDiscovererDelegate {
    func droneDiscoverer(_ droneDiscoverer: DroneDiscoverer!, didUpdateDronesList dronesList: [Any]!)
}

extension Notification.Name {
    static let ARDiscoveryNotificationServicesDevicesListUpdated = Notification.Name(kARDiscoveryNotificationServicesDevicesListUpdated)
}

class DroneDiscoverer: NSObject {
    weak var delegate: DroneDiscovererDelegate? {
        didSet {
            delegate?.droneDiscoverer(self, didUpdateDronesList: ARDiscovery.sharedInstance().getCurrentListOfDevicesServices())
        }
    }
    
    func startDiscovering() {
        registerNotifications()
        ARDiscovery.sharedInstance().start()
    }
    
    func stopDiscovering() {
        ARDiscovery.sharedInstance().stop()
        unregisterNotifications()
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.discoveryDidUpdateServices),
                                               name: .ARDiscoveryNotificationServicesDevicesListUpdated,
                                               object: nil)
    }
    
    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .ARDiscoveryNotificationServicesDevicesListUpdated,
                                                  object: nil)
    }

    @objc private func discoveryDidUpdateServices(notification: NSNotification) {
        if let discoveryServicesList = notification.userInfo?[kARDiscoveryServicesList] as? [Any] {
            DispatchQueue.main.async {
                self.delegate?.droneDiscoverer(self, didUpdateDronesList: discoveryServicesList)
            }
        }
    }
}