import UIKit
import AVFoundation

class CaptureService {
    
    private(set) var session = AVCaptureSession()
    private(set) var videoDevice : AVCaptureDevice? = nil
    private(set) var bufferSize: CGSize = .zero
    private(set) var photoOutput = AVCapturePhotoOutput()

    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    let videoDataOutput: AVCaptureVideoDataOutput
    
    weak var videoOutputDeelgate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    init(videoDataOutput: AVCaptureVideoDataOutput) {
        self.videoDataOutput = videoDataOutput
    }
    
    func createAVCaptureSession() {
        
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera], mediaType: .video, position: .back).devices.first else { return  }
        var deviceInput: AVCaptureDeviceInput!
        
        
        // Select a video device, make an input
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
        }
        
        self.videoDevice = videoDevice
        
        session.beginConfiguration()
        session.sessionPreset = .hd4K3840x2160 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return 
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            session.addOutput(photoOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(videoOutputDeelgate, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        session.sessionPreset = .inputPriority
    }
}
