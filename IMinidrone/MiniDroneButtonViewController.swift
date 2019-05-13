import UIKit

class MiniDroneButtonViewController: UIViewController {
    private let stateSem: DispatchSemaphore = DispatchSemaphore(value: 0)

    private var connectionAlertController: UIAlertController?
    private var downloadAlertController: UIAlertController?
    private var downloadProgressView: UIProgressView?
    private var miniDrone: MiniDrone?
    private var nbMaxDownload = 0
    private var currentDownloadIndex = 0 // from 1 to nbMaxDownload

    var service: ARService?

    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var takeOffLandBt: UIButton!

    @IBOutlet weak var yawLabel: UILabel!
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var downButton: UIButton!

    @IBOutlet weak var rollLabel: UILabel!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        miniDrone = MiniDrone(service: service)
        miniDrone?.delegate = self
        miniDrone?.connect()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        yawLabel.text = "yaw"
        upButton.setTitle("up", for: .normal)
        downButton.setTitle("down", for: .normal)
        rollLabel.text = "roll"
        forwardButton.setTitle("forward", for: .normal)
        backButton.setTitle("back", for: .normal)
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
    
    @IBAction func gazUpTouchDown(_ sender: UIButton) {
        miniDrone?.setGaz(50)
    }
    
    @IBAction func gazDownTouchDown(_ sender: UIButton) {
        miniDrone?.setGaz(-50)
    }

    @IBAction func gazUpTouchUp(_ sender: UIButton) {
        miniDrone?.setGaz(0)
    }

    @IBAction func gazDownTouchUp(_ sender: UIButton) {
        miniDrone?.setGaz(0)
    }

    @IBAction func yawLeftTouchDown(_ sender: UIButton) {
        miniDrone?.setYaw(-50)
    }
    
    @IBAction func yawRightTouchDown(_ sender: UIButton) {
        miniDrone?.setYaw(50)
    }

    @IBAction func yawLeftTouchUp(_ sender: UIButton) {
        miniDrone?.setYaw(0)
    }

    @IBAction func yawRightTouchUp(_ sender: UIButton) {
        miniDrone?.setYaw(0)
    }
    
    @IBAction func rollLeftTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(-50)
    }

    @IBAction func rollRightTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setRoll(50)
    }
    
    @IBAction func rollLeftTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setRoll(0)
    }

    @IBAction func rollRightTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setRoll(0)
    }

    @IBAction func pitchForwardTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setPitch(50)
    }

    @IBAction func pitchBackTouchDown(_ sender: UIButton) {
        miniDrone?.setFlag(1)
        miniDrone?.setPitch(-50)
    }

    @IBAction func pitchForwardTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setPitch(0)
    }

    @IBAction func pitchBackTouchUp(_ sender: UIButton) {
        miniDrone?.setFlag(0)
        miniDrone?.setPitch(0)
    }
}

extension MiniDroneButtonViewController: MiniDroneDelegate {
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
            takeOffLandBt.setTitle("Take off", for: .normal)
            takeOffLandBt.isEnabled = true
        case ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING,
             ARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            takeOffLandBt.setTitle("Land", for: .normal)
            takeOffLandBt.isEnabled = true
        default:
            takeOffLandBt.isEnabled = false
        }
    }

    func miniDrone(_ miniDrone: MiniDrone!, batteryDidChange batteryPercentage: Int32) {
        batteryLabel.text = String(format: "%d%%", batteryPercentage)
    }

    func miniDrone(_ miniDrone: MiniDrone!, configureDecoder codec: ARCONTROLLER_Stream_Codec_t) -> Bool {
        return false
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, didReceive frame: UnsafeMutablePointer<ARCONTROLLER_Frame_t>!) -> Bool {
        return false
    }

    func miniDrone(_ miniDrone: MiniDrone!, didFoundMatchingMedias nbMedias: UInt) {
        nbMaxDownload = Int(nbMedias)
        currentDownloadIndex = 1
        
        if nbMedias > 0 {
            downloadAlertController?.message = "Downloading medias"
            
            let customVC = UIViewController()
            downloadProgressView = UIProgressView(progressViewStyle: .default)
            if let downloadProgressView = downloadProgressView {
                downloadProgressView.progress = 0
                customVC.view.addSubview(downloadProgressView)
                customVC.view.addConstraint(NSLayoutConstraint(item: downloadProgressView,
                                                               attribute: .centerX,
                                                               relatedBy: .equal,
                                                               toItem: customVC.view,
                                                               attribute: .centerX,
                                                               multiplier: 1,
                                                               constant: 0))
                customVC.view.addConstraint(NSLayoutConstraint(item: downloadProgressView,
                                                               attribute: .bottom,
                                                               relatedBy: .equal,
                                                               toItem: customVC.view.safeAreaLayoutGuide.bottomAnchor,
                                                               attribute: .top,
                                                               multiplier: 1,
                                                               constant: -20))
                
                downloadAlertController?.setValue(customVC, forKey: "contentViewController")
            }
        } else {
            downloadAlertController?.dismiss(animated: true, completion: {
                self.downloadProgressView = nil
                self.downloadAlertController = nil
            })
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, media mediaName: String!, downloadDidProgress progress: Int32) {
        let completedProgress = Float(currentDownloadIndex - 1) / Float(nbMaxDownload)
        let currentProgress = Float(progress) / 100 / Float(nbMaxDownload)
        downloadProgressView?.progress = completedProgress + currentProgress
    }

    func miniDrone(_ miniDrone: MiniDrone!, mediaDownloadDidFinish mediaName: String!) {
        currentDownloadIndex += 1
        
        if currentDownloadIndex > nbMaxDownload {
            downloadAlertController?.dismiss(animated: true, completion: {
                self.downloadProgressView = nil
                self.downloadAlertController = nil
            })
        }
    }
    
    func miniDrone(_ miniDrone: MiniDrone!, speedChanged speedX: Float, y speedY: Float, z speedZ: Float) {
        speedLabel.text = String(format: "x:%@%.1fm/s y:%@%.1fm/s z:%@%.1fm/s",
                                 speedX < 0 ? "" : "+", (speedX * 10).rounded(.toNearestOrAwayFromZero) / 10,
                                 speedY < 0 ? "" : "+", (speedY * 10).rounded(.toNearestOrAwayFromZero) / 10,
                                 speedZ < 0 ? "" : "+", (speedZ * 10).rounded(.toNearestOrAwayFromZero) / 10)
    }
}
