import AVFoundation
import Vision
import UIKit

protocol SignRecognizerManagerDelegate: AnyObject {
    func recognized(observations: [VNObservation]?, image: UIImage?)
}


class SignRecognizerManager: NSObject {
    let serviceRecognizer: ServiceRecognizer
    let captureService: CaptureService
    private var image: UIImage?
    
    weak var delegate: SignRecognizerManagerDelegate?
    
    init(serviceRecognizer: ServiceRecognizer, captureService: CaptureService) {
        self.serviceRecognizer = serviceRecognizer
        self.captureService = captureService
        
    }
    
    
    func setup() {
        captureService.videoOutputDeelgate = self
        captureService.createAVCaptureSession()
        serviceRecognizer.setupVision(completion: { [weak self] result in
            self?.delegate?.recognized(observations: result, image: self?.image)
        })
        captureService.session.startRunning()
    }
    
    
    private func checkAccessToCameraThenSetupAVCapture() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
            self.setup()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.setup()
                        }
                    }
                }
            case .denied:
                return
            case .restricted:
                return
        @unknown default:
            fatalError()
        }
    }
}


extension SignRecognizerManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        self.image = UIImage(pixelBuffer: pixelBuffer)
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(serviceRecognizer.requests)
        } catch {
            print(error)
        }
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}
