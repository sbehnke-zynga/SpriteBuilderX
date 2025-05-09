#import <Foundation/Foundation.h>
#import "ProjectSettings.h"

#ifdef __cplusplus
    #include <string>

    struct VersionInfo {
        int major = 0;
        int minor = 0;
        int build = 0;
        
        std::string to_string() const {
            return std::to_string(major) + "." + std::to_string(minor) + "." + std::to_string(build);
        }
        
        auto operator<=>(const VersionInfo&) const = default;
    };
#endif

@class FCFormatConverter;

@interface TexturePackerCommandLine : NSObject
{
    NSString* errorMessage;
}

@property(nonatomic, copy) NSString *outputName;
@property(nonatomic, copy) NSString* previewFile;

@property(nonatomic,assign) int imageFormat;
@property(nonatomic,assign) int shape_padding;
@property(nonatomic,assign) int border_padding;
@property(nonatomic,assign) int extrude;
@property(nonatomic,assign) BOOL disableRotateSprite;
@property(nonatomic,assign) BOOL multipack;
@property(nonatomic,assign) int max_width;
@property(nonatomic,assign) int max_height;

@property(nonatomic,readonly) NSString* errorMessage;

+ (TexturePackerCommandLine*) texturePacker;

-(void)createTextureSheet:(NSMutableArray *)absoluteFilePaths publishDirectory:(NSString*) publishDirectory spriteSheetFile:(NSString *)spriteSheetFile projectSettings:(ProjectSettings *)projectSettings;
@end

