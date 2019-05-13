import UIKit

class MiniDroneFlowViewController: UIViewController {
    private let stateSem: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    private var connectionAlertController: UIAlertController?
    private var miniDrone: MiniDrone?
    
    @IBOutlet weak var forward: UIImageView!
    @IBOutlet weak var backward: UIImageView!
    @IBOutlet weak var left: UIImageView!
    @IBOutlet weak var right: UIImageView!
    @IBOutlet weak var up: UIImageView!
    @IBOutlet weak var down: UIImageView!
    @IBOutlet weak var turnLeft: UIImageView!
    @IBOutlet weak var turnRight: UIImageView!
    
    enum direction {
        case forward
        case backward
        case left
        case right
        case up
        case down
        case turnLeft
        case turnRight
    }
    var dirSet : Set<direction> = []
    
    var points : Set<UITouch> = Set<UITouch>()
    var droneTimer : Timer?
    
    var service: ARService?
    
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var takeOffLandBt: UIButton!
    
    func debug(_ items: Any...) {
        print(items)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        miniDrone = MiniDrone(service: service)
        miniDrone?.delegate = self
        miniDrone?.connect()
        
        droneTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateMove), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if miniDrone?.connectionState() != ARCONTROLLER_DEVICE_STATE_RUNNING {
            connectionAlertController = UIAlertController(title: service?.name ?? "", message: "Connecting ...", preferredStyle: .alert)
            if let alertController = connectionAlertController {
                alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
                    alertController.dismiss(animated: true, completion: nil)
                    self.navigationController?.popViewController(animated: true)
                }))
                present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        connectionAlertController?.dismiss(animated: true, completion: nil)
        connectionAlertController = UIAlertController(title: service?.name ?? "", message: "Disconnecting ...", preferredStyle: .alert)
        if let connectionAlertController = connectionAlertController {
            present(connectionAlertController, animated: true, completion: nil)
        }
        
        // in background, disconnect from the drone
        DispatchQueue.global(qos: .default).async {
            self.miniDrone?.disconnect()
            
            // wait for the disconnection to appear
            let _ = self.stateSem.wait(timeout: .distantFuture)
            self.miniDrone = nil
            
            // dismiss the alert view in main thread
            DispatchQueue.main.async {
                self.connectionAlertController?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    @IBAction func emergencyClicked(_ sender: UIButton) {
        miniDrone?.emergency()
    }
    
    @IBAction func takeOffLandClicked(_ sender: UIButton) {
        if let miniDrone = miniDrone {
            switch miniDrone.flyingState() {
            case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
                miniDrone.takeOff()
            case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING,
                 ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
                miniDrone.land()
            default:
                break
            }
        }
    }
    
    @objc func updateMove() {
        dirSet.removeAll()
        for point in points {
            let pos = point.location(in: self.view)
            if forward.frame.contains(pos) {
                dirSet.insert(direction.forward)
            }
            if backward.frame.contains(pos) {
                dirSet.insert(direction.backward)
            }
            if right.frame.contains(pos) {
                dirSet.insert(direction.right)
            }
            if left.frame.contains(pos) {
                dirSet.insert(direction.left)
            }
            if up.frame.contains(pos) {
                dirSet.insert(direction.up)
            }
            if down.frame.contains(pos) {
                dirSet.insert(direction.down)
            }
            if turnRight.frame.contains(pos) {
                dirSet.insert(direction.turnRight)
            }
            if turnLeft.frame.contains(pos) {
                dirSet.insert(direction.turnLeft)
            }
        }
        changeDirection()
    }
    
    func changeDirection() {
        // Clear
        if dirSet.union([direction.forward, direction.backward]).count > 0 {
            miniDrone?.setFlag(0)
            miniDrone?.setPitch(0)
        }
        if dirSet.union([direction.right, direction.left]).count > 0 {
            miniDrone?.setFlag(0)
            miniDrone?.setRoll(0)
        }
        if dirSet.union([direction.down, direction.up]).count > 0 {
            miniDrone?.setGaz(0)
        }
        if dirSet.union([direction.turnLeft, direction.turnRight]).count > 0 {
            miniDrone?.setYaw(0)
        }
        
        // Move multiple directions
        if dirSet.contains(direction.forward) {
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(50)
        }
        if dirSet.contains(direction.backward) {
            miniDrone?.setFlag(1)
            miniDrone?.setPitch(-50)
        }
        if dirSet.contains(direction.right) {
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(50)
        }
        if dirSet.contains(direction.left) {
            miniDrone?.setFlag(1)
            miniDrone?.setRoll(-50)
        }
        if dirSet.contains(direction.up) {
            miniDrone?.setGaz(50)
        }
        if dirSet.contains(direction.down) {
            miniDrone?.setGaz(-50)
        }
        if dirSet.contains(direction.turnRight) {
            miniDrone?.setYaw(50)
        }
        if dirSet.contains(direction.turnLeft) {
            miniDrone?.setYaw(-50)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        points = points.union(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        points = points.union(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        points.subtract(touches)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        points.removeAll()
        dirSet.removeAll()
        changeDirection()
    }
}

extension MiniDroneFlowViewController: MiniDroneDelegate {
    func miniDrone(_ miniDrone: MiniDrone!, connectionDidChange state: eARCONTROLLER_DEVICE_STATE) {
        switch state {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            connectionAlertController?.dismiss(animated: true, completion: nil)
        case ARCONTROLLER_DEVICE_STATE_STOPPED:
            stateSem.signal()
            
            // Go back
            if let alertController = connectionAlertController {
                alertController.dismiss(animated: true, completion: {
                    self.navigationController?.popViewController(animated: true)
                })
            } else {
                navigationController?.popViewController(animated: true)
            }
        default:
            break
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, flyingStateDidChange state: eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE) {
        switch state {
        case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            takeOffLandBt.setImage(UIImage(named: "take_off"), for: .normal)
            takeOffLandBt.isEnabled = true
        case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING,
             ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            takeOffLandBt.setImage(UIImage(named: "landing"), for: .normal)
            takeOffLandBt.isEnabled = true
        default:
            takeOffLandBt.isEnabled = false
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, batteryDidChange batteryPercentage: Int32) {
        batteryLabel.text = String(format: "%d%%", batteryPercentage)
    }
}

