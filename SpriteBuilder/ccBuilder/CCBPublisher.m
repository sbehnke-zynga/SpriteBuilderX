#import "CCBPublisher.h"
#import "ProjectSettings.h"
#import "TaskStatusUpdaterProtocol.h"
#import "DateCache.h"
#import "PublishRenamedFilesLookup.h"
#import "PublishingTaskStatusProgress.h"
#import "CCBDirectoryPublisher.h"
#import "PublishGeneratedFilesOperation.h"
#import "CCBPublishingTarget.h"
#import "CCBPublisherCacheCleaner.h"
#import "ZipDirectoryOperation.h"
#import "MiscConstants.h"
#import "PlatformSettings.h"
#import "NSString+RelativePath.h"


@interface CCBPublisher ()

@property (nonatomic, copy) PublisherFinishBlock finishBlock;

@property (nonatomic, strong) PublishingTaskStatusProgress *publishingTaskStatusProgress;
@property (nonatomic, strong) NSOperationQueue *publishingQueue;
@property (nonatomic, strong) NSMutableArray *publishingPlatforms;
@property (nonatomic, strong) ProjectSettings *projectSettings;

// Shared for targets
@property (nonatomic, strong) CCBWarnings *warnings;
@property (nonatomic, strong) DateCache *modifiedDatesCache;

@end


@implementation CCBPublisher

- (id)initWithProjectSettings:(ProjectSettings *)someProjectSettings warnings:(CCBWarnings *)someWarnings finishedBlock:(PublisherFinishBlock)finishBlock;
{
    NSAssert(someProjectSettings != nil, @"project settings should never be nil! Publisher won't work without.");
    NSAssert(someWarnings != nil, @"warnings are nil. Are you sure you don't need them?");

    self = [super init];
	if (!self)
	{
		return NULL;
	}

    self.projectSettings = someProjectSettings;
    self.warnings = someWarnings;
    self.finishBlock = finishBlock;

    self.publishingQueue = [[NSOperationQueue alloc] init];
    _publishingQueue.maxConcurrentOperationCount = 1;

    self.modifiedDatesCache = [[DateCache alloc] init];
    self.publishingPlatforms = [NSMutableArray array];

    return self;
}

- (bool)start
{
    [_publishingPlatforms removeAllObjects];
    for(PlatformSettings *platfromSettings in _projectSettings.platformsSettings)
    {
        if([_projectSettings.publishPlatform isEqualToString:@"Default"]) {
            if(platfromSettings.publishEnabled && [platfromSettings.packets count] != 0)
            {
                [_publishingPlatforms addObject:platfromSettings];
            }
        }
        else if([_projectSettings.publishPlatform isEqualToString:@"All"]) {
            if([platfromSettings.packets count])
            {
                [_publishingPlatforms addObject:platfromSettings];
            }
        }
        else {
            if([platfromSettings.name isEqualToString:_projectSettings.publishPlatform] && [platfromSettings.packets count])
            {
                [_publishingPlatforms addObject:platfromSettings];
            }
        }
    }
    if ([_publishingPlatforms count] == 0)
    {
        NSLog(@"[PUBLISH] Nothing to do: no publishing targets added.");
        [_warnings setCurrentPlatform:@"none"];
        [_warnings addWarningWithDescription:@"Nothing to publish. Check Project Settings. Common cause: No platforms is set to publish or no packages selected inside platforms" isFatal:YES];
        [self callFinishedBlock];
        return false;
    }


    NSLog(@"[PUBLISH] Start...");
    printf("[PUBLISH] Start...\n");


    [_publishingQueue setSuspended:YES];

    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];

    if (_projectSettings.publishEnvironment == kCCBPublishEnvironmentRelease)
    {
        [CCBPublisherCacheCleaner cleanWithProjectSettings:_projectSettings];
    }

    if(![self doPublish])
        return NO;

    _publishingTaskStatusProgress.totalTasks = [_publishingQueue operationCount];

    [_publishingQueue setSuspended:NO];
    [_publishingQueue waitUntilAllOperationsAreFinished];
	
    [_projectSettings flagFilesDirtyWithWarnings:_warnings];


    NSLog(@"[PUBLISH] Done in %.2f seconds.", [[NSDate date] timeIntervalSince1970] - startTime);
    printf("[PUBLISH] Done in %.2f seconds.\n", [[NSDate date] timeIntervalSince1970] - startTime);


    [self callFinishedBlock];
    return YES;
}

- (void)callFinishedBlock
{
    if ([[NSThread currentThread] isMainThread])
    {
        if (_finishBlock)
        {
            _finishBlock(self, _warnings);
        }
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), ^
        {
            if (_finishBlock)
            {
                _finishBlock(self, _warnings);
            }
        });
    }
}

- (BOOL)doPublish
{
    __weak id weakSelf = self;
/*    [_publishingQueue addOperationWithBlock:^
    {
        [weakSelf removeOldPublishDirIfCacheCleaned];
    }];*/

    [self removeOldPublishDirIfCacheCleaned];

    if (![self enqueuePublishOperationsForAllTargets])
    {
        return NO;
    }

    [_publishingQueue addOperationWithBlock:^
    {
        [self->_projectSettings clearAllDirtyMarkers];

        [weakSelf resetNeedRepublish];
    }];

    return YES;
}

- (BOOL)enqueuePublishOperationsForAllTargets
{
    for (PlatformSettings *platform in _publishingPlatforms)
    {
        if (![self enqueuePublishingOperationsForPlatform:platform])
        {
             return NO;
        }
    }
    return YES;
}

- (NSArray *)publishingResolutionsForPlatform:(PlatformSettings*) platform
{
    NSMutableArray *result = [NSMutableArray array];
    
    if (platform.publish1x)
    {
        [result addObject:RESOLUTION_PHONE];
    }
    if (platform.publish2x)
    {
        [result addObject:RESOLUTION_PHONE_HD];
    }
    if (platform.publish4x)
    {
        [result addObject:RESOLUTION_TABLET_HD];
    }
    return result;
}

- (BOOL)enqueuePublishingOperationsForPlatform:(PlatformSettings*) platform
{
    _warnings.currentPlatform = platform.name;

    PublishRenamedFilesLookup *renamedFilesLookup = [[PublishRenamedFilesLookup alloc] init];
    NSMutableSet *publishedSpriteSheetFiles = [NSMutableSet set];
    
    NSArray *resolutions = [self publishingResolutionsForPlatform:platform];

    for (NSString *key in platform.inputDirs)
    {
        CCBDirectoryPublisher *dirPublisher = [[CCBDirectoryPublisher alloc] initWithProjectSettings:_projectSettings
                                                                                            warnings:_warnings
                                                                                               queue:_publishingQueue];
        NSDictionary *value = [platform.inputDirs objectForKey:key];
        
        dirPublisher.platformSettings = platform;
        dirPublisher.inputDir = value[@"path"];
        id type =  value[@"type"];
        
        //dirPublisher.osType = target.osType;
        dirPublisher.resolutions = resolutions;
        //dirPublisher.audioQuality = target.audioQuality;
        dirPublisher.publishingTaskStatusProgress = _publishingTaskStatusProgress;
        dirPublisher.modifiedDatesCache = _modifiedDatesCache;
        if([type integerValue] == kPlatformSettingsPublishTypesPublish)
        {
            dirPublisher.outputDir = [platform.publishDirectory absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]];
            dirPublisher.renamedFilesLookup = renamedFilesLookup;
            dirPublisher.publishedSpriteSheetFiles = publishedSpriteSheetFiles;
            if (![dirPublisher generateAndEnqueuePublishingTasks])
                return NO;
        }
        else
        {
            PublishRenamedFilesLookup *packetRenamedFilesLookup = [[PublishRenamedFilesLookup alloc] init];
            NSMutableSet *packetPublishedSpriteSheetFiles = [NSMutableSet set];
            dirPublisher.outputDir = [[platform.separatePackagesDirectory absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]] stringByAppendingPathComponent:key];
            dirPublisher.renamedFilesLookup = packetRenamedFilesLookup;
            dirPublisher.publishedSpriteSheetFiles = packetPublishedSpriteSheetFiles;
            if (![dirPublisher generateAndEnqueuePublishingTasks])
                return NO;
            [self enqueueGenerateFilesOperationWithTarget:platform withRenamedFilesLookup:packetRenamedFilesLookup withPublishedSpriteSheetFiles:packetPublishedSpriteSheetFiles withPacket:key];
        }
    }

    [self enqueueGenerateFilesOperationWithTarget:platform withRenamedFilesLookup:renamedFilesLookup withPublishedSpriteSheetFiles:publishedSpriteSheetFiles];

    // Yiee Haa!
    return YES;
}

- (void)enqueueGenerateFilesOperationWithTarget:(PlatformSettings*) platform withRenamedFilesLookup:(PublishRenamedFilesLookup*)renamedFilesLookup withPublishedSpriteSheetFiles:(NSMutableSet*)publishedSpriteSheetFiles
{
    PublishGeneratedFilesOperation *operation = [[PublishGeneratedFilesOperation alloc] initWithProjectSettings:_projectSettings
                                                                                                       warnings:_warnings
                                                                                                 statusProgress:_publishingTaskStatusProgress];
    //operation.osType = target.osType;
    operation.outputDir = [platform.publishDirectory absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]];
    operation.publishedSpriteSheetFiles = publishedSpriteSheetFiles;
    operation.fileLookup = renamedFilesLookup;

    [_publishingQueue addOperation:operation];
}

- (void)enqueueGenerateFilesOperationWithTarget:(PlatformSettings*) platform withRenamedFilesLookup:(PublishRenamedFilesLookup*)renamedFilesLookup withPublishedSpriteSheetFiles:(NSMutableSet*)publishedSpriteSheetFiles withPacket:(NSString*)packet
{
    PublishGeneratedFilesOperation *operation = [[PublishGeneratedFilesOperation alloc] initWithProjectSettings:_projectSettings
                                                                                                       warnings:_warnings
                                                                                                 statusProgress:_publishingTaskStatusProgress];
    //operation.osType = target.osType;
    operation.outputDir = [[platform.separatePackagesDirectory stringByAppendingPathComponent:packet] absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]];
    operation.publishedSpriteSheetFiles = publishedSpriteSheetFiles;
    operation.fileLookup = renamedFilesLookup;
    operation.packet = packet;
    
    [_publishingQueue addOperation:operation];
}

- (void)resetNeedRepublish
{
    if (_projectSettings.needRepublish)
    {
        _projectSettings.needRepublish = NO;
        [_projectSettings store];
    }
}

- (void)removeOldPublishDirIfCacheCleaned
{
    if (_projectSettings.needRepublish)
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (PlatformSettings *platform in _publishingPlatforms)
        {
            NSString *publishDirectory = [platform.publishDirectory absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]];
            if(publishDirectory && publishDirectory.length>0)
            {
                NSError *error;
                if (![fileManager removeItemAtPath:publishDirectory error:&error]
                    && error.code != NSFileNoSuchFileError)
                {
                    NSLog(@"Error removing old publishing directory at path \"%@\" with error %@", publishDirectory, error);
                }
            }
            NSString *separatePackagesDirectory = [platform.separatePackagesDirectory absolutePathFromBaseDirPath:[_projectSettings.projectPath stringByDeletingLastPathComponent]];
            if(separatePackagesDirectory && separatePackagesDirectory.length>0)
            {
                NSError *error;
                if (![fileManager removeItemAtPath:separatePackagesDirectory error:&error]
                    && error.code != NSFileNoSuchFileError)
                {
                    NSLog(@"Error removing old separate packet publishing directory at path \"%@\" with error %@", separatePackagesDirectory, error);
                }
            }
        }
    }
}

- (void)startAsync
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^
    {
        [self start];
    });
}

- (void)cancel
{
    NSLog(@"[PUBLISH] cancelled by user");
    [_publishingQueue cancelAllOperations];
}

- (void)setTaskStatusUpdater:(id <TaskStatusUpdaterProtocol>)taskStatusUpdater
{
    _taskStatusUpdater = taskStatusUpdater;
    self.publishingTaskStatusProgress = [[PublishingTaskStatusProgress alloc] initWithTaskStatus:taskStatusUpdater];
}

/*- (void)addPublishingTarget:(CCBPublishingTarget *)target
{
    if (!target)
    {
        return;
    }

    [_publishingTargets addObject:target];
}*/

@end
