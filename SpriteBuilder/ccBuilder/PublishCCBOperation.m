#import "PublishCCBOperation.h"

#import "PlugInManager.h"
#import "PlugInExport.h"
#import "CCBWarnings.h"
#import "NSArray+Query.h"
#import "ProjectSettings.h"
#import "CCBFileUtil.h"
#import "PublishingTaskStatusProgress.h"


@interface PublishCCBOperation ()

@property (nonatomic, copy) NSString *currentWorkingFile;

@end


@implementation PublishCCBOperation

- (void)main
{
    [super main];

    [self assertProperties];

    [self publishCCB];

    [_publishingTaskStatusProgress taskFinished];
}

- (void)assertProperties
{
    NSAssert(_fileName != nil, @"fileName should not be nil");
    NSAssert(_filePath != nil, @"filePath should not be nil");
    NSAssert(_dstFilePath != nil, @"dstFile should not be nil");
}

- (void)publishCCB
{
    if ([self.dstFilePath isEqualToString:self.filePath])
    {
        [_warnings addWarningWithDescription:@"Publish will overwrite files in resource directory." isFatal:YES];
        return;
    }

    NSDate *srcDate = [CCBFileUtil modificationDateForFile:self.filePath];
    NSDate *dstDate = [CCBFileUtil modificationDateForFile:self.dstFilePath];

    // Check if file already exists and have same date
    if (!dstDate || fabs([srcDate timeIntervalSinceDate:dstDate]) > 0.0001)
    {
        [_publishingTaskStatusProgress updateStatusText:[NSString stringWithFormat:@"Publishing %@...", self.fileName]];

        // Remove old file
        NSFileManager *fileManager = [NSFileManager defaultManager];;
        [fileManager removeItemAtPath:self.dstFilePath error:NULL];

        BOOL sucess = [self publishCCBFile:self.filePath to:self.dstFilePath];
        if (!sucess)
        {
            return;
        }

        [CCBFileUtil setModificationDate:srcDate forFile:self.dstFilePath];
    }
}

-(void)fixupDict:(NSMutableDictionary*)dict
{
    NSMutableArray *properties = dict[@"properties"];
    for (NSMutableDictionary *property in properties)
    {
        NSString* type = [property objectForKey:@"type"];
        if([type isEqualToString:@"Position"])
        {
            NSMutableArray* value = [property objectForKey:@"value"];
            if(value)
            {
                CCPositionUnit xUnit = [[value objectAtIndex:3] intValue];
                CCPositionUnit yUnit = [[value objectAtIndex:4] intValue];
                if(xUnit == CCPositionUnitUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCPositionUnitPoints] atIndexedSubscript:3];
                if(yUnit == CCPositionUnitUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCPositionUnitPoints] atIndexedSubscript:4];
            }

        }
        else if([type isEqualToString:@"Size"])
        {
            NSMutableArray* value = [property objectForKey:@"value"];
            if(value)
            {
                CCSizeUnit widthUnit = [[value objectAtIndex:2] intValue];
                CCSizeUnit heightUnit = [[value objectAtIndex:3] intValue];
                
                if(widthUnit == CCSizeUnitInsetUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCSizeUnitInsetPoints] atIndexedSubscript:2];
                else if(widthUnit == CCSizeUnitUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCSizeUnitPoints] atIndexedSubscript:2];
                if(heightUnit == CCSizeUnitInsetUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCSizeUnitInsetPoints] atIndexedSubscript:3];
                else if(heightUnit == CCSizeUnitUIPoints)
                    [value setObject:[NSNumber numberWithInt:CCSizeUnitPoints] atIndexedSubscript:3];
            }
            
        }
        else if ([type isEqualToString:@"FloatScale"])
        {
            NSMutableArray* value = [property objectForKey:@"value"];
            if(value)
            {
                int type = [[value objectAtIndex:1] intValue];
                if(type & 1)
                {
                    type = type & ~1;
                    [value setObject:[NSNumber numberWithInt:type] atIndexedSubscript:1];
                }
            }
        }
        else if ([type isEqualToString:@"Scale"] || [type isEqualToString:@"ScaleLock"])
        {
            NSMutableArray* value = [property objectForKey:@"value"];
            if(value)
            {
                int scaleType = [[value objectAtIndex:3] intValue];
                if(scaleType & 1)
                {
                    scaleType = scaleType & ~(int)1;
                    [value setObject:[NSNumber numberWithInt:scaleType] atIndexedSubscript:3];
                }
            }
        }

    }
    
    if(dict[@"children"])
    {
        for (NSMutableDictionary * child in dict[@"children"])
        {
            [self fixupDict:child];
        }
        
    }
}

- (BOOL)publishCCBFile:(NSString *)srcFile to:(NSString *)dstFile
{
    self.currentWorkingFile = [dstFile lastPathComponent];

    NSString *publishFormat = [_projectSettings.exporter copy];
    PlugInExport *plugIn = [[PlugInManager sharedManager] plugInExportForExtension:publishFormat];
    if (!plugIn)
    {
        [_warnings addWarningWithDescription:[NSString stringWithFormat:@"Plug-in is missing for publishing files to %@-format. You can select plug-in in Project Settings.", publishFormat] isFatal:YES];
        return NO;
    }

    // Load src file
    NSMutableDictionary *doc = [NSMutableDictionary dictionaryWithContentsOfFile:srcFile];
    if (!doc)
    {
        [_warnings addWarningWithDescription:[NSString stringWithFormat:@"Failed to publish ccb-file. File is in invalid format: %@", srcFile] isFatal:NO];
        return YES;
    }
    
    if([doc[@"fileVersion"] intValue]<5)
        [self fixupDict:doc[@"nodeGraph"]];

    [self validateJointsInDocument:doc];

    // Export file
    plugIn.projectSettings = _projectSettings;
    plugIn.delegate = self;
    NSData *data = [plugIn exportDocument:doc];
    if (!data)
    {
        [_warnings addWarningWithDescription:[NSString stringWithFormat:@"Failed to publish ccb-file: %@", srcFile] isFatal:NO];
        return YES;
    }

    // Save file
    BOOL success = [data writeToFile:dstFile atomically:YES];
    if (!success)
    {
        [_warnings addWarningWithDescription:[NSString stringWithFormat:@"Failed to publish ccb-file. Failed to write file: %@", dstFile] isFatal:NO];
        return YES;
    }

    return YES;
}

- (void)validateJointsInDocument:(NSMutableDictionary *)document
{
    if (document[@"joints"])
    {
        NSMutableArray *joints = document[@"joints"];

        joints = [[joints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *joint, NSDictionary *bindings)
        {
            __block NSString *bodyType = @"bodyA";

            //Oh god. Nested blocks!
            PredicateBlock find = ^BOOL(NSDictionary *dict, int idx)
            {
                return [dict.allValues containsObject:bodyType];
            };

            //Find bodyA property
            if (![joint[@"properties"] findFirst:find])
            {
                NSString *description = [NSString stringWithFormat:@"Joint %@ must have bodyA attached. Not exporting it.", joint[@"displayName"]];
                [self->_warnings addWarningWithDescription:description isFatal:NO relatedFile:self->_currentWorkingFile];
                return NO;
            }

            //Find bodyB property
            bodyType = @"bodyB";
            if (![joint[@"properties"] findFirst:find])
            {
                NSString *description = [NSString stringWithFormat:@"Joint %@ must have a bodyB attached. Not exporting it.", joint[@"displayName"]];
                [self->_warnings addWarningWithDescription:description isFatal:NO relatedFile:self->_currentWorkingFile];
                return NO;
            }

            return YES;
        }]] mutableCopy];

        document[@"joints"] = joints;
    }
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"file: %@, path: %@, dstfile: %@", _fileName, _filePath, _dstFilePath];
}


#pragma mark - CCBPublishDelegate methods

- (void)addWarningWithDescription:(NSString *)description isFatal:(BOOL)fatal relatedFile:(NSString *)relatedFile resolution:(NSString *)resolution
{
    [_warnings addWarningWithDescription:description isFatal:fatal relatedFile:relatedFile resolution:resolution];
}

@end
