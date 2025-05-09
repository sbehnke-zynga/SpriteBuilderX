//
//  FCFormatConverter.m
//  CocosBuilder
//
//  Created by Viktor on 6/27/13.
//
//

#import "FCFormatConverter.h"
#include "PVRTexLib.hpp"
#include "TextureConverter.h"

static FCFormatConverter* gDefaultConverter = NULL;

static NSString * kErrorDomain = @"com.apportable.SpriteBuilder";

struct KtxFormat {
    /// Constructor is only required when creating KTX images.
    KtxFormat() :
    endianness(0), glType(0), glTypeSize(0), glFormat(0), glInternalFormat(0),
    glBaseInternalFormat(0), pixelWidth(0), pixelHeight(0), pixelDepth(0),
    numberOfArrayElements(0), numberOfFaces(0), numberOfMipmapLevels(0), bytesOfKeyValueData(0) {
        
        // As per http://www.khronos.org/opengles/sdk/tools/KTX/file_format_spec/
        identifier[0]  = 0xAB;
        identifier[1]  = 0x4B;
        identifier[2]  = 0x54;
        identifier[3]  = 0x58;
        identifier[4]  = 0x20;
        identifier[5]  = 0x31;
        identifier[6]  = 0x31;
        identifier[7]  = 0xBB;
        identifier[8]  = 0x0D;
        identifier[9]  = 0x0A;
        identifier[10] = 0x1A;
        identifier[11] = 0x0A;
    }
    
    unsigned char identifier[12];
    uint32_t endianness;
    uint32_t glType;
    uint32_t glTypeSize;
    uint32_t glFormat;
    uint32_t glInternalFormat;
    uint32_t glBaseInternalFormat;
    uint32_t pixelWidth;
    uint32_t pixelHeight;
    uint32_t pixelDepth;
    uint32_t numberOfArrayElements;
    uint32_t numberOfFaces;
    uint32_t numberOfMipmapLevels;
    uint32_t bytesOfKeyValueData;
};

@interface FCFormatConverter ()

@property (nonatomic, strong) NSTask *pngQuantTask;
@property (nonatomic, strong) NSTask *zipTask;
@property (nonatomic, strong) NSTask *sndTask;
@property (nonatomic, strong) NSTask *webpTask;
@property (nonatomic, strong) NSTask *fbxTask;

@end

#define CC_SWAP( x, y )			\
({ __typeof__(x) temp  = (x);		\
x = y; y = temp;		\
})


static float clampf(float value, float min_inclusive, float max_inclusive)
{
    if (min_inclusive > max_inclusive) {
        CC_SWAP(min_inclusive,max_inclusive);
    }
    return value < min_inclusive ? min_inclusive : value < max_inclusive? value : max_inclusive;
}

@implementation FCFormatConverter

+ (FCFormatConverter*) defaultConverter
{
    if (!gDefaultConverter)
    {
        gDefaultConverter = [[FCFormatConverter alloc] init];
    }
    return gDefaultConverter;
}

- (NSString*) proposedNameForConvertedImageAtPath:(NSString*)srcPath format:(int)format compress:(BOOL)compress isSpriteSheet:(BOOL)isSpriteSheet
{
    if ( isSpriteSheet )
		{
		    // The name of a sprite in a spritesheet never changes.
		    return [srcPath copy];
		}
    if ( format == kFCImageFormatOriginal)
    {
        return [srcPath copy];
    }
    else if (format == kFCImageFormatPNG ||
             format == kFCImageFormatPNG_8BIT ||
             format == kFCImageFormatPNG_NO_ALPHA ||
             format == kFCImageFormatPNG_8BIT_NO_ALPHA)
    {
        // File might be loaded from a .psd file.
        return [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
    }
    else if (format == kFCImageFormatPVR_RGBA8888 ||
             format == kFCImageFormatPVR_RGBA4444 ||
             format == kFCImageFormatPVR_RGB888 ||
             format == kFCImageFormatPVR_RGB565 ||
             format == kFCImageFormatPVRTC_4BPP ||
             format == kFCImageFormatPVRTC_2BPP ||
             format == kFCImageFormatPVRTC2_4BPP ||
             format == kFCImageFormatPVRTC2_2BPP)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pvr"];
        if (compress) dstPath = [dstPath stringByAppendingPathExtension:@"ccz"];
        return dstPath;
    }
    else if (format == kFCImageFormatJPG)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
        return dstPath;
    }
    else if (format == kFCImageFormatWEBP ||
             format == kFCImageFormatWEBP_LOSSY ||
             format == kFCImageFormatWEBP_NO_ALPHA ||
             format == kFCImageFormatWEBP_LOSSY_NO_ALPHA)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"webp"];
        return dstPath;
    }
    else if (format == kFCImageFormatDXT1 ||
             format == kFCImageFormatDXT2 ||
             format == kFCImageFormatDXT3 ||
             format == kFCImageFormatDXT4 ||
             format == kFCImageFormatDXT5)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dds"];
        return dstPath;
    }
    else if (format == kFCImageFormatATC_RGB ||
             format == kFCImageFormatATC_EXPLICIT_ALPHA ||
             format == kFCImageFormatATC_INTERPOLATED_ALPHA ||
             format == kFCImageFormatETC ||
             format == kFCImageFormatETC_ALPHA ||
             format == kFCImageFormatETC2_RGB8 ||
             format == kFCImageFormatETC2_RGBA8 ||
             format == kFCImageFormatETC2_RGB8A1)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"ktx"];
        return dstPath;
    }
    return NULL;
}

-(BOOL)optimizePngAtPath:(NSString*)srcPath premultipliedAlpha:(BOOL)premultipliedAlpha error:(NSError**)error;
{

    NSTask *task = [[NSTask alloc] init];
    NSString *pathToPNGCrush = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"pngcrush"];
    [task setLaunchPath:pathToPNGCrush];
    if(premultipliedAlpha)
        [task setArguments:@[@"-force", @"-ow", @"-ztxt", @"b", @"premultiplied_alpha", @"true", srcPath]];
    else
        [task setArguments:@[@"-force", @"-ow", srcPath]];
    
    task.currentDirectoryPath = NSTemporaryDirectory();

    NSPipe *pipeErr = [NSPipe pipe];
    [task setStandardError:pipeErr];

    int status = 0;

    @try
    {
        [task launch];
        [task waitUntilExit];
        status = [task terminationStatus];
    }
    @catch (NSException *ex)
    {
        NSString * errorMessage = [NSString stringWithFormat:@"pngcrush error: %@ exception %@", srcPath, ex.reason];
        NSLog(@"%@",errorMessage);
        if (error)
        {
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        return NO;
    }

    if (status)
    {
        NSFileHandle *fileErr = [pipeErr fileHandleForReading];
        NSData *dataErr = [fileErr readDataToEndOfFile];
        NSString *stdErrStr = [[NSString alloc] initWithData:dataErr encoding:NSUTF8StringEncoding];
        
        NSString *errorMessage = [NSString stringWithFormat:@"pngcrush error: %@ err:%@", srcPath, stdErrStr];
        NSLog(@"%@", errorMessage);
        if (error)
        {
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        return NO;
        //[_warnings addWarningWithDescription:warningDescription];
    }
    return YES;
}

-(NSString*)compress:(NSString*)dstPath andDir:(NSString*)dstDir
{
    // Create compressed file (ccz)
    self.zipTask = [[NSTask alloc] init];
    [_zipTask setCurrentDirectoryPath:dstDir];
    [_zipTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ccz"]];
    NSMutableArray* args = [NSMutableArray arrayWithObjects:dstPath, nil];
    [_zipTask setArguments:args];
    [_zipTask launch];
    [_zipTask waitUntilExit];
    self.zipTask = nil;
    
    // Remove uncompressed file
    [[NSFileManager defaultManager] removeItemAtPath:dstPath error:NULL];
    
    // Update name of texture file
    dstPath = [dstPath stringByAppendingPathExtension:@"ccz"];
    return dstPath;
}

static BOOL saveRawDataToPng(void* data, int width, int height, BOOL hasAlpha, BOOL alpha, NSString *path, NSError **error)
{
    int sourceBytes = hasAlpha?4:3;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big|(CGBitmapInfo)((hasAlpha&&alpha)?kCGImageAlphaLast:kCGImageAlphaNone);
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, width*height*sourceBytes, NULL);
    CGImageRef imageRef = CGImageCreate(width, height, 8, 8*sourceBytes, sourceBytes*width, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGDataProviderRelease(provider);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    if (!destination) {
        if (error)
        {
            NSString * errorMessage = [NSString stringWithFormat:@"Failed to create CGImageDestination for: %@", path];
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        CGImageRelease(imageRef);
        return NO;
    }
    CGImageDestinationAddImage(destination, imageRef, nil);
    CGImageRelease(imageRef);
    
    if (!CGImageDestinationFinalize(destination)) {
        if (error)
        {
            NSString * errorMessage = [NSString stringWithFormat:@"Failed to write image to: %@", path];
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        CFRelease(destination);
        return NO;
    }
    
    CFRelease(destination);
    return YES;
}

typedef enum {
    kFCAlphaProcessingNone,
    kFCAlphaProcessingPremultiply,
    kFCAlphaProcessingDrop
} kFCAlphaProcessing;

static BOOL convertToPng(NSString *srcPath, NSString *dstPath, kFCAlphaProcessing alphaProcessing, NSError **error)
{
    if(alphaProcessing == kFCAlphaProcessingNone && [[srcPath pathExtension] isEqualToString:@"png"])
    {
        return YES;
    }
    NSImage * image = [[NSImage alloc] initWithContentsOfFile:srcPath];
    NSBitmapImageRep* rawImg = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
    if(alphaProcessing == kFCAlphaProcessingPremultiply && [rawImg hasAlpha])
    {
        auto RGBA8888 = PVRTGENPIXELID4('r', 'g', 'b', 'a', 8, 8, 8, 8);
        pvrtexlib::PVRTextureHeader header(RGBA8888, image.size.width, image.size.height);
        pvrtexlib::PVRTexture     * pvrTexture = new pvrtexlib::PVRTexture(header, rawImg.bitmapData);
        
        if(!pvrTexture->GetTextureIsPreMultiplied())
        {
            if (error)
            {
                NSString * errorMessage = [NSString stringWithFormat:@"Failure to premultiple alpha: %@", srcPath];
                NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
                *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
            }
            delete pvrTexture;
            return NO;
        }
        BOOL ret = saveRawDataToPng(pvrTexture->GetTextureDataPointer(), rawImg.pixelsWide, rawImg.pixelsHigh, [rawImg hasAlpha], YES, dstPath, error);
        delete pvrTexture;
        return ret;
    }
    else
    {
        return saveRawDataToPng(rawImg.bitmapData, rawImg.pixelsWide, rawImg.pixelsHigh, [rawImg hasAlpha], alphaProcessing != kFCAlphaProcessingDrop, dstPath, error);
    }
}

static void replacebytes(const char* path, long offset, const char * newBytes, long len)
{
    FILE* f = fopen(path, "r+b"); // Error checking omitted
    fseek(f, offset, SEEK_SET);
    fwrite(newBytes, len, 1, f);
    fclose(f);
}

-(BOOL)convertImageAtPath:(NSString*)srcPath
                   format:(int)format
                  quality:(int)quality
                   dither:(BOOL)dither
                 compress:(BOOL)compress
            isSpriteSheet:(BOOL)isSpriteSheet
                isRelease:(BOOL)isRelease
           outputFilename:(NSString**)outputFilename
                    error:(NSError**)error;
{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* dstDir = [srcPath stringByDeletingLastPathComponent];
    
    // Convert PSD to PNG as a pre-step.
    // Unless the .psd is part of a spritesheet, then the original name has to be preserved.
    if ( [[srcPath pathExtension] isEqualToString:@"psd"] && !isSpriteSheet)
    {
        CGImageSourceRef image_source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:srcPath], NULL);
        CGImageRef image = CGImageSourceCreateImageAtIndex(image_source, 0, NULL);

        NSString *out_path = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
        CFURLRef out_url = (__bridge CFURLRef)[NSURL fileURLWithPath:out_path];
        CGImageDestinationRef image_destination = CGImageDestinationCreateWithURL(out_url, kUTTypePNG, 1, NULL);
        CGImageDestinationAddImage(image_destination, image, NULL);
        CGImageDestinationFinalize(image_destination);

        CFRelease(image_source);
        CGImageRelease(image);
        CFRelease(image_destination);

        [fm removeItemAtPath:srcPath error:nil];
        srcPath = out_path;
    }
		
    if ( format == kFCImageFormatOriginal)
    {
        *outputFilename = [srcPath copy];
        return YES;
    }
    else if (format == kFCImageFormatPNG ||
             format == kFCImageFormatPNG_8BIT ||
             format == kFCImageFormatPNG_NO_ALPHA ||
             format == kFCImageFormatPNG_8BIT_NO_ALPHA)
    {
        // PNG image - no conversion required
        //*outputFilename = [srcPath copy];
        BOOL dropAlpha = format == kFCImageFormatPNG_NO_ALPHA || format == kFCImageFormatPNG_8BIT_NO_ALPHA;
        BOOL convertTo8Bit = format == kFCImageFormatPNG_8BIT || format == kFCImageFormatPNG_8BIT_NO_ALPHA;
        
        kFCAlphaProcessing alphaProcessing = kFCAlphaProcessingNone;
        if(dropAlpha)
            alphaProcessing = kFCAlphaProcessingDrop;
        else if(isRelease)
            alphaProcessing = kFCAlphaProcessingPremultiply;
        
         NSString *out_path = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
        
        if(!convertToPng(srcPath, out_path, alphaProcessing, error))
            return NO;
        
        if(convertTo8Bit)
        {
            self.pngQuantTask = [[NSTask alloc] init];
            [_pngQuantTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"pngquant"]];
            NSMutableArray* args = [NSMutableArray arrayWithObjects: @"--force", @"--ext", @".png", out_path, nil];
            [_pngQuantTask setArguments:args];
            [_pngQuantTask launch];
            [_pngQuantTask waitUntilExit];
            
            self.pngQuantTask = nil;
        }
        
        if(isRelease)
        {
            if(![self optimizePngAtPath:srcPath premultipliedAlpha:YES error:error])
                return NO;
        }
        
        *outputFilename = [out_path copy];
        return YES;
    }
    else if (format == kFCImageFormatPVR_RGBA8888 ||
             format == kFCImageFormatPVR_RGBA4444 ||
             format == kFCImageFormatPVR_RGB888 ||
             format == kFCImageFormatPVR_RGB565 ||
             format == kFCImageFormatPVRTC_4BPP ||
             format == kFCImageFormatPVRTC_2BPP ||
             format == kFCImageFormatPVRTC2_4BPP ||
             format == kFCImageFormatPVRTC2_2BPP)
    {
        // PVR(TC) image
        NSString *dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pvr"];

        PVRTuint64 pixelType;
        PVRTexLibVariableType variableType = PVRTLVT_UnsignedByteNorm;
        
        if (format == kFCImageFormatPVR_RGBA8888)
        {
            pixelType = PVRTGENPIXELID4('r', 'g', 'b', 'a', 8, 8, 8, 8);
        }
        else if (format == kFCImageFormatPVR_RGBA4444)
        {
            pixelType = PVRTGENPIXELID4('r', 'g', 'b', 'a', 4, 4, 4, 4);
            variableType = PVRTLVT_UnsignedShortNorm;
        }
        else if (format == kFCImageFormatPVR_RGB888)
        {
            pixelType = PVRTGENPIXELID4('r', 'g', 'b', 0, 8, 8, 8, 0);
        }
        else if (format == kFCImageFormatPVR_RGB565)
        {
            pixelType = PVRTGENPIXELID4('r', 'g', 'b', 0, 8, 5, 6, 0);
            variableType = PVRTLVT_UnsignedShortNorm;
        }
        else if (format == kFCImageFormatPVRTC_4BPP)
        {
            pixelType = PVRTLPF_PVRTCI_4bpp_RGBA;
        }
        else if (format == kFCImageFormatPVRTC_2BPP)
        {
            pixelType = PVRTLPF_PVRTCI_2bpp_RGBA;
        }
        else if (format == kFCImageFormatPVRTC2_4BPP)
        {
            pixelType = PVRTLPF_PVRTCII_4bpp;
        }
        else if (format == kFCImageFormatPVRTC2_2BPP)
        {
            pixelType = PVRTLPF_PVRTCII_2bpp;
        }

        NSImage * image = [[NSImage alloc] initWithContentsOfFile:srcPath];
        NSBitmapImageRep* rawImg = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
        
        auto RGBA8888 = PVRTGENPIXELID4('r', 'g', 'b', 'a', 8, 8, 8, 8);
        pvrtexlib::PVRTextureHeader header(RGBA8888, image.size.width, image.size.height);
        pvrtexlib::PVRTexture     * pvrTexture = new pvrtexlib::PVRTexture(header, rawImg.bitmapData);
        
        bool hasError = NO;
      
        if(!pvrTexture->GetTextureIsPreMultiplied())
        {
            if (error)
			{
				NSString * errorMessage = [NSString stringWithFormat:@"Failure to premultiple alpha: %@", srcPath];
				NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
				*error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
			}
            hasError = YES;
        }
       
        if(!hasError && !pvrTexture->Transcode(pixelType, variableType, PVRTLCS_sRGB, isRelease?PVRTexLibCompressorQuality::PVRTLCQ_PVRTCBest:PVRTexLibCompressorQuality::PVRTLCQ_PVRTCFast, dither))
        {
            if (error)
            {
                NSString * errorMessage = [NSString stringWithFormat:@"Failure to transcode image: %@", srcPath];
                NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
                *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
            }
            hasError = YES;
        }
        
        if(!hasError)
        {
            
            std::string filePath([dstPath UTF8String], dstPath.length);
            
            if(!pvrTexture->SaveToFile(filePath))
            {
				if (error)
				{
					NSString * errorMessage = [NSString stringWithFormat:@"Failure to save image: %@", dstPath];
					NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
					*error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
				}
                hasError = YES;
            }
        }
        
        // Remove PNG file
        [[NSFileManager defaultManager] removeItemAtPath:srcPath error:NULL];
        //Clean up memory.
        delete pvrTexture;
        
        if(hasError)
        {
            return NO;//return failure;
        }
        
        if (compress)
        {
            dstPath = [self compress:dstPath andDir:dstDir];
        }
        
        if ([fm fileExistsAtPath:dstPath])
        {
            *outputFilename = [dstPath copy];
            return YES;
        }
    }
    else if (format == kFCImageFormatJPG)
    {
        // JPG image format
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
        
        // Set the compression factor
        float compressionFactor = clampf(quality / 100.0f, 0.f, 100.0f);
        
        NSDictionary* props = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor];
        
        // Convert the file
        NSBitmapImageRep* imageRep = (NSBitmapImageRep*)[NSBitmapImageRep imageRepWithContentsOfFile:srcPath];
        NSData* imgData = [imageRep representationUsingType:NSJPEGFileType properties:props];
        
        if (![imgData writeToFile:dstPath atomically:YES]) return NULL;
        
        // Remove old file
        if (![srcPath isEqualToString:dstPath])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }
        
        *outputFilename = [dstPath copy];
        return YES;
        
    }
    else if (format == kFCImageFormatWEBP ||
             format == kFCImageFormatWEBP_LOSSY ||
             format == kFCImageFormatWEBP_NO_ALPHA ||
             format == kFCImageFormatWEBP_LOSSY_NO_ALPHA)
    {
        // WEBP image format
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"webp"];
        
        self.webpTask = [[NSTask alloc] init];
        [_webpTask setCurrentDirectoryPath:dstDir];
        [_webpTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"cwebp"]];
        NSMutableArray* args = nil;
        switch (format) {
            case kFCImageFormatWEBP:
                args = [NSMutableArray arrayWithObjects:srcPath, @"-lossless", @"-alpha_cleanup", @"-o", dstPath, nil];
                break;
                
            case kFCImageFormatWEBP_LOSSY:
                args = [NSMutableArray arrayWithObjects:srcPath, @"-q", [@(quality) stringValue], @"-alpha_cleanup", @"-o", dstPath, nil];
                break;
                
            case kFCImageFormatWEBP_NO_ALPHA:
                args = [NSMutableArray arrayWithObjects:srcPath, @"-lossless", @"-noalpha", @"-o", dstPath, nil];
                break;
                
            case kFCImageFormatWEBP_LOSSY_NO_ALPHA:
                args = [NSMutableArray arrayWithObjects:srcPath, @"-q", [@(quality) stringValue], @"-noalpha", @"-o", dstPath, nil];
                break;
                
            default:
                break;
        }
        [_webpTask setArguments:args];
        [_webpTask launch];
        [_webpTask waitUntilExit];
        self.webpTask = nil;
        
        // Remove uncompressed file
        [[NSFileManager defaultManager] removeItemAtPath:srcPath error:NULL];
        
        *outputFilename = [dstPath copy];
        return YES;
    }
    
    else if (format == kFCImageFormatDXT1 ||
             format == kFCImageFormatDXT2 ||
             format == kFCImageFormatDXT3 ||
             format == kFCImageFormatDXT4 ||
             format == kFCImageFormatDXT5)
    {
        // DDS image format
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dds"];
        NSString* tmpPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"tmp.png"];
        
        if(format == kFCImageFormatDXT2 || format == kFCImageFormatDXT4)
        {
            if(!convertToPng(srcPath, tmpPath, kFCAlphaProcessingPremultiply, error))
                return NO;
        }
        else
        {
            tmpPath = srcPath;
        }

        self.webpTask = [[NSTask alloc] init];
        [_webpTask setCurrentDirectoryPath:dstDir];
        [_webpTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"nvcompress"]];
        NSMutableArray* args = nil;
        switch (format) {
            case kFCImageFormatDXT1:
                args = [NSMutableArray arrayWithObjects:@"-nomips", @"-alpha", @"-bc1", tmpPath, dstPath, nil];
                break;
            
            case kFCImageFormatDXT2:
            case kFCImageFormatDXT3:
                args = [NSMutableArray arrayWithObjects:@"-nomips", @"-alpha", @"-bc2", tmpPath, dstPath, nil];
                break;
                
            case kFCImageFormatDXT4:
            case kFCImageFormatDXT5:
                args = [NSMutableArray arrayWithObjects:@"-nomips", @"-alpha", @"-bc3", tmpPath, dstPath, nil];
                break;
                
            default:
                break;
        }
        [_webpTask setArguments:args];
        [_webpTask launch];
        [_webpTask waitUntilExit];
        self.webpTask = nil;
        
        if(format == kFCImageFormatDXT2)
            replacebytes([dstPath UTF8String], 84, "DXT2", 4);
        if(format == kFCImageFormatDXT4)
            replacebytes([dstPath UTF8String], 84, "DXT4", 4);
        
        // Remove uncompressed file
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
        if(![tmpPath isEqualToString:srcPath])
            [[NSFileManager defaultManager] removeItemAtPath:srcPath error:NULL];
        
        if (compress)
        {
            dstPath = [self compress:dstPath andDir:dstDir];
        }
        
        *outputFilename = [dstPath copy];
        return YES;
    }
    else if (format == kFCImageFormatATC_RGB ||
             format == kFCImageFormatATC_EXPLICIT_ALPHA ||
             format == kFCImageFormatATC_INTERPOLATED_ALPHA ||
             format == kFCImageFormatETC ||
             format == kFCImageFormatETC_ALPHA ||
             format == kFCImageFormatETC2_RGB8 ||
             format == kFCImageFormatETC2_RGBA8 ||
             format == kFCImageFormatETC2_RGB8A1)
    {
        NSString* dstPath = [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"ktx"];
        
        NSImage * image = [[NSImage alloc] initWithContentsOfFile:srcPath];
        NSBitmapImageRep* rawImg = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
        
        TQonvertImage qualcommTextureInput;
        
        TFormatFlags inputFormatFlags;
        qualcommTextureInput.pFormatFlags = &inputFormatFlags;
        memset(qualcommTextureInput.pFormatFlags, 0, sizeof(TFormatFlags));
        
        qualcommTextureInput.nWidth     = image.size.width;
        qualcommTextureInput.nHeight    = image.size.height;
        qualcommTextureInput.nFormat    = Q_FORMAT_RGBA_8UI;
        qualcommTextureInput.nDataSize  = image.size.height * image.size.width * 4;
        qualcommTextureInput.pFormatFlags->nFlipY       = 0;
        if(format == kFCImageFormatETC ||
           format == kFCImageFormatETC_ALPHA ||
           format == kFCImageFormatETC2_RGB8 ||
           format == kFCImageFormatETC2_RGBA8 ||
           format == kFCImageFormatETC2_RGB8A1)
        {
            qualcommTextureInput.pFormatFlags->nMaskRed     = 0x0000FF;
            qualcommTextureInput.pFormatFlags->nMaskGreen   = 0x00FF00;
            qualcommTextureInput.pFormatFlags->nMaskBlue    = 0xFF0000;
        }
        else
        {
            qualcommTextureInput.pFormatFlags->nMaskRed     = 0xFF0000;
            qualcommTextureInput.pFormatFlags->nMaskGreen   = 0x00FF00;
            qualcommTextureInput.pFormatFlags->nMaskBlue    = 0x0000FF;
        }

        NSMutableData *data = nil;
        (void)data;
        
        if(format == kFCImageFormatATC_EXPLICIT_ALPHA ||
           format == kFCImageFormatATC_INTERPOLATED_ALPHA ||
           format == kFCImageFormatETC_ALPHA ||
           format == kFCImageFormatETC2_RGBA8 ||
           format == kFCImageFormatETC2_RGB8A1)
        {
            NSImage * image = [[NSImage alloc] initWithContentsOfFile:srcPath];
            NSBitmapImageRep* rawImg = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
            
            auto RGBA8888 = PVRTGENPIXELID4('r', 'g', 'b', 'a', 8, 8, 8, 8);
            pvrtexlib::PVRTextureHeader header(RGBA8888, image.size.width, image.size.height);
            pvrtexlib::PVRTexture pvrTexture(header , rawImg.bitmapData);
            
            if(!pvrTexture.GetTextureIsPreMultiplied())
            {
                if (error)
                {
                    NSString * errorMessage = [NSString stringWithFormat:@"Failure to premultiple alpha: %@", srcPath];
                    NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
                    *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
                }
                return NO;
            }
            
            NSLog(@"Texture %@", srcPath);
            NSUInteger dataLen = image.size.height * image.size.width * 4;
            if(format == kFCImageFormatETC_ALPHA)
            {
                data = [[NSMutableData alloc] initWithLength:dataLen * 2];
                memcpy(data.mutableBytes, pvrTexture.GetTextureDataPointer(), dataLen);
                PVRTexLibChannelName szChannel[3] = { PVRTLCN_Red, PVRTLCN_Green, PVRTLCN_Blue};
                PVRTexLibChannelName szChannelSource[3] = { PVRTLCN_Red, PVRTLCN_Green, PVRTLCN_Blue};
                pvrTexture.CopyChannels(pvrTexture, 3, szChannel, szChannelSource);
                memcpy((unsigned char*)data.mutableBytes + dataLen, pvrTexture.GetTextureDataPointer(), dataLen);
                qualcommTextureInput.nHeight *= 2;
                //saveRawDataToPng(data.mutableBytes, image.size.width, image.size.height * 2, NO, [srcPath stringByAppendingPathExtension:@"png"], nil);
            }
            else
            {
                data = [[NSMutableData alloc] initWithLength:dataLen];
                memcpy(data.mutableBytes, pvrTexture.GetTextureDataPointer(), dataLen);
            }

            qualcommTextureInput.pData                      = (unsigned char*)data.mutableBytes;
        }
        else
        {
            qualcommTextureInput.pData                      = (unsigned char*) rawImg.bitmapData;
        }
        
        TQonvertImage qualcommTextureOutput;
        TFormatFlags outputFormatFlags;
        qualcommTextureOutput.pFormatFlags = &outputFormatFlags;
        memset(qualcommTextureOutput.pFormatFlags, 0, sizeof(TFormatFlags));
        
        qualcommTextureOutput.nWidth    = qualcommTextureInput.nWidth;
        qualcommTextureOutput.nHeight   = qualcommTextureInput.nHeight;
        switch (format) {
            case kFCImageFormatATC_RGB:
                qualcommTextureOutput.nFormat = Q_FORMAT_ATC_RGB;
                break;
            case kFCImageFormatATC_EXPLICIT_ALPHA:
                qualcommTextureOutput.nFormat = Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA;
                break;
            case kFCImageFormatATC_INTERPOLATED_ALPHA:
                qualcommTextureOutput.nFormat = Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA;
                break;
            case kFCImageFormatETC:
                qualcommTextureOutput.nFormat = Q_FORMAT_ETC1_RGB8;
                break;
            case kFCImageFormatETC_ALPHA:
                qualcommTextureOutput.nFormat = Q_FORMAT_ETC1_RGB8;
                break;
            case kFCImageFormatETC2_RGB8:
                qualcommTextureOutput.nFormat = Q_FORMAT_ETC2_RGB8;
                break;
            case kFCImageFormatETC2_RGBA8:
                qualcommTextureOutput.nFormat = Q_FORMAT_ETC2_RGBA8;
                break;
            case kFCImageFormatETC2_RGB8A1:
                qualcommTextureOutput.nFormat = Q_FORMAT_ETC2_RGB8_PUNCHTHROUGH_ALPHA1;
                break;
            default:
                break;
        }
        qualcommTextureOutput.nDataSize = 0;
        qualcommTextureOutput.pData     = NULL;
        
        if(Qonvert(&qualcommTextureInput, &qualcommTextureOutput) != Q_SUCCESS) {
            if(error)
            {
                NSString * errorMessage = [NSString stringWithFormat:@"The first Qonvert call failed: %@", srcPath];
                NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
                *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
            }
            return NO;
        }
        qualcommTextureOutput.pData = (unsigned char*) malloc(qualcommTextureOutput.nDataSize);
        
        if(Qonvert(&qualcommTextureInput, &qualcommTextureOutput) != Q_SUCCESS) {
            if(error)
            {
                NSString * errorMessage = [NSString stringWithFormat:@"The second Qonvert call failed: %@", srcPath];
                NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
                *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
            }
            free(qualcommTextureOutput.pData);
            return NO;
        }
        
        // http://www.khronos.org/registry/gles/extensions/AMD/AMD_compressed_ATC_texture.txt
        
        KtxFormat ktx;
        ktx.pixelWidth           = qualcommTextureInput.nWidth;
        ktx.pixelHeight          = qualcommTextureInput.nHeight;
        ktx.pixelDepth           = 32;
        ktx.numberOfMipmapLevels = 1;
        
        switch(qualcommTextureOutput.nFormat) {
            case Q_FORMAT_ATITC_RGB:
                ktx.glInternalFormat = 0x8C92; // ATC_RGB_AMD
                break;
            case Q_FORMAT_ATC_RGBA_EXPLICIT_ALPHA:
                ktx.glInternalFormat = 0x8C93; // ATC_RGBA_EXPLICIT_ALPHA_AMD
                break;
            case Q_FORMAT_ATC_RGBA_INTERPOLATED_ALPHA:
                ktx.glInternalFormat = 0x87EE; // ATC_RGBA_INTERPOLATED_ALPHA_AMD
                break;
            case Q_FORMAT_ETC1_RGB8:
                ktx.glInternalFormat = 0x8D64; // CC_GL_ETC1_RGB8_OES
                break;
            case Q_FORMAT_ETC2_RGB8:
                ktx.glInternalFormat = 0x9274; // CC_GL_COMPRESSED_RGB8_ETC2
                break;
            case Q_FORMAT_ETC2_RGBA8:
                ktx.glInternalFormat = 0x9278; // CC_GL_COMPRESSED_RGBA8_ETC2_EAC
                break;
            case Q_FORMAT_ETC2_RGB8_PUNCHTHROUGH_ALPHA1:
                ktx.glInternalFormat = 0x9276; // CC_GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2
                break;

            default:
                break;
        }
        
        FILE* out = fopen([dstPath UTF8String], "w");
        
        if(format == kFCImageFormatETC_ALPHA)
        {
            // Write metadata data:
            const char *key = "alpha";
            const char *value = "down";
            int keyLen = strlen(key) + 1;
            int valueLen = strlen(value) + 1;
            uint32_t keyAndValueLen = keyLen + valueLen;
            uint8_t padding[4] = {'\0', '\0', '\0', '\0'};
            ktx.bytesOfKeyValueData = ((keyLen + valueLen + 3)/4)*4 + 4;
            // Write the header:
            fwrite((void*) &ktx, 1, sizeof(KtxFormat), out);
            fwrite(&keyAndValueLen, 1, 4, out);
            fwrite(key, 1, keyLen, out);
            fwrite(value, 1, valueLen, out);
            if(keyAndValueLen + 4 < ktx.bytesOfKeyValueData)
                fwrite(padding, 1, ktx.bytesOfKeyValueData - 4 - keyAndValueLen, out);
        }
        else
        {
            // Write the header:
            fwrite((void*) &ktx, 1, sizeof(KtxFormat), out);
        }
        
        // Write the data size:
        fwrite((void*) &(qualcommTextureOutput.nDataSize), 1, sizeof(unsigned int), out);
        
        // Write actual data:
        fwrite(qualcommTextureOutput.pData, 1, qualcommTextureOutput.nDataSize, out);
        
        fclose(out);
        
        // Remove uncompressed file
        [[NSFileManager defaultManager] removeItemAtPath:srcPath error:NULL];
        
        if (compress)
        {
            dstPath = [self compress:dstPath andDir:dstDir];
        }
        
        *outputFilename = [dstPath copy];
        
        return YES;
        
    }
    
	// Conversion failed
	if(error != nil)
	{
		*error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:@{NSLocalizedDescriptionKey:@"Unhandled format"}];
	}
	
	return NO;
}

- (NSString*) proposedNameForConvertedSoundAtPath:(NSString*)srcPath format:(int)format quality:(int)quality
{
    NSString* ext = NULL;
    if (format == kFCSoundFormatWAV) ext = @"wav";
    else if (format == kFCSoundFormatCAF) ext = @"caf";
    else if (format == kFCSoundFormatMP4) ext = @"m4a";
    else if (format == kFCSoundFormatOGG) ext = @"ogg";
    else if (format == kFCSoundFormatMP3) ext = @"mp3";
    
    if (ext)
    {
        return [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
    }
    return NULL;
}

- (NSString*) proposedNameForConvertedModelAtPath:(NSString*)srcPath
{
    NSString* ext = @"c3b";
    if (ext)
    {
        return [[srcPath stringByDeletingPathExtension] stringByAppendingPathExtension:ext];
    }
    return NULL;
}

- (NSString*) afconvertDataFormatWithQuality:(int)quality prefix8Bit:(NSString*)prefix8Bit prefix16Bit:(NSString*)prefix16Bit
{
    switch (quality) {
        case 1:
            return [NSString stringWithFormat:@"%@@%@", prefix8Bit, @"11025"];
        case 2:
            return [NSString stringWithFormat:@"%@@%@", prefix8Bit, @"22050"];
        case 3:
            return [NSString stringWithFormat:@"%@@%@", prefix8Bit, @"32000"];
        case 4:
            return [NSString stringWithFormat:@"%@@%@", prefix8Bit, @"41000"];
        case 5:
            return [NSString stringWithFormat:@"%@@%@", prefix8Bit, @"48000"];
            
        case 6:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"11025"];
        case 7:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"22050"];
        case 8:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"32000"];
        case 9:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"44100"];
        case 10:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"48000"];
        
        default:
            return [NSString stringWithFormat:@"%@@%@", prefix16Bit, @"22050"];
    }
}

- (NSString*) convertSoundAtPath:(NSString*)srcPath format:(int)format quality:(int)quality stereo:(BOOL)stereo;
{
    NSString* dstPath = [self proposedNameForConvertedSoundAtPath:srcPath format:format quality:quality];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    if (format == kFCSoundFormatWAV)
    {
        // Convert to WAV
        _sndTask = [[NSTask alloc] init];
        
        NSString *qualityString = [self afconvertDataFormatWithQuality:quality prefix8Bit:@"UI8" prefix16Bit:@"LEI16"];
        
        [_sndTask setLaunchPath:@"/usr/bin/afconvert"];
        NSMutableArray* args = [NSMutableArray arrayWithObjects:
                                @"-f", @"WAVE",
                                @"-d", qualityString, nil];
        if(!stereo)
        {
            [args addObject:@"-c"];
            [args addObject:@"1"];
        }
        [args addObject:srcPath];
        [args addObject:dstPath];
        
        [_sndTask setArguments:args];
        [_sndTask launch];
        [_sndTask waitUntilExit];
        
        
        // Remove old file
        if (![srcPath isEqualToString:dstPath])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }
        
        return dstPath;
    }
    else if (format == kFCSoundFormatCAF)
    {
        // Convert to CAF
        self.sndTask = [[NSTask alloc] init];
        
        NSString *qualityString = [self afconvertDataFormatWithQuality:quality prefix8Bit:@"I8" prefix16Bit:@"LEI16"];
        
        [_sndTask setLaunchPath:@"/usr/bin/afconvert"];
        NSMutableArray* args = [NSMutableArray arrayWithObjects:
                                @"-f", @"caff",
                                @"-d", qualityString, nil];
        if(!stereo)
        {
            [args addObject:@"-c"];
            [args addObject:@"1"];
        }
        [args addObject:srcPath];
        [args addObject:dstPath];
        
        [_sndTask setArguments:args];
        [_sndTask launch];
        [_sndTask waitUntilExit];

        // Remove old file
        if (![srcPath isEqualToString:dstPath])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }

        self.sndTask = nil;
        return dstPath;
    }
    else if (format == kFCSoundFormatMP4)
    {
        // Convert to AAC
        
        //default value
        if(quality == -1)
            quality = 3;
        
        int qualityScaled = ((quality -1) * 127) / 9;//Quality [1,10]
        
        // Do the conversion
        self.sndTask = [[NSTask alloc] init];
        
        [_sndTask setLaunchPath:@"/usr/bin/afconvert"];
        NSMutableArray* args = [NSMutableArray arrayWithObjects:
                                @"-f", @"m4af",
                                @"-d", @"aac",
                                @"-u", @"pgcm", @"2",
                                @"-u", @"vbrq", [NSString stringWithFormat:@"%i",qualityScaled],
                                @"-q", @"127",
                                @"-s", @"3", nil];
        if(!stereo)
        {
            [args addObject:@"-c"];
            [args addObject:@"1"];
        }
        [args addObject:srcPath];
        [args addObject:dstPath];
        
        [_sndTask setArguments:args];
        [_sndTask launch];
        [_sndTask waitUntilExit];

        // Remove old file
        if (![srcPath isEqualToString:dstPath])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }

        self.sndTask = nil;
        return dstPath;
    }
    else if (format == kFCSoundFormatOGG)
    {
        // Convert to OGG

        if ([srcPath isEqualToString:dstPath])
        {
            // oggenc can't convert things in place, so make a copy that will get deleted at the end
            NSString *newSrcPath = [srcPath stringByAppendingPathExtension:@"orig"];
            [fm moveItemAtPath:srcPath toPath:newSrcPath error:NULL];
            srcPath = newSrcPath;
        }
        
        //default value
        if(quality == -1)
            quality = 3;

        self.sndTask = [[NSTask alloc] init];
        NSString *temp = [NSString stringWithFormat:@"%@.temp",dstPath];
        [_sndTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"oggenc"]];
        NSMutableArray* args = [NSMutableArray arrayWithObjects:
                                [NSString stringWithFormat:@"-q%d", quality], nil];
        if(!stereo)
            [args addObject:@"--downmix"];
        [args addObject:@"-o"];
        [args addObject:temp];
        [args addObject:srcPath];
        
        [_sndTask setArguments:args];
        [_sndTask launch];
        [_sndTask waitUntilExit];

        // Remove old file
        if (![srcPath isEqualToString:temp])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }
        
        [fm moveItemAtPath:temp toPath:dstPath error:nil];

        self.sndTask = nil;
        return dstPath;
    }
    else if (format == kFCSoundFormatMP3)
    {
        // Convert to MP3
        
        if ([srcPath isEqualToString:dstPath])
        {
            // oggenc can't convert things in place, so make a copy that will get deleted at the end
            NSString *newSrcPath = [srcPath stringByAppendingPathExtension:@"orig"];
            [fm moveItemAtPath:srcPath toPath:newSrcPath error:NULL];
            srcPath = newSrcPath;
        }
        
        //default value
        if(quality == -1)
            quality = 4;
        
        self.sndTask = [[NSTask alloc] init];
        NSString *temp = [NSString stringWithFormat:@"%@.temp",dstPath];
        [_sndTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"lame"]];
        NSMutableArray* args = [NSMutableArray arrayWithObjects:
                                @"-h",
                                [NSString stringWithFormat:@"-V%d", quality],
                                stereo?@"":@"-a",
                                srcPath, temp,
                                nil];
        [_sndTask setArguments:args];
        [_sndTask launch];
        [_sndTask waitUntilExit];
        
        // Remove old file
        if (![srcPath isEqualToString:temp])
        {
            [fm removeItemAtPath:srcPath error:NULL];
        }
        
        [fm moveItemAtPath:temp toPath:dstPath error:nil];
        
        self.sndTask = nil;
        return dstPath;
    }
    
    return NULL;
}

- (NSString*) convertModelAtPath:(NSString*)srcPath format:(int)format skip_normals:(BOOL)skip_normals error:(NSError**)error
{
    NSString* dstPath = [self proposedNameForConvertedModelAtPath:srcPath];
    NSFileManager* fm = [NSFileManager defaultManager];
    
    self.fbxTask = [[NSTask alloc] init];
    [_fbxTask setLaunchPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"fbx-conv"]];
    NSMutableArray* args = [NSMutableArray arrayWithObjects:
                            [NSString stringWithFormat:@"-b"], nil];
    
    if(format == kFCSoundFormatMesh)
        [args addObject:@"-l"];
    if(format == kFCSoundFormatAnimation)
        [args addObject:@"-j"];
    if(!skip_normals)
        [args addObject:@"-p"];
    
    [args addObject:srcPath];
    
    NSPipe *pipeErr = [NSPipe pipe];
    [_fbxTask setStandardError:pipeErr];
    
    int status = 0;
    
    @try
    {
        [_fbxTask setArguments:args];
        [_fbxTask launch];
        [_fbxTask waitUntilExit];
        status = [_fbxTask terminationStatus];
    }
    @catch (NSException *ex)
    {
        NSString * errorMessage = [NSString stringWithFormat:@"fbx-conv error: %@ exception %@", srcPath, ex.reason];
        NSLog(@"%@",errorMessage);
        if (error)
        {
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        return nil;
    }
    
    if (status)
    {
        NSFileHandle *fileErr = [pipeErr fileHandleForReading];
        NSData *dataErr = [fileErr readDataToEndOfFile];
        NSString *stdErrStr = [[NSString alloc] initWithData:dataErr encoding:NSUTF8StringEncoding];
            
        NSString *errorMessage = [NSString stringWithFormat:@"fbx-conv error: %@ err:%@", srcPath, stdErrStr];
        NSLog(@"%@", errorMessage);
        if (error)
        {
            NSDictionary * userInfo __attribute__((unused)) =@{NSLocalizedDescriptionKey:errorMessage};
            *error = [NSError errorWithDomain:kErrorDomain code:EPERM userInfo:userInfo];
        }
        return nil;
    }
    
    // Remove old file
    if (![srcPath isEqualToString:dstPath])
    {
        [fm removeItemAtPath:srcPath error:NULL];
    }
    
    self.sndTask = nil;
    return dstPath;
}

- (void)cancel
{
    @try
    {
        [_pngQuantTask terminate];
        [_zipTask terminate];
        [_sndTask  terminate];
        [_fbxTask  terminate];

        self.pngQuantTask = nil;
        self.zipTask = nil;
        self.sndTask = nil;
        self.fbxTask = nil;
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception: %@", exception);
    }
}

@end
