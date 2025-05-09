#import <objc/message.h>
#import "InspectorPropertyPaneBuilder.h"
#import "InspectorValue.h"
#import "NodeInfo.h"
#import "PlugInNode.h"
#import "InspectorSeparator.h"
#import "CocosScene.h"
#import "SequencerSequence.h"
#import "SequencerNodeProperty.h"
#import "SequencerHandler.h"
#import "CCNode+NodeInfo.h"
#import "CustomPropSetting.h"

@interface InspectorPropertyPaneBuilder ()

@property (nonatomic, strong, readwrite) CCNode *node;
@property (nonatomic) BOOL isCodeConnectionPane;
@property (nonatomic) int currentOffSetY;
@property (nonatomic) BOOL displayPluginProperties;

@property (nonatomic, strong) InspectorValue *lastInspectorValue;
@property (nonatomic) BOOL hideAllToNextSeparator;
@property (nonatomic, strong) NSMutableDictionary *currentInspectorValues;

@end


@implementation InspectorPropertyPaneBuilder

- (instancetype)initWithIsCodeConnectionPane:(BOOL)isCodeConnectionPane node:(CCNode *)node
{
    self = [super init];
    if (self)
    {
        self.isCodeConnectionPane = isCodeConnectionPane;
        self.node = node;
        self.currentOffSetY = 0;
        self.currentInspectorValues = [NSMutableDictionary dictionary];
    }

    return self;
}

- (NSDictionary *)buildAndCreatePropertyViewMap
{
    [self notifyPanesThatWillBeRemoved];

    [self removeAllOldInspectorPanes];

    [self resetInspectorContainerViewFrames];

    self.displayPluginProperties = YES;

    if (!_node)
    {
        return @{};
    }

    NodeInfo *info = _node.userObject;
    PlugInNode *plugIn = info.plugIn;

    if (plugIn.isJoint)
    {
        [self disableStandardPropertiesAndTogglePhysicsWarningView];
    }
    else
    {
        [self addCodeConnectionsPaneForPlugIn:plugIn];
    }

    if (plugIn && _displayPluginProperties)
    {
        [self addProperties:plugIn];
    }
    else
    {
        if (_displayPluginProperties)
        {
            NSLog(@"WARNING info:%@ plugIn:%@ selectedNode: %@", info, plugIn, _node);
        }
    }

    if(!_isCodeConnectionPane)
        [self addCustomPropertiesForPlugIn:plugIn];
    
    [self addParamPropertiesForPlugIn:plugIn];

    self.hideAllToNextSeparator = NO;

    [_currentView setFrameSize:NSMakeSize([_currentScrollView contentSize].width, _currentOffSetY)];

    [self resetKeyViewLoop];

    return _currentInspectorValues;
}

- (InspectorValue *)addInspectorPropertyOfType:(NSString *)type
                             name:(NSString *)name
                      displayName:(NSString *)displayName
                            extra:(NSString *)extra
                         readOnly:(BOOL)readOnly
                     affectsProps:(NSArray *)affectsProps
{
    InspectorValue *inspectorValue = [InspectorValue inspectorOfType:type
                                                       withSelection:_node
                                                     andPropertyName:name
                                                      andDisplayName:displayName
                                                            andExtra:extra];

    NSAssert3(inspectorValue, @"property '%@' (%@) not found in class %@", name, type, NSStringFromClass([_node class]));

    [self saveLastInspectorValue:inspectorValue];

    [self configureInspectorValue:readOnly affectsProps:affectsProps inspectorValue:inspectorValue];

    [self saveInspectorValueForFutureUpdates:name inspectorValue:inspectorValue];

    [self loadPropertyEditorNibWithType:type inspectorValue:inspectorValue];

    [inspectorValue willBeAdded];

    NSView *inspectorValuesView = inspectorValue.view;
    
    //if its a separator, check to see if it isExpanded, if not set all of the next non-separator InspectorValues to hidden and don't touch the offset
    if ([inspectorValue isKindOfClass:[InspectorSeparator class]])
    {
        [self addSeparator:_currentOffSetY inspectorValue:inspectorValue inspectorValuesView:inspectorValuesView];
    }
    else
    {
        //Separator in Custom Properties: "-"
        //Also you can use "-SomeType" to add description
        NSString *dash = @"-";
        if (name.length > 1 && [[name substringToIndex:1] isEqualToString:dash]) {
            _currentOffSetY -= 10;
        } else
        if ([name isEqualToString:dash]) {
            _currentOffSetY -= 14;
        }
        [self toggleVisibilityToNextSeparator:_currentOffSetY inspectorValuesView:inspectorValuesView];
    }

    [_currentView addSubview:inspectorValuesView];

    [inspectorValuesView setAutoresizingMask:NSViewWidthSizable];
    
    return inspectorValue;
}

- (void)saveLastInspectorValue:(InspectorValue *)inspectorValue
{
    _lastInspectorValue.inspectorValueBelow = inspectorValue;
    self.lastInspectorValue = inspectorValue;
}

- (void)configureInspectorValue:(BOOL)readOnly affectsProps:(NSArray *)affectsProps inspectorValue:(InspectorValue *)inspectorValue
{
    inspectorValue.readOnly = readOnly;
    inspectorValue.rootNode = (_node == _cocosScene.rootNode);
    inspectorValue.affectsProperties = affectsProps;
}

- (void)saveInspectorValueForFutureUpdates:(NSString *)propName inspectorValue:(InspectorValue *)inspectorValue
{
    if (propName)
    {
        _currentInspectorValues[propName] = inspectorValue;
    }
}

- (void)toggleVisibilityToNextSeparator:(int)offset inspectorValuesView:(NSView *)inspectorValuesView
{
    if (_hideAllToNextSeparator)
    {
        [inspectorValuesView setHidden:YES];
    }
    else
    {
        NSRect frame = [inspectorValuesView frame];
        [inspectorValuesView setFrame:NSMakeRect(0, offset, frame.size.width, frame.size.height)];
        offset += frame.size.height;
        self.currentOffSetY = offset;
    }
}

- (void)addSeparator:(int)offset inspectorValue:(InspectorValue *)inspectorValue inspectorValuesView:(NSView *)inspectorValuesView
{
    InspectorSeparator *inspectorSeparator = (InspectorSeparator *) inspectorValue;

    self.hideAllToNextSeparator = !inspectorSeparator.isExpanded;

    NSRect frame = [inspectorValuesView frame];
    [inspectorValuesView setFrame:NSMakeRect(0, offset, frame.size.width, frame.size.height)];
    offset += frame.size.height;
    self.currentOffSetY = offset;
}

- (void)loadPropertyEditorNibWithType:(NSString *)type inspectorValue:(InspectorValue *)inspectorValue
{
    NSString *inspectorNibName = [NSString stringWithFormat:@"Inspector%@", type];
    @try
    {
        [[NSBundle mainBundle] loadNibNamed:inspectorNibName owner:inspectorValue topLevelObjects:nil];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception loading inspector nib \"%@\": %@, origin: %@", inspectorNibName, exception, [NSThread callStackSymbols]);
    }
}

- (BOOL)isDisabledProperty:(NSString *)name animatable:(BOOL)animatable
{
    // Only animatable properties can be disabled
    if (!animatable)
    {
        return NO;
    }

    SequencerSequence *sequence = _sequenceHandler.currentSequence;
    SequencerNodeProperty *sequencerNodeProperty = [_node sequenceNodeProperty:name sequenceId:sequence.sequenceId];

    // Do not disable if animation hasn't been enabled
    if (!sequencerNodeProperty)
    {
        return NO;
    }
    
    // Do not disable if we are currently at a keyframe or beore
    if(![sequencerNodeProperty activeKeyframeAtTime:sequence.timelinePosition])
    {
        return NO;
    }
    else
    {
        if ([sequencerNodeProperty keyframeAtTime:sequence.timelinePosition] && ![name isEqualToString:@"visible"])
            return NO;
    }

    // Between keyframes - disable
    return YES;
}


- (void)resetKeyViewLoop
{
    NSString *privateFunction = [NSString stringWithFormat:@"%@%@%@", @"_setDefault", @"KeyView", @"Loop"];
    SEL privateSelector = NSSelectorFromString(privateFunction);

    //Undocumented function that resets the KeyViewLoop.
    if ([_currentView respondsToSelector:privateSelector])
    {
        IMP imp = [_currentView methodForSelector:privateSelector];
        void (*func)(id, SEL) = (void *)imp;
        func(_currentView, privateSelector);
    }
}

- (void)addCustomPropertiesForPlugIn:(PlugInNode *)plugIn
{
    NSString *customClass = [_node extraPropForKey:@"customClass"];
    NSArray *customProps = _node.customProperties;
    if (customClass && ![customClass isEqualToString:@""])
    {
        BOOL isCCBSubFile = [plugIn.nodeClassName isEqualToString:@"CCBFile"];

        [self addSeparatorForCustomPropertyCustomProps:customProps isCCBSubFile:isCCBSubFile];

        [self addCustomPropertySettingsCustomProps:customProps];

        [self addCustomEditForCustomPropertyIsCCBSubFile:isCCBSubFile];
    }
}

- (void)addParamPropertiesForPlugIn:(PlugInNode *)plugIn
{
    NSArray *paramsProperties = _node.additionalProperties;
    if(paramsProperties && paramsProperties.count)
    {
        BOOL first = YES;
        NSString* currentGroup = nil;
        
        for (NSDictionary *dict in paramsProperties)
        {
            if([dict[@"codeConnection"] boolValue] == _isCodeConnectionPane)
            {
                NSString *group = dict[@"group"];
                if(first || [currentGroup compare: group] != NSOrderedSame)
                {
                    first = NO;
                    currentGroup = group;
                    [self addSeparatorForParamPropertyGroup:group andDisplayName:dict[@"groupName"]];
                }
                [self addInspectorPropertyOfType:dict[@"type"]
                                            name:dict[@"name"]
                                     displayName:dict[@"displayName"]
                                           extra:dict[@"extra"]
                                        readOnly:NO
                                    affectsProps:nil];
            }
            
        }
    }
}

- (void)addCustomEditForCustomPropertyIsCCBSubFile:(BOOL)isCCBSubFile
{
    if (!isCCBSubFile)
    {
        [self addInspectorPropertyOfType:@"CustomEdit" name:NULL displayName:@"" extra:NULL readOnly:NO affectsProps:NULL];
    }
}

- (void)addCustomPropertySettingsCustomProps:(NSArray *)customProps
{
    for (int i=0; i < customProps.count; i++) {
        CustomPropSetting *setting = [customProps objectAtIndex:i];
        NSString *type = (setting.type == kCCBCustomPropTypeBool) ? @"CustomBool" : @"Custom";
        [self addInspectorPropertyOfType: type
                                    name: setting.name
                             displayName: setting.name
                                   extra: NULL
                                readOnly: NO
                            affectsProps: NULL];
    }
}

- (void)addSeparatorForCustomPropertyCustomProps:(NSArray *)customProps isCCBSubFile:(BOOL)isCCBSubFile
{
    if ([customProps count] || !isCCBSubFile)
    {
        [self addInspectorPropertyOfType:@"Separator"
                                    name:[_node extraPropForKey:@"customClass"]
                             displayName:[_node extraPropForKey:@"customClass"]
                                   extra:NULL
                                readOnly:YES
                            affectsProps:NULL];
    }
}

- (void)addSeparatorForParamPropertyGroup:(NSString *)group andDisplayName:(NSString *)displayName
{
    [self addInspectorPropertyOfType:@"Separator"
                                name:[NSString stringWithFormat:@"separator_uid_%@", group]
                         displayName:[NSString stringWithFormat:@"Params - %@", displayName]
                               extra:NULL
                            readOnly:YES
                        affectsProps:NULL];
}

- (void)addProperties:(PlugInNode *)plugIn
{
    NSArray *propInfos = plugIn.nodeProperties;
    for (int i = 0; i < [propInfos count]; i++)
    {
        NSDictionary *propInfo = propInfos[(NSUInteger) i];
        BOOL animated = [propInfo[@"animatable"] boolValue];
        NSString *name = propInfo[@"name"];

        if ([name isEqualToString:@"visible"])
        {
            animated = YES;
        }

        BOOL readOnly = [propInfo[@"readOnly"] boolValue];
        if ([self isDisabledProperty:name animatable:animated])
        {
            readOnly = YES;
        }

        // Handle Flash skews
        BOOL usesFlashSkew = [_node usesFlashSkew];
        if ((usesFlashSkew && [name isEqualToString:@"rotation"])
            || (!usesFlashSkew && [name isEqualToString:@"rotationalSkewX"])
            || (!usesFlashSkew && [name isEqualToString:@"rotationalSkewY"]))
        {
            continue;
        }

        // Handle read only for animated properties
        //For the separators; should make this a part of the definition
        if (name == NULL)
        {
            name = propInfo[@"displayName"];
        }

        if (![propInfo[@"inspectorDisabled"] boolValue]
            && ([propInfo[@"codeConnection"] boolValue] == _isCodeConnectionPane))
        {
            [self addInspectorPropertyOfType:propInfo[@"type"]
                                        name:name
                                 displayName:propInfo[@"displayName"]
                                       extra:propInfo[@"extra"]
                                    readOnly:readOnly
                                affectsProps:propInfo[@"affectsProperties"]];
        }
    }
}

- (void)disableStandardPropertiesAndTogglePhysicsWarningView
{
    [_inspectorPhysics setHidden:YES];

    if ([self isPhysicUnavailableAvailable])
    {
        self.displayPluginProperties = NO;

        if (!_isCodeConnectionPane)
        {
            InspectorValue *inspectorValue = [self addInspectorPropertyOfType:@"PhysicsUnavailable"
                                        name:@"name"
                                 displayName:nil
                                       extra:@""
                                    readOnly:YES
                                affectsProps:nil];
            
            // This will retain the value, otherwise the action to go back to timeline frame 0 won't work
            // as the target will be removed from memory prematurely
            _currentInspectorValues[@"PhysicsUnavailable"] = inspectorValue;
        }
    }
}

- (BOOL)isPhysicUnavailableAvailable
{
    return [_sequenceHandler currentSequence].timelinePosition != 0.0f
            || ![_sequenceHandler currentSequence].autoPlay;
}

- (void)addCodeConnectionsPaneForPlugIn:(PlugInNode *)plugIn
{
    if (_isCodeConnectionPane)
    {
        [self addInspectorPropertyOfType:@"CodeConnections"
                                    name:@"customClass"
                             displayName:@"Code Connections"
                                   extra:NULL
                                readOnly:[plugIn.nodeClassName isEqualToString:@"CCBFile"]
                            affectsProps:NULL];

        [_inspectorPhysics setHidden:NO];
    }
}

- (void)resetInspectorContainerViewFrames
{
    [_currentView setFrameSize:NSMakeSize(233, 1)];
}

- (void)removeAllOldInspectorPanes
{
    NSArray *panes = [_currentView subviews];
    for (int i = [panes count] - 1; i >= 0; i--)
    {
        NSView *pane = panes[(NSUInteger) i];
        [pane removeFromSuperview];
    }
    [_currentInspectorValues removeAllObjects];
}

- (void)notifyPanesThatWillBeRemoved
{
    for (NSString *key in _currentInspectorValues)
    {
        InspectorValue *inspectorValue = _currentInspectorValues[key];
        [inspectorValue willBeRemoved];
    }
}

@end
