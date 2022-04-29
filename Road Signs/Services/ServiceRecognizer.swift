import UIKit
import Vision
import CoreML

class ServiceRecognizer {
    
    private(set) var requests: [VNRequest] = []
    
    func setupVision(completion: @escaping ([VNObservation]?) -> ()) {
        // Setup Vision parts
        
        guard let modelURL = Bundle.main.url(forResource: "Model", withExtension: "mlmodelc") else {
            completion(nil)
            return
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        completion(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
    }
    
    
}
