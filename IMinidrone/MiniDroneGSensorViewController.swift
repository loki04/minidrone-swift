import UIKit
import CoreMotion
import CoreLocation

class MiniDroneGSensorViewController: UIViewController {
    private let UPDATE_INTERVAL = 0.1
    private let stateSem: DispatchSemaphore = DispatchSemaphore(value: 0)
    
    private var connectionAlertController: UIAlertController?
    private var miniDrone: MiniDrone?
    
    @IBOutlet weak var forward: UIImageView!
    @IBOutlet weak var backward: UIImageView!
    @IBOutlet weak var left: UIImageView!
    @IBOutlet weak var right: UIImageView!
    @IBOutlet weak var up: UIImageView!
    @IBOutlet weak var down: UIImageView!
    @IBOutlet weak var turn360: UIImageView!
    
    enum direction {
        case forward
        case backward
        case left
        case right
        case up
        case down
        case turnLeft
        case turnRight
        case turn
    }
    var dirSet : Set<direction> = []
    
    var points : Set<UITouch> = Set<UITouch>()
    var droneTimer : Timer?
    
    var motionManager = CMMotionManager()
    var locationManager = CLLocationManager()
    var headings : Array<Double> = []
    var headings_pos = -1
    let headings_length = 20
    var heading_turn = 0.0
    let heading_minvalue = 15.0
    
    var turns_curr : Double = 0.0
    var turns : Array<Double> = []
    var turns_pos = -1
    
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
        
        droneTimer = Timer.scheduledTimer(timeInterval: UPDATE_INTERVAL / 2, target: self, selector: #selector(updateMove), userInfo: nil, repeats: true)
        
        motionManager.accelerometerUpdateInterval = UPDATE_INTERVAL
        motionManager.startAccelerometerUpdates()
        
        for _ in 1...headings_length {
            headings.append(0.0)
            turns.append(0.0)
        }
        locationManager.startUpdatingHeading()
        
        self.view.addGestureRecognizer(XMCircleGestureRecognizer(midPoint: turn360.center, innerRadius: 10, outerRadius: 130, target: self, action: #selector(MiniDroneGSensorViewController.rotateGesture(recognizer:))))
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
        
        motionManager.stopAccelerometerUpdates()
        motionManager.stopMagnetometerUpdates()
        locationManager.stopUpdatingHeading()
        
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
    
    @objc func rotateGesture(recognizer:XMCircleGestureRecognizer)
    {
        turns_curr = 0
        if let angle = recognizer.angle {
            turns_curr = Double(angle.degrees)
        }
    }
    
    @objc func updateMove() {
        dirSet.removeAll()

        // Over images
        for point in points {
            let pos = point.location(in: self.view)

            if up.frame.contains(pos) {
                dirSet.insert(direction.up)
            }
            if down.frame.contains(pos) {
                dirSet.insert(direction.down)
            }
        }
        
        // Accelerometer (forward,backward,left,right)
        if let acc = motionManager.accelerometerData?.acceleration {
            if acc.x < -0.2 {
                dirSet.insert(direction.forward)
                forward.alpha = acc.x.alpha
            }
            if acc.x > 0.2 {
                dirSet.insert(direction.backward)
                backward.alpha = acc.x.alpha
            }
            if acc.y < -0.2 {
                dirSet.insert(direction.left)
                left.alpha = acc.y.alpha
            }
            if acc.y > 0.2 {
                dirSet.insert(direction.right)
                right.alpha = acc.y.alpha
            }

            // Land if there is a big Z move
            if abs(acc.z) > 3 {
                points.removeAll()
                dirSet.removeAll()
                miniDrone?.land();
            }
        }
        
        // Location heading
        if let h = locationManager.heading {
            //calcTurn(curr: h.magneticHeading, distance: -10, len: headings_length, pos: &headings_pos, array: &headings)
            
            let curr = h.magneticHeading
            headings_pos = (headings_pos + 1) % headings_length
            headings[headings_pos] = curr
            let prev = headings[(headings_length + headings_pos - 10) % headings_length]
            var diff = curr - prev
            if diff < -180 {
                diff = diff + 360
            } else if diff > 180 {
                diff = diff - 360
            }
            heading_turn = 0
            if abs(diff) > heading_minvalue {
                dirSet.insert(direction.turn)
                heading_turn = diff
            }
            
        }
        if heading_turn == 0 && turns_curr != 0 {
            //calcTurn(curr: turns_curr, distance: -5, len: headings_length, pos: &turns_pos, array: &turns)
            
            let curr = turns_curr
            turns_pos = (turns_pos + 1) % headings_length
            turns[turns_pos] = turns_curr
            let prev = turns[(headings_length + turns_pos - 5) % headings_length]
            if prev != 0 {
                var diff = curr - prev
                if diff < -180 {
                    diff = diff + 360
                } else if diff > 180 {
                    diff = diff - 360
                }
                heading_turn = 0
                if abs(diff) > heading_minvalue {
                    dirSet.insert(direction.turn)
                    heading_turn = diff
                }
            }
            
        }
        changeDirection()
    }
    
    func calcTurn(curr: Double, distance: Int, len: Int, pos: inout Int, array: inout Array<Double>) {
        pos = (pos + 1) % len
        array[pos] = curr
        let prev = array[(len + pos - distance) % len]
        if prev != 0 {
            var diff = curr - prev
            if diff < -180 {
                diff = diff + 360
            } else if diff > 180 {
                diff = diff - 360
            }
            heading_turn = 0
            if abs(diff) > heading_minvalue {
                dirSet.insert(direction.turn)
                heading_turn = diff
            }
        }
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
        if dirSet.union([direction.turnLeft, direction.turnRight, direction.turn]).count > 0 {
            miniDrone?.setYaw(0)
        }
        
        // Move multiple directions
        if let acc = motionManager.accelerometerData?.acceleration {
            if dirSet.contains(direction.forward) {
                miniDrone?.setFlag(1)
                miniDrone?.setPitch((acc.x * -50).droneMinMax)
            }
            if dirSet.contains(direction.backward) {
                miniDrone?.setFlag(1)
                miniDrone?.setPitch((acc.x * -50).droneMinMax)
            }
            if dirSet.contains(direction.right) {
                miniDrone?.setFlag(1)
                miniDrone?.setRoll((acc.y * 50).droneMinMax)
            }
            if dirSet.contains(direction.left) {
                miniDrone?.setFlag(1)
                miniDrone?.setRoll((acc.y * 50).droneMinMax)
            }
        }
        if dirSet.contains(direction.up) {
            miniDrone?.setGaz(50)
        }
        if dirSet.contains(direction.down) {
            miniDrone?.setGaz(-50)
        }
        if abs(heading_turn) > heading_minvalue {
            if dirSet.contains(direction.turn) {
                miniDrone?.setYaw(heading_turn.droneMinMax)
            }
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

extension MiniDroneGSensorViewController: MiniDroneDelegate {
    func miniDrone(_ miniDrone: MiniDrone!, connectionDidChange state: eARCONTROLLER_DEVICE_STATE) {
        switch state {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            connectionAlertController?.dismiss(animated: true, completion: nil)
        case ARCONTROLLER_DEVICE_STATE_STOPPED:
            stateSem.signal()
            
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

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    var alpha : CGFloat {
        return CGFloat(min(abs(self), 1))
    }
    var droneMinMax : Int8 {
        return Int8(max(min(self, 100),-100))
    }
}
