import UIKit
import CoreML
import Vision
import AVFoundation
import VideoToolbox
import CoreLocation

class ViewController: UIViewController {
    
    let signRecongnizerManager = SignRecognizerManager(serviceRecognizer: .init(), captureService: .init(videoDataOutput: .init()))
    let ocrManager = OCRManager()
    let locationService = ServiceLocation()
    
    lazy var mainView: MainView! = {
        return self.view as! MainView
    }()
    
    var lastRecognizedSpeedLimitTimeOfRecognition = Date()
    var roadSignsRecognizedDuringLastHalfOfSecond = [(String, Date)]()
    var currentSpeed: Int = 0
    var currentSpeedLimit: Int = 60
    private var detectionOverlay: CALayer! = nil
    private var requests = [VNRequest]()
    var image: UIImage?
    var photoOutput = AVCapturePhotoOutput()
    var bufferSize: CGSize {self.signRecongnizerManager.captureService.bufferSize}
    var rootLayer: CALayer! = nil
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    var objectBounds = [CGRect]()
    var currentImageFromPixelBuffer = UIImage()
    let locationManager = CLLocationManager()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    override func loadView() {
        view = MainView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationService.setupAuthorization()
        locationService.speedDelegate = self
        signRecongnizerManager.delegate = self
        signRecongnizerManager.setup()
        previewLayer = .init(session: signRecongnizerManager.captureService.session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        rootLayer = view.layer
        setupLayers()
        updateLayerGeometry()
        
        view.layer.insertSublayer(previewLayer, at: 0)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer.frame = view.layer.bounds
    }

    func showAlert(_ msg: String) {
        let avc = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        avc.addAction(UIAlertAction(title: "Continue", style: .cancel, handler: nil))
        self.show(avc, sender: nil)
    }
    
    func checkCurrentSpeedAndSpeedLimit() {
        if currentSpeed > currentSpeedLimit {
            self.mainView.currentSpeedLabel.textColor = UIColor.red
            self.mainView.kilometersPerHourLabel.textColor = UIColor.red
        } else {
            self.mainView.currentSpeedLabel.textColor = .white
            self.mainView.kilometersPerHourLabel.textColor = .white
        }
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)"))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.width - 10, height: bounds.size.height - 10)
        textLayer.position = CGPoint(x: bounds.midX + 10, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 1.0, 1.0])
        textLayer.contentsScale = 2.0
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func cutoutDetectedMarkFromImage(image: UIImage, bounds: CGRect) -> UIImage {
        var newBounds = CGRect()
        newBounds.size.width = bounds.size.width
        newBounds.size.height = bounds.size.height
        newBounds.origin.x = bounds.origin.x
        newBounds.origin.y = image.size.height - bounds.origin.y - bounds.size.height
        
        let cgImage = self.fixOrientation(img: image).cgImage?.cropping(to: newBounds)
        guard let resultCGImage = cgImage else { return UIImage() }
        var resultImage = UIImage(cgImage: resultCGImage)
        resultImage = resultImage.rotate(radians: .pi / 2)!
        return resultImage
    }
    
    func fixOrientation(img: UIImage) -> UIImage {
        if (img.imageOrientation == .up) {
            return img
        }

        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        img.draw(in: rect)

        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return normalizedImage
    }
}

extension ViewController {
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            let topLabelObservation = objectObservation.labels[0]
            if topLabelObservation.confidence >= 0.9 {
                
                if objectObservation.boundingBox.width > 0.05 && objectObservation.boundingBox.height > 0.05 {
                    let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
                    
                    if (!objectBounds.width.isNaN && objectBounds.width != 0 && topLabelObservation.identifier == "speedlimit") {
                        
                        ocrManager.setupVisionTextRecognizeImage(image: self.cutoutDetectedMarkFromImage(image: currentImageFromPixelBuffer, bounds: objectBounds)) { [weak self] recognizedString in
                            guard let self = self else { return }
                            print("-------------------" + recognizedString)
                            var recognizedStringWithZeros = recognizedString.replacingOccurrences(of: "O", with: "0", options: .literal, range: nil) // replace all letters O in recognized string with number 0
                            recognizedStringWithZeros = recognizedStringWithZeros.replacingOccurrences(of: "o", with: "0", options: .literal, range: nil) // replace all letters o in recognized string with number 0
                            if recognizedStringWithZeros.count > 1 && Array(recognizedStringWithZeros)[1] != "2" {
                                recognizedStringWithZeros = recognizedStringWithZeros.replace(1, "0") // replace second character with 0 if it's not set to "2"
                            }
                            if recognizedStringWithZeros.count <= 1 {
                                recognizedStringWithZeros.append("0") // add "0" if string length is less than 2
                            }
                            if Array(recognizedStringWithZeros).count > 2 {
                                recognizedStringWithZeros = recognizedStringWithZeros.replace(2, "0") // replace third character with 0
                            }
                            while recognizedStringWithZeros.count > 3 {
                                recognizedStringWithZeros.removeLast() // fit string length to maximum 3 symbols
                            }
                            if let imageFromAssets = UIImage(named: recognizedStringWithZeros) { // if there is speed limit with this number in the library
                                if (self.lastRecognizedSpeedLimitTimeOfRecognition.timeIntervalSinceNow * -1 >= 1 || Int(recognizedStringWithZeros)! >= self.currentSpeedLimit) { // check if there's single speed limit and if not, select larger speed limit of two
                                    self.lastRecognizedSpeedLimitTimeOfRecognition = Date() // set time of last recognition of speed limit
                                    self.currentSpeedLimit = Int(recognizedStringWithZeros)! // set current speed limit
                                    DispatchQueue.main.async {
                                        self.mainView.speedLimitImageView.image = imageFromAssets
                                        self.checkCurrentSpeedAndSpeedLimit()
                                    }
                                }
                            }
                        }
                    } else {
                        self.setCurrentRoadSign(signTitle: topLabelObservation.identifier)
                    }
                    
                    let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                    let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                                        identifier: topLabelObservation.identifier)
                    shapeLayer.addSublayer(textLayer)
                    
                    detectionOverlay.addSublayer(shapeLayer)
                }
            }
        }
        CATransaction.commit()
    }
    
    func setCurrentRoadSign(signTitle: String) {
        var roadSignForLastHalfOfSecondWithRemovedOldSigns = [(String, Date)]() // array, which contains speed limits recognized during last 0.5 seconds
        for (sign, time) in self.roadSignsRecognizedDuringLastHalfOfSecond {
            if signTitle == sign && time.timeIntervalSinceNow * -1 < 0.5 { // check if there's one more recognition of this sign in last 0.5 second
                self.mainView.currentRoadSignImageView.image = UIImage(named: signTitle) // update current road
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(removeCurrentSignImageView), object: nil) // ignore previous remove road sign image view method
                perform(#selector(removeCurrentSignImageView), with: nil, afterDelay: 5) // remove current road sign image view in 0.5 seconds
            }
            if (time.timeIntervalSinceNow * -1 < 0.5) { // check if road sign was recognized during last 0.5 seconds
                roadSignForLastHalfOfSecondWithRemovedOldSigns.append((sign, time))
            }
        }
        roadSignForLastHalfOfSecondWithRemovedOldSigns.append((signTitle, Date())) // append last recognized road sign
        self.roadSignsRecognizedDuringLastHalfOfSecond = roadSignForLastHalfOfSecondWithRemovedOldSigns // update array of recognized road signs for last 0.5 seconds
    }
    
    @objc func removeCurrentSignImageView() {
        self.mainView.currentRoadSignImageView.image = UIImage()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint (x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
}

// MARK: - CLLocationManagerDelegate

extension ViewController: ServiceLocationDelegate {
    func didUpdateCurrentSpeed(speed: Double) {
        if speed <= 0.5 {
            self.currentSpeed = 0
            self.mainView.currentSpeedLabel.text = "0"
            self.checkCurrentSpeedAndSpeedLimit()
            return
        }
        
        self.mainView.currentSpeedLabel.text = String(Int(speed))
        self.currentSpeed = Int(speed)
        self.checkCurrentSpeedAndSpeedLimit()
        
    }
}

extension ViewController: SignRecognizerManagerDelegate {
    func recognized(observations: [VNObservation]?, image: UIImage?) {
        guard let observations = observations else {
            return
        }
        if let image = image {
            currentImageFromPixelBuffer = image
        }
        drawVisionRequestResults(observations)
    }
}
