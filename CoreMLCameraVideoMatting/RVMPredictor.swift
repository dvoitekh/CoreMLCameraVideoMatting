import CoreML
import Vision
import CoreImage
import UIKit

struct RVMPredictor {
    let model: RVM = {
        do {
            return try RVM(configuration:  MLModelConfiguration())
        } catch {
            print(error)
            fatalError("can't create model")
        }
    }()
    
    var sharedImage: BMSharedImage
    var r1: MLMultiArray?
    var r2: MLMultiArray?
    var r3: MLMultiArray?
    var r4: MLMultiArray?
    
    mutating func predict(src: CVPixelBuffer) {
        let modelInput = RVMInput(src: src, r1i: r1, r2i: r2, r3i: r3, r4i: r4)
        
        let modelOutput = try! model.prediction(input: modelInput)
        
        r1 = modelOutput.r1o
        r2 = modelOutput.r2o
        r3 = modelOutput.r3o
        r4 = modelOutput.r4o
//        fgr is an RGB foreground image
        let fgrCGIImage = modelOutput.fgr.toCGImage()
//        pha mask is in grayscale! in order to display it properly we need to convert it to RGBA
        let phaCGIImage = modelOutput.pha.toBGRApixelBuffer()!.toCGImage()
//        UI updates have to performed from the main thread
        DispatchQueue.main.sync {
            self.sharedImage.fgr = UIImage(cgImage: fgrCGIImage)
            self.sharedImage.pha = UIImage(cgImage: phaCGIImage)
        }
    }
}

