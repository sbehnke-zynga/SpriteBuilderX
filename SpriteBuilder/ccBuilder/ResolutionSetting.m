/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2012 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "ResolutionSetting.h"

@implementation ResolutionSetting

@synthesize enabled;
@synthesize name;
@synthesize width;
@synthesize height;
@synthesize ext;
@synthesize resourceScale;
@synthesize mainScale;
@synthesize additionalScale;
@synthesize centeredOrigin;
@synthesize exts;

- (id) init
{
    self = [super init];
    if (!self) return NULL;
    
    enabled = NO;
    self.name = @"Custom";
    self.width = 1000;
    self.height = 1000;
    self.ext = @" ";
    self.resourceScale = 1;
    self.mainScale = 1;
    self.additionalScale = 1;
    
    return self;
}

- (id) initWithSerialization:(id)serialization
{
    self = [self init];
    if (!self) return NULL;
    
    self.enabled = YES;
    self.name = [serialization objectForKey:@"name"];
    self.width = [[serialization objectForKey:@"width"] intValue];
    self.height = [[serialization objectForKey:@"height"] intValue];
    self.ext = [serialization objectForKey:@"ext"];
		// TODO should store separate values for these.
    //float scale = [[serialization objectForKey:@"scale"] floatValue];
    self.resourceScale = [[serialization objectForKey:@"resourceScale"] floatValue];
    self.mainScale = [[serialization objectForKey:@"mainScale"] floatValue];
    self.additionalScale = [[serialization objectForKey:@"additionalScale"] floatValue];
    self.centeredOrigin = [[serialization objectForKey:@"centeredOrigin"] boolValue];
    if(self.resourceScale == 0)
    {
        float scale = [[serialization objectForKey:@"scale"] floatValue];
        self.resourceScale = scale;
        self.mainScale = scale;
        self.additionalScale = scale;
    }
    
    return self;
}

-(void)setresourceScale:(float)_scale
{
	NSAssert(_scale > 0.0, @"scale must be positive.");
	
//	if(_scale <= 0.0){
//		NSLog(@"WARNING: scale must be positive. (1.0 was substituted for %f)", _scale);
//		_scale = 1.0;
//	}
	
	resourceScale = _scale;
}

- (id) serialize
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    
    [dict setObject:name forKey:@"name"];
    [dict setObject:[NSNumber numberWithInt:width] forKey:@"width"];
    [dict setObject:[NSNumber numberWithInt:height] forKey:@"height"];
    [dict setObject:ext forKey:@"ext"];
    [dict setObject:[NSNumber numberWithFloat:resourceScale] forKey:@"resourceScale"];
    [dict setObject:[NSNumber numberWithFloat:mainScale] forKey:@"mainScale"];
    [dict setObject:[NSNumber numberWithFloat:additionalScale] forKey:@"additionalScale"];
    [dict setObject:[NSNumber numberWithBool:centeredOrigin] forKey:@"centeredOrigin"];
    
    return dict;
}

- (void) setExt:(NSString *)e
{
    
    ext = [e copy];
    
    if (!e || [e isEqualToString:@" "] || [e isEqualToString:@""])
    {
        exts = [[NSArray alloc] init];
    }
    else
    {
        exts = [e componentsSeparatedByString:@" "];
    }
}

- (void) dealloc
{
    self.ext = NULL;
    
}

+ (ResolutionSetting*) settingPhone
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Phone";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phone";
    setting.resourceScale = 1;
    
    return setting;
}
+ (ResolutionSetting*) settingPhoneHd
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"PhoneHd";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}
+ (ResolutionSetting*) settingTabletHd
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"TabletHd";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd tablet phonehd phone";
    setting.resourceScale = 4;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPhone";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phone";
    setting.resourceScale = 1;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhoneLandscape
{
    ResolutionSetting* setting = [self setting_iPhone];
    
    setting.name = @"iPhone Landscape (short)";
    setting.width = 480;
    setting.height = 320;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhonePortrait
{
    ResolutionSetting* setting = [self setting_iPhone];
    
    setting.name = @"iPhone Portrait (short)";
    setting.width = 320;
    setting.height = 480;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhoneRetina
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPhone";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}
+ (ResolutionSetting*) setting_iPhoneRetinaLandscape
{
    ResolutionSetting* setting = [self setting_iPhoneRetina];
    
    setting.name = @"iPhone 4S Landscape";
    setting.width = 960;
    setting.height = 640;
    
    return setting;
}
+ (ResolutionSetting*) setting_iPhoneRetinaPortrait
{
    ResolutionSetting* setting = [self setting_iPhoneRetina];
    
    setting.name = @"iPhone 4S Portrait";
    setting.width = 640;
    setting.height = 960;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone5Landscape
{
    ResolutionSetting* setting = [self setting_iPhoneRetina];
    
    setting.name = @"iPhone 5 Landscape";
    setting.width = 1136;
    setting.height = 640;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone5Portrait
{
    ResolutionSetting* setting = [self setting_iPhoneRetina];
    
    setting.name = @"iPhone 5 Portrait";
    setting.width = 640;
    setting.height = 1136;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPhone 6";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6Landscape
{
    ResolutionSetting* setting = [self setting_iPhone6];
    
    setting.name = @"iPhone 6 Landscape";
    setting.width = 1334;
    setting.height = 750;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6Portrait
{
    ResolutionSetting* setting = [self setting_iPhone6];
    
    setting.name = @"iPhone 6 Portrait";
    setting.width = 750;
    setting.height = 1334;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6Plus
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPhone 6+";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd tablet phonehd phone";
    setting.resourceScale = 4;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6PlusLandscape
{
    ResolutionSetting* setting = [self setting_iPhone6Plus];
    
    setting.name = @"iPhone 6+ Landscape";
    setting.width = 1920;
    setting.height = 1080;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhone6PlusPortrait
{
    ResolutionSetting* setting = [self setting_iPhone6Plus];
    
    setting.name = @"iPhone 6+ Portrait";
    setting.width = 1080;
    setting.height = 1920;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPad
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPad";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPadLandscape
{
    ResolutionSetting* setting = [self setting_iPad];
    
    setting.name = @"iPad Landscape";
    setting.width = 1024;
    setting.height = 768;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPadPortrait
{
    ResolutionSetting* setting = [self setting_iPad];
    
    setting.name = @"iPad Portrait";
    setting.width = 768;
    setting.height = 1024;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPadRetina
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"iPad Retina";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd phonehd phone";
    setting.resourceScale = 4;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPadRetinaLandscape
{
    ResolutionSetting* setting = [self setting_iPadRetina];
    
    setting.name = @"iPad Retina Landscape";
    setting.width = 2048;
    setting.height = 1536;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPadRetinaPortrait
{
    ResolutionSetting* setting = [self setting_iPadRetina];
    
    setting.name = @"iPad Retina Portrait";
    setting.width = 1536;
    setting.height = 2048;
    
    return setting;
}

+ (ResolutionSetting*) setting_iPhoneX {
    
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    setting.name = @"iPhone X";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd phonehd";
    setting.resourceScale = 4;
    return setting;
}

+ (ResolutionSetting*) setting_iPhoneXLandscape {
    
    ResolutionSetting* setting = [self setting_iPhoneX];
    setting.name = @"iPhone X Landscape";
    setting.width = 2436;
    setting.height = 1125;
    return setting;
}

+ (ResolutionSetting*) setting_iPhoneXPortrait {
    
    ResolutionSetting* setting = [self setting_iPhoneX];
    setting.name = @"iPhone X Portrait";
    setting.width = 1125;
    setting.height = 2436;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro10 {
    
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    setting.name = @"iPad Pro 10";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd phonehd";
    setting.resourceScale = 4;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro10Landscape {
    
    ResolutionSetting* setting = [self setting_iPadPro10];
    setting.name = @"iPad Pro 10 Landscape";
    setting.width = 2224;
    setting.height = 1668;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro10Portrait {
    
    ResolutionSetting* setting = [self setting_iPadPro10];
    setting.name = @"iPad Pro 10 Portrait";
    setting.width = 1668;
    setting.height = 2224;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro12 {
    
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    setting.name = @"iPad Pro 12";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd phonehd";
    setting.resourceScale = 4;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro12Landscape {
    
    ResolutionSetting* setting = [self setting_iPadPro12];
    setting.name = @"iPad Pro 12 Landscape";
    setting.width = 2732;
    setting.height = 2048;
    return setting;
}

+ (ResolutionSetting*) setting_iPadPro12Portrait {
    
    ResolutionSetting* setting = [self setting_iPadPro12];
    setting.name = @"iPad Pro 12 Portrait";
    setting.width = 2048;
    setting.height = 2732;
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x720 {
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 1280x720";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x720Landscape {
    
    ResolutionSetting* setting = [self setting_Android1280x720];
    setting.name = @"Android 1280x720 Landscape";
    setting.width = 1280;
    setting.height = 720;
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x720Portrait {
    
    ResolutionSetting* setting = [self setting_Android1280x720];
    setting.name = @"Android 1280x720 Portrait";
    setting.width = 720;
    setting.height = 1280;
    return setting;
}

+ (ResolutionSetting*) setting_Android1920x1080
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 1920x1080";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd tablet phonehd phone";
    setting.resourceScale = 4;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1920x1080Landscape
{
    ResolutionSetting* setting = [self setting_Android1920x1080];
    
    setting.name = @"Android 1920x1080 Landscape";
    setting.width = 1920;
    setting.height = 1080;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1920x1080Portrait
{
    ResolutionSetting* setting = [self setting_Android1920x1080];
    
    setting.name = @"Android 1920x1080 Portrait";
    setting.width = 1080;
    setting.height = 1920;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android854x480
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 854x480";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android854x480Landscape
{
    ResolutionSetting* setting = [self setting_Android854x480];
    
    setting.name = @"Android 854x480 Landscape";
    setting.width = 854;
    setting.height = 480;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android854x480Portrait
{
    ResolutionSetting* setting = [self setting_Android854x480];
    
    setting.name = @"Android 854x480 Portrait";
    setting.width = 480;
    setting.height = 854;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android800x480
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 800x480";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android800x480Landscape
{
    ResolutionSetting* setting = [self setting_Android800x480];
    
    setting.name = @"Android 800x480 Landscape";
    setting.width = 800;
    setting.height = 480;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android800x480Portrait
{
    ResolutionSetting* setting = [self setting_Android800x480];
    
    setting.name = @"Android 800x480 Portrait";
    setting.width = 480;
    setting.height = 800;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android960x540
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 960x540";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android960x540Landscape
{
    ResolutionSetting* setting = [self setting_Android960x540];
    
    setting.name = @"Android 960x540 Landscape";
    setting.width = 960;
    setting.height = 540;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android960x540Portrait
{
    ResolutionSetting* setting = [self setting_Android960x540];
    
    setting.name = @"Android 960x540 Portrait";
    setting.width = 540;
    setting.height = 960;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1024x600
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 1024x600";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1024x600Landscape
{
    ResolutionSetting* setting = [self setting_Android1024x600];
    
    setting.name = @"Android 1024x600 Landscape";
    setting.width = 1024;
    setting.height = 600;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1024x600Portrait
{
    ResolutionSetting* setting = [self setting_Android1024x600];
    
    setting.name = @"Android 1024x600 Portrait";
    setting.width = 600;
    setting.height = 1024;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x800
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 1280x800";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"phonehd phone";
    setting.resourceScale = 2;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x800Landscape
{
    ResolutionSetting* setting = [self setting_Android1280x800];
    
    setting.name = @"Android 1280x800 Landscape";
    setting.width = 1280;
    setting.height = 800;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android1280x800Portrait
{
    ResolutionSetting* setting = [self setting_Android1280x800];
    
    setting.name = @"Android 1280x800 Portrait";
    setting.width = 800;
    setting.height = 1280;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android2960x1440
{
    ResolutionSetting* setting = [[ResolutionSetting alloc] init];
    
    setting.name = @"Android 2960x1440";
    setting.width = 0;
    setting.height = 0;
    setting.ext = @"tablethd tablet phonehd phone";
    setting.resourceScale = 4;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android2960x1440Landscape
{
    ResolutionSetting* setting = [self setting_Android2960x1440];
    
    setting.name = @"Android 2960x1440 Landscape";
    setting.width = 2960;
    setting.height = 1440;
    
    return setting;
}

+ (ResolutionSetting*) setting_Android2960x1440Portrait
{
    ResolutionSetting* setting = [self setting_Android2960x1440];
    
    setting.name = @"Android 2960x1440 Portrait";
    setting.width = 1440;
    setting.height = 2960;
    
    return setting;
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@ <0x%p> (%d x %d)", NSStringFromClass([self class]), self, width, height];
}

- (id) copyWithZone:(NSZone*)zone
{
    ResolutionSetting* copy = [[ResolutionSetting alloc] init];
    
    copy.enabled = enabled;
    copy.name = name;
    copy.width = width;
    copy.height = height;
    copy.ext = ext;
    copy.resourceScale = resourceScale;
    copy.mainScale = mainScale;
    copy.additionalScale = additionalScale;
    copy.centeredOrigin = centeredOrigin;
    
    return copy;
}

@end
