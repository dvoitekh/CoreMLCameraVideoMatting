import SwiftUI
import Vision

//Background Matting Image Container
//ObservableObject enables usage within SwiftUI views
//@Published makes Swift track changes to the corresponding property and trigger view reloads
class BMSharedImage: ObservableObject {
//    foreground RGB image
    @Published var fgr: UIImage?
//    background RGBA image
    @Published var pha: UIImage?
    
    @Published var emotion: String = "neutral"
    @Published var emotionProbability: Double = 1.0
}

//Some features work differently on MacOS and iOS
//Therefore, we might need to apply some platform-specific settings
func resolveValueForPlatform<T>(iOsValue: T, macOsValue: T) -> T {
    #if os(OSX)
    return macOsValue
    #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        return macOsValue
        #else
        return iOsValue
        #endif
    #else
    return iOsValue
    #endif
}

//Transform device video buffer into CVPixelBuffer
func getPixelBufferFromSampleBuffer(buffer:CMSampleBuffer) -> CVPixelBuffer? {
    if let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) {
      return pixelBuffer
    }
    return nil
}

extension Image {
//    Prettify the Image for the UI page
    func normalize() -> some View {
        return self.resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: UIScreen.main.bounds.width,
                   height: UIScreen.main.bounds.height / 2)
//        Camera stream is rotated by 90 degrees on iOS device by default
            .rotationEffect(.degrees(resolveValueForPlatform(iOsValue: 90.0, macOsValue: 0.0)))
            .padding(.bottom, 200)
    }
}

extension CVPixelBuffer {
//    Transform pixel buffer into CGImage
    func toCGImage() -> CGImage {
        let ciImage = CIImage(cvPixelBuffer: self)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: CGRect(x: 0,y: 0,width: CVPixelBufferGetWidth(self),height: CVPixelBufferGetHeight(self)))!
    }

//    Create BGRA pixel buffer (we need it to transform grayscale pha into BGRA pixel buffer)
    func toBGRApixelBuffer() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let frameSize = CGSize(width: width, height: height)

        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        if status != kCVReturnSuccess {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        context!.draw(self.toCGImage(), in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}

//extension CVPixelBuffer {
//    func crop(to rect: CGRect) -> CVPixelBuffer? {
//        CVPixelBufferLockBaseAddress(self, .readOnly)
//        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
//
//        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
//            return nil
//        }
//
//        let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
//
//        let imageChannels = 4
//        let startPos = Int(rect.origin.y) * inputImageRowBytes + imageChannels * Int(rect.origin.x)
//        let outWidth = UInt(rect.width)
//        let outHeight = UInt(rect.height)
//        let croppedImageRowBytes = Int(outWidth) * imageChannels
//
//        var inBuffer = vImage_Buffer()
//        inBuffer.height = outHeight
//        inBuffer.width = outWidth
//        inBuffer.rowBytes = inputImageRowBytes
//
//        inBuffer.data = baseAddress + UnsafeMutableRawPointer.Stride(startPos)
//
//        guard let croppedImageBytes = malloc(Int(outHeight) * croppedImageRowBytes) else {
//            return nil
//        }
//
//        var outBuffer = vImage_Buffer(data: croppedImageBytes, height: outHeight, width: outWidth, rowBytes: croppedImageRowBytes)
//
//        let scaleError = vImageScale_ARGB8888(&inBuffer, &outBuffer, nil, vImage_Flags(0))
//
//        guard scaleError == kvImageNoError else {
//            free(croppedImageBytes)
//            return nil
//        }
//
//        return croppedImageBytes.toCVPixelBuffer(pixelBuffer: self, targetWith: Int(outWidth), targetHeight: Int(outHeight), targetImageRowBytes: croppedImageRowBytes)
//    }
//
//    func flip() -> CVPixelBuffer? {
//        CVPixelBufferLockBaseAddress(self, .readOnly)
//        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
//
//        guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
//            return nil
//        }
//
//        let width = UInt(CVPixelBufferGetWidth(self))
//        let height = UInt(CVPixelBufferGetHeight(self))
//        let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
//        let outputImageRowBytes = inputImageRowBytes
//
//        var inBuffer = vImage_Buffer(
//            data: baseAddress,
//            height: height,
//            width: width,
//            rowBytes: inputImageRowBytes)
//
//        guard let targetImageBytes = malloc(Int(height) * outputImageRowBytes) else {
//            return nil
//        }
//        var outBuffer = vImage_Buffer(data: targetImageBytes, height: height, width: width, rowBytes: outputImageRowBytes)
//
//        // See https://developer.apple.com/documentation/accelerate/vimage/vimage_operations/image_reflection for other transformations
//        let reflectError = vImageHorizontalReflect_ARGB8888(&inBuffer, &outBuffer, vImage_Flags(0))
//        // let reflectError = vImageVerticalReflect_ARGB8888(&inBuffer, &outBuffer, vImage_Flags(0))
//
//        guard reflectError == kvImageNoError else {
//            free(targetImageBytes)
//            return nil
//        }
//
//        return targetImageBytes.toCVPixelBuffer(pixelBuffer: self, targetWith: Int(width), targetHeight: Int(height), targetImageRowBytes: outputImageRowBytes)
//    }
//}
//
//extension UnsafeMutableRawPointer {
//    // Converts the vImage buffer to CVPixelBuffer
//    func toCVPixelBuffer(pixelBuffer: CVPixelBuffer, targetWith: Int, targetHeight: Int, targetImageRowBytes: Int) -> CVPixelBuffer? {
//        let pixelBufferType = CVPixelBufferGetPixelFormatType(pixelBuffer)
//        let releaseCallBack: CVPixelBufferReleaseBytesCallback = {mutablePointer, pointer in
//            if let pointer = pointer {
//                free(UnsafeMutableRawPointer(mutating: pointer))
//            }
//        }
//
//        var targetPixelBuffer: CVPixelBuffer?
//        let conversionStatus = CVPixelBufferCreateWithBytes(nil, targetWith, targetHeight, pixelBufferType, self, targetImageRowBytes, releaseCallBack, nil, nil, &targetPixelBuffer)
//
//        guard conversionStatus == kCVReturnSuccess else {
//            free(self)
//            return nil
//        }
//
//        return targetPixelBuffer
//    }
//}
