
#import "TexturePackerCommandLine.h"
#import "FCFormatConverter.h"
#import "FCFormatConverter.h"
#import "MaxRectsBinPack.h"
#import "vector"

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CGImage.h>

#import "pvrtc.h"
#import <CommonCrypto/CommonDigest.h>


@interface TexturePackerCommandLine ()
@property (nonatomic, strong) FCFormatConverter *formatConverter;
@end

@implementation TexturePackerCommandLine {
}

@synthesize imageFormat;
@synthesize shape_padding;
@synthesize border_padding;
@synthesize extrude;
@synthesize disableRotateSprite;
@synthesize errorMessage;
@synthesize multipack;
@synthesize max_width;
@synthesize max_height;

void runOnMainQueueWithoutDeadlocking(void (^block)(void))
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (TexturePackerCommandLine*) texturePacker
{
    return [[TexturePackerCommandLine alloc] init];
}

- (id)init
{
    if ((self = [super init]))
    {
        imageFormat = 4;
        multipack = NO;
        max_width = 0;
        max_height = 0;
    }
    return self;
}


- (void)setErrorMessage:(NSString *)em
{
    if (em != errorMessage)
    {
        errorMessage = em;
    }
}

+ (VersionInfo)getTexturePackerVersion {
    VersionInfo ver;
    NSString *TexturePackerAppPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"TexturePacker"];
    NSString *texturePackerPath = [TexturePackerAppPath stringByAppendingPathComponent:@"Contents/MacOS/TexturePacker"];
    
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"--version", nil];
    NSPipe *outputPipe = [NSPipe pipe];
    
    NSTask *texturePackerTask = [[NSTask alloc] init];
    [texturePackerTask setLaunchPath:texturePackerPath];
    [texturePackerTask setStandardOutput:outputPipe];
    [texturePackerTask setArguments:args];
    [texturePackerTask launch];
    [texturePackerTask waitUntilExit];
    
    NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
    NSData *outputData = [outputHandle readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    
    NSArray<NSString *> *components = [outputString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (components && [components count] > 1) {
        NSString *binaryName = [components objectAtIndex:0];
        NSString *version = [components objectAtIndex:1];
        
        if ([binaryName isEqualToString:@"TexturePacker"]) {
            NSArray<NSString *> *versionComponents = [version componentsSeparatedByString:@"."];
            if (versionComponents && [versionComponents count] == 3) {
                ver.major = [[versionComponents objectAtIndex:0] intValue];
                ver.minor = [[versionComponents objectAtIndex:1] intValue];
                ver.build = [[versionComponents objectAtIndex:2] intValue];
            }
        }
    }
    
    return ver;
}

-(void)createTextureSheet:(NSMutableArray *)absoluteFilePaths publishDirectory:(NSString*) publishDirectory spriteSheetFile:(NSString *)spriteSheetFile projectSettings:(ProjectSettings *)projectSettings
{
    
    VersionInfo version = [TexturePackerCommandLine getTexturePackerVersion];
    bool supportedVersion = false;
    
    supportedVersion |= version == VersionInfo{3, 3, 4}; // 3.3.4
    supportedVersion |= version == VersionInfo{7, 4, 0}; // 7.4.0
    
    if (!supportedVersion) {
        // Warning unsupported version.
        static bool shouldAlert = true;
        if (shouldAlert) {
            shouldAlert = false;
            
            runOnMainQueueWithoutDeadlocking(^{
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"Texture Packer Error"];
                [alert setInformativeText:[NSString stringWithFormat:@"Unsupported version of Texture Packer: %s", version.to_string().c_str()]];
                [alert addButtonWithTitle:@"Ok"];
                [alert runModal];
            });
        } else {
            NSLog(@"Unsupported version of Texture Packer: %s", version.to_string().c_str());
        }
    }
    
    // first copy the files in the resource auto folder to tmp
    NSString *outputFolder = [spriteSheetFile stringByDeletingLastPathComponent];
    NSString *masterPlistFile = [spriteSheetFile stringByAppendingPathExtension:@"plist"];
    NSString *TexturePackerAppPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:@"TexturePacker"];
    // get path name
    
    NSString *targetName = [publishDirectory lastPathComponent];
    // copy files to the temp path
    NSString *tmpPath = [projectSettings tempSpriteSheetCacheDirectory];

    
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:tmpPath error:nil];

    
    tmpPath = [tmpPath stringByAppendingPathComponent:targetName];

    [fm createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:NULL error:NULL];

    publishDirectory = [publishDirectory stringByAppendingPathComponent:@"resources-auto"];

    NSString *relativePath =publishDirectory;
    
    NSArray* files = [fm contentsOfDirectoryAtPath:relativePath error:NULL];

    
    for (NSString* file in files)
    {
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"png"])
        {
            NSString *sourceFile = [publishDirectory stringByAppendingPathComponent:file];
            NSString *destFile = [tmpPath stringByAppendingPathComponent:file];
            
            [fm copyItemAtPath:sourceFile toPath:destFile error:nil];
        }
    }
    
    
    NSString *texturePackerPath = [TexturePackerAppPath stringByAppendingPathComponent:@"Contents/MacOS/TexturePacker"];
        
    NSTask *texturePackerTask = [[NSTask alloc] init];
    [texturePackerTask setCurrentDirectoryPath:tmpPath];
    [texturePackerTask setLaunchPath:texturePackerPath];
    
    if (multipack)
    {
        spriteSheetFile = [NSString stringWithFormat: @"%@{n}", spriteSheetFile];
    }
    
    NSString *pListFilename  = [spriteSheetFile stringByAppendingPathExtension:@"plist"];
    
    NSMutableArray* args = [NSMutableArray arrayWithObjects: @"--data",pListFilename,nil];
    [args addObject:@"--algorithm"];
    [args addObject:@"MaxRects"];
    
    [args addObject:@"--maxrects-heuristics"];
    [args addObject:@"Best"];
    
    if (multipack)
    {
        [args addObject:@"--multipack"];
    }
    
    if (max_width == 0)
    {
        max_width = 2048;
    }
    
    [args addObject:@"--max-width"];
    NSString* maxWidthValue = [NSString stringWithFormat:@"%i", max_width];
    [args addObject:maxWidthValue];
    
    if (max_height == 0)
    {
        max_height = 2048;
    }
    
    [args addObject:@"--max-height"];
    NSString* maxHeightValue = [NSString stringWithFormat:@"%i", max_height];
    [args addObject:maxHeightValue];
    
    [args addObject:@"--pack-mode"];
    [args addObject:@"Best"];
    if(extrude > 0)
    {
        [args addObject:@"--extrude"];
        NSString* extrudeValue = [NSString stringWithFormat:@"%i", extrude];
        [args addObject:extrudeValue];
    }
    
    // set trim mode
    [args addObject:@"--trim-mode"];
    [args addObject:@"Trim"];
    
    // set border padding
    [args addObject:@"--border-padding"];
    NSString* borderPaddingValue = [NSString stringWithFormat:@"%i", border_padding];
    [args addObject:borderPaddingValue];
    
    // set shape padding
    [args addObject:@"--shape-padding"];
    NSString* shapePaddingValue = [NSString stringWithFormat:@"%i", shape_padding];
    [args addObject:shapePaddingValue];
    
    // disable texturepacker sprite rotation via setting
    if(disableRotateSprite){
        [args addObject:@"--disable-rotation"];
    }else{
        [args addObject:@"--enable-rotation"];
    }
    // set Dithering to floydsteinbergalpha
    [args addObject:@"--dither-fs-alpha"];
    
    // force power of two
    [args addObject:@"--size-constraints"];
    [args addObject:@"POT"];
    
    [args addObject:@"--scale"];
    [args addObject:@"0.5"];
    
    NSString *pTextureName = spriteSheetFile;
    
    [args addObject:@"--opt"];
    switch(imageFormat)
    {
        case 0: // PNG
            [args addObject:@"RGBA8888"];
            pTextureName = [spriteSheetFile stringByAppendingPathExtension:@"png"];
            break;
        case 2: // PVR RGBA8888 - PMA
            [args addObject:@"RGBA8888"];
            pTextureName = [spriteSheetFile stringByAppendingPathExtension:@"pvr.ccz"];
            // set premultiply alpha
            if (version.major > 3)
            {
                [args addObject:@"--alpha-handling"];
                [args addObject:@"PremultiplyAlpha"];
            }
            else
            {
                [args addObject:@"--premultiply-alpha"];
            }
            
            break;
        case 3: // PVR RGBA4444 - PMA
            [args addObject:@"RGBA4444"];
            pTextureName = [spriteSheetFile stringByAppendingPathExtension:@"pvr.ccz"];
            // set premultiply alpha
            if (version.major > 3)
            {
                [args addObject:@"--alpha-handling"];
                [args addObject:@"PremultiplyAlpha"];
            }
            else
            {
                [args addObject:@"--premultiply-alpha"];
            }
            break;
        case 5: // PVRTC4 - PMA
            [args addObject:@"PVRTC4"];
            pTextureName = [spriteSheetFile stringByAppendingPathExtension:@"pvr.ccz"];
            // set premultiply alpha
            if (version.major > 3)
            {
                [args addObject:@"--alpha-handling"];
                [args addObject:@"PremultiplyAlpha"];
            }
            else
            {
                [args addObject:@"--premultiply-alpha"];
            }
            break;
        case 1: // PVR RGBA4444 - No PMA
        default:
            [args addObject:@"RGBA4444"];
            pTextureName = [spriteSheetFile stringByAppendingPathExtension:@"pvr.ccz"];
            break;
    }
    
    [args addObject:@"--format"];
    if (version.major > 3)
    {
        [args addObject:@"cocos2d-x"];
    }
    else
    {
        [args addObject:@"cocos2d"];
    }
    [args addObject:@"--sheet"];
    [args addObject:pTextureName];
    
    [args addObject:[projectSettings tempSpriteSheetCacheDirectory]];
    
    NSPipe *errPipe = [NSPipe pipe];
    
    [texturePackerTask setStandardError:errPipe];
    [texturePackerTask setArguments:args];
    [texturePackerTask launch];
    [texturePackerTask waitUntilExit];
    
    NSString *errorString = nil;
    
    NSFileHandle *readErr = [errPipe fileHandleForReading];
    NSData *errData = [readErr readDataToEndOfFile];
    errorString = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
    if(errorString.length > 0)
    {
        runOnMainQueueWithoutDeadlocking(^{
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Texture Packer Error"];
            [alert setInformativeText:[NSString stringWithFormat:@"%@\n\n%@", spriteSheetFile, errorString]];
            [alert addButtonWithTitle:@"Ok"];
            [alert runModal];
        });
    }
    else
    {
        if (multipack)
        {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSArray *files = [fm contentsOfDirectoryAtPath:outputFolder error:NULL];
            NSString *start = [[masterPlistFile lastPathComponent] stringByDeletingPathExtension];
            NSMutableArray *plistFiles = [NSMutableArray new];
            for( NSString* file in files )
            {
                if( [file hasSuffix:@".plist"]  && [file hasPrefix:start])
                {
                    [plistFiles addObject:file];
                }
            }
            
            NSMutableDictionary *masterPlist = [NSMutableDictionary new];
            [masterPlist setObject:plistFiles forKey:@"MultipackFiles"];
            [masterPlist writeToFile:masterPlistFile atomically:YES];
        }
    }
}

@end
