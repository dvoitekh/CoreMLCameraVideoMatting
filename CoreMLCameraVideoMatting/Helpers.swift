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
            .resizable()
            .aspectRatio(contentMode: .fill)
            .edgesIgnoringSafeArea(.all)
            .frame(maxWidth: UIScreen.main.bounds.width,
                   maxHeight: UIScreen.main.bounds.height)
//        Camera stream is rotated by 90 degrees on iOS device by default
            .rotationEffect(.degrees(resolveValueForPlatform(iOsValue: 90.0, macOsValue: 0.0)))
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
