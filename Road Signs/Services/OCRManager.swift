import Foundation
import UIKit
import Vision

class OCRManager {
    
    var request = VNRecognizeTextRequest(completionHandler: nil)
    
    func setupVisionTextRecognizeImage(image:UIImage?, completion: @escaping (String)->()) {
        var textString = ""
        request = VNRecognizeTextRequest(completionHandler: { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    print("No candidates")
                    continue
                }
                textString += topCandidate.string
                DispatchQueue.main.async {
                    completion(textString)
                }
            }
        })
        
        request.customWords = ["custOm"]
        request.minimumTextHeight = 0.03125
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en_US"]
        request.usesLanguageCorrection = true
        
        let request = [request]
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = image?.cgImage else { return print("Missing image to scan") }
            let handle = VNImageRequestHandler(cgImage: img, options: [:])
            try? handle.perform(request)
        }
    }
}
