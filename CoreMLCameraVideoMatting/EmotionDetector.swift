import CoreML
import Vision
import CoreImage
import UIKit

struct EmotionDetector {
    let model: Resnet50Emotions = {
        do {
            return try Resnet50Emotions(configuration:  MLModelConfiguration())
        } catch {
            print(error)
            fatalError("can't create model")
        }
    }()
    
    var sharedImage: BMSharedImage
    
    mutating func predict(src: CVPixelBuffer) {
//        let resultPixelBuffer = src.crop(to: CGRect(x: 248, y: 512, width: 224, height: 224))?.flip()
        let resizedSrc = resizePixelBuffer(src, width: 224, height: 224)!
        let rotatedSrc = rotate90PixelBuffer(resizedSrc, factor: 3)!
        let modelInput = Resnet50EmotionsInput(image: rotatedSrc)
        
        let modelOutput = try! model.prediction(input: modelInput)
        let topLabel = modelOutput.classLabelProbs.max(by: { $0.value < $1.value })
        DispatchQueue.main.sync {
            self.sharedImage.emotion = topLabel!.key
            self.sharedImage.emotionProbability = topLabel!.value
        }
    }
}

