import UIKit

class DeviceListViewController: UIViewController {
    private let controllerID : Array = ["controlButton", "controlFlow", "controlGSensor"]

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var controller: UISegmentedControl!
    
    private let droneDiscoverer = DroneDiscoverer()
    private var dataSource: [Any] = []
    private var selectedService: ARService?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        droneDiscoverer.delegate = self;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        registerNotifications()
        droneDiscoverer.startDiscovering()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        unregisterNotifications()
        droneDiscoverer.stopDiscovering()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let arService = selectedService else {
            return
        }

        if segue.identifier == controllerID[0] {
            let viewController: MiniDroneButtonViewController = (segue.destination as? MiniDroneButtonViewController)!
            viewController.service = arService
        } else if segue.identifier == controllerID[1] {
            let viewController: MiniDroneFlowViewController = (segue.destination as? MiniDroneFlowViewController)!
            viewController.service = arService
        } else if segue.identifier == controllerID[2] {
            let viewController: MiniDroneGSensorViewController = (segue.destination as? MiniDroneGSensorViewController)!
            viewController.service = arService
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enteredBackground),
                                               name: .UIApplicationDidEnterBackground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.enterForeground),
                                               name: .UIApplicationWillEnterForeground,
                                               object: nil)
    }
    
    private func unregisterNotifications() {
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationDidEnterBackground,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: .UIApplicationWillEnterForeground,
                                                  object: nil)
    }
    
    @objc private func enterForeground(notification: Notification?) {
        droneDiscoverer.startDiscovering()
    }

    @objc private func enteredBackground(notification: Notification?) {
        droneDiscoverer.stopDiscovering()
    }
}

extension DeviceListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")

        if let arService = dataSource[indexPath.row] as? ARService {
            cell.textLabel?.text = String(arService.name)
        }

        return cell
    }
}

extension DeviceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let arService = dataSource[indexPath.row] as? ARService else {
            return
        }

        switch arService.product {
        case ARDISCOVERY_PRODUCT_MINIDRONE,
             ARDISCOVERY_PRODUCT_MINIDRONE_EVO_BRICK,
             ARDISCOVERY_PRODUCT_MINIDRONE_EVO_LIGHT,
             ARDISCOVERY_PRODUCT_MINIDRONE_DELOS3:
            selectedService = arService
            
            let idx = controller.selectedSegmentIndex
            switch idx {
            case 0, 1, 2:
                self.performSegue(withIdentifier: controllerID[idx], sender: self)
                break
            default:
                self.performSegue(withIdentifier: controllerID[0], sender: self)
                break
            }

        default:
            break;
        }
    }
}

extension DeviceListViewController: DroneDiscovererDelegate {
    func droneDiscoverer(_ droneDiscoverer: DroneDiscoverer!, didUpdateDronesList dronesList: [Any]!) {
        dataSource = dronesList
        tableView.reloadData()
    }
}
