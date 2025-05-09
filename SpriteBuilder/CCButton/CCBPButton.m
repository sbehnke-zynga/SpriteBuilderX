//
//  CCBPButton.m
//  SpriteBuilder
//
//  Created by Viktor on 9/25/13.
//
//

#import "CCBPButton.h"
#import "CCSpriteFrame.h"
#import "CCTexture.h"
#import "AppDelegate.h"
#import "InspectorController.h"
#import "CCSprite9Slice.h"
#import "PositionPropertySetter.h"

#define kCCFatFingerExpansion 70

@implementation CCBPButton

- (id) init
{
    return [self initWithTitle:@"" spriteFrame:NULL];
}

- (id) initWithTitle:(NSString *)title
{
    self = [self initWithTitle:title spriteFrame:NULL highlightedSpriteFrame:NULL disabledSpriteFrame:NULL mouseOverSpriteFrame:NULL];
    
    return self;
}

- (id) initWithTitle:(NSString *)title fontName:(NSString*)fontName fontSize:(float)size
{
    self = [self initWithTitle:title];
    self.label.fontName = fontName;
    self.label.fontSize = size;
    
    return self;
}

- (id) initWithTitle:(NSString*) title spriteFrame:(CCSpriteFrame*) spriteFrame
{
    self = [self initWithTitle:title spriteFrame:spriteFrame highlightedSpriteFrame:NULL disabledSpriteFrame:NULL mouseOverSpriteFrame:NULL];
    
    // Setup default colors for when only one frame is used
    [self setBackgroundColor:[CCColor colorWithWhite:0.7 alpha:1] forState:CCBPControlStateHighlighted];
    [self setLabelColor:[CCColor colorWithWhite:0.7 alpha:1] forState:CCBPControlStateHighlighted];
    
    [self setBackgroundOpacity:0.5f forState:CCBPControlStateDisabled];
    [self setLabelOpacity:0.5f forState:CCBPControlStateDisabled];
    
    return self;
}

- (id) initWithTitle:(NSString*) title spriteFrame:(CCSpriteFrame*) spriteFrame highlightedSpriteFrame:(CCSpriteFrame*) highlighted disabledSpriteFrame:(CCSpriteFrame*) disabled mouseOverSpriteFrame:(CCSpriteFrame*) mouseOver
{
    self = [super init];
    if (!self) return NULL;
    
    self.anchorPoint = ccp(0.5f, 0.5f);
    _imageScale = 1.0f;
    
    if (!title) title = @"";
    _state = CCBPControlStateNormal;
    
    // Setup holders for properties
    _backgroundColors = [NSMutableDictionary dictionary];
    _backgroundOpacities = [NSMutableDictionary dictionary];
    _backgroundSpriteFrames = [NSMutableDictionary dictionary];
    
    _labelColors = [NSMutableDictionary dictionary];
    _labelOpacities = [NSMutableDictionary dictionary];
    
    _zoomOnClick = 1.0f;
    
    // Setup background image
    if (spriteFrame)
    {
        _background = [CCSprite9Slice spriteWithSpriteFrame:spriteFrame];
        [self setBackgroundSpriteFrame:spriteFrame forState:CCBPControlStateNormal];
    }
    else
    {
        _background = [[CCSprite9Slice alloc] init];
    }
    
    if (highlighted)
    {
        [self setBackgroundSpriteFrame:highlighted forState:CCBPControlStateHighlighted];
    }
    
    if (disabled)
    {
        [self setBackgroundSpriteFrame:disabled forState:CCBPControlStateDisabled];
    }
    
    if (mouseOver)
    {
        [self setBackgroundSpriteFrame:mouseOver forState:CCBPControlStateMouseOver];
    }
    
    [self addProtectedChild:_background z:0];
    
    // Setup label
    _label = [CCLabelTTF labelWithString:title fontName:@"Helvetica" fontSize:14];
    _label.adjustsFontSizeToFit = NO;
    _label.horizontalAlignment = CCTextAlignmentCenter;
    _label.verticalAlignment = CCVerticalTextAlignmentCenter;
    
    [self addProtectedChild:_label z:1];
    
    // Setup original scale
    _originalScaleX = _originalScaleY = 1;
    
    [self needsLayout];
    [self stateChanged];
    
    return self;
}

- (void) layout
{
    CGSize contentSize = [self convertContentSizeToPoints:self.contentSize type:self.contentSizeType];
    CGSize paddedLabelSize = CGSizeMake(contentSize.width - (self.leftPadding + self.rightPadding), contentSize.height -  (self.topPadding + self.bottomPadding));
    
    if(_adjustsFontSizeToFit && paddedLabelSize.width>0 && paddedLabelSize.height>0)
    {
        self.label.fontSize = _fontSize;
        self.label.dimensions = CGSizeMake(paddedLabelSize.width, 0);
        if(self.label.contentSize.height>paddedLabelSize.height)
        {
            float startScale = 1.0;
            float endScale = 1.0;
            float fontSize = _fontSize;
            do
            {
                self.label.fontSize = fontSize / (endScale * 2.0);
                startScale = endScale;
                endScale = endScale*2;
            }while (self.label.contentSize.height>paddedLabelSize.height);
            float midScale;
            for(int i=0;i<4;++i)
            {
                midScale = (startScale + endScale) / 2.0f;
                self.label.fontSize = fontSize / midScale;
                if(self.label.contentSize.height>paddedLabelSize.height)
                {
                    startScale = midScale;
                }
                else
                {
                    endScale = midScale;
                }
            }
            self.label.fontSize = fontSize / (endScale * 1.05f);
        }
    }
    else
    {
        self.label.fontSize = _fontSize;
    }
    
    self.label.dimensions = paddedLabelSize;
    
    [_background setContentSize:CGSizeMake(contentSize.width / _imageScale, contentSize.height / _imageScale)];
    self.background.anchorPoint = ccp(0.5f,0.5f);
    self.background.positionType = CCPositionTypeNormalized;
    self.background.position = ccp(0.5f,0.5f);
    
    self.label.anchorPoint = ccp(0.5f,0.5f);
    self.label.positionType = CCPositionTypePoints;
    self.label.position = ccp((contentSize.width + (self.leftPadding - self.rightPadding))/2, (contentSize.height + (self.bottomPadding - self.topPadding))/2);
    
    [super layout];
}

- (void) updatePropertiesForState:(CCBPControlState)state
{
    // Update background
    ccColor4F backgroundColor = [self backgroundColorForState:state].ccColor4f;
    _background.color = [CCColor colorWithCcColor4f:backgroundColor];
    _background.opacity = [self backgroundOpacityForState:state];
    
    CCSpriteFrame* spriteFrame = [self backgroundSpriteFrameForState:state];
    if (!spriteFrame) spriteFrame = [self backgroundSpriteFrameForState:CCBPControlStateNormal];
    _background.spriteFrame = spriteFrame;
    
    // Update label
    ccColor4F labelColor = [self labelColorForState:state].ccColor4f;
    _label.fontColor = [CCColor colorWithCcColor4f:labelColor];;
    _label.opacity = [self labelOpacityForState:state];;
    
    [self needsLayout];
}

- (void) stateChanged
{
    switch (_state) {
        case CCBPControlStateNormal:
            _label.scaleX = _originalScaleX;
            _label.scaleY = _originalScaleY;
            _background.scaleX = _originalScaleX * _imageScale;
            _background.scaleY = _originalScaleY * _imageScale;
            [self updatePropertiesForState:CCBPControlStateNormal];
            break;
            
        case CCBPControlStateHighlighted:
            _label.scaleX = _originalScaleX * _zoomOnClick;
            _label.scaleY = _originalScaleY * _zoomOnClick;
            _background.scaleX = _originalScaleX * _zoomOnClick * _imageScale;
            _background.scaleY = _originalScaleY * _zoomOnClick * _imageScale;
            [self updatePropertiesForState:CCBPControlStateHighlighted];
            break;
            
        case CCBPControlStateDisabled:
            _label.scaleX = _originalScaleX;
            _label.scaleY = _originalScaleY;
            _background.scaleX = _originalScaleX * _imageScale;
            _background.scaleY = _originalScaleY * _imageScale;
            [self updatePropertiesForState:CCBPControlStateDisabled];
            break;
            
        case CCBPControlStateMouseOver:
            _label.scaleX = _originalScaleX;
            _label.scaleY = _originalScaleY;
            _background.scaleX = _originalScaleX * _imageScale;
            _background.scaleY = _originalScaleY * _imageScale;
            [self updatePropertiesForState:CCBPControlStateMouseOver];
            break;
            
        default:
            break;
    }
}

#pragma mark Properties

- (void) setLabelColor:(CCColor*)color forState:(CCBPControlState)state
{
    [_labelColors setObject:color forKey:[NSNumber numberWithInt:(int)state]];
    [self stateChanged];
}

- (CCColor*) labelColorForState:(CCBPControlState)state
{
    CCColor* color = [_labelColors objectForKey:[NSNumber numberWithInt:(int)state]];
    if (!color) color = [CCColor whiteColor];
    return color;
}

- (void) setLabelOpacity:(CGFloat)opacity forState:(CCBPControlState)state
{
    [_labelOpacities setObject:[NSNumber numberWithFloat:opacity] forKey:[NSNumber numberWithInt:(int)state]];
    [self stateChanged];
}

- (CGFloat) labelOpacityForState:(CCBPControlState)state
{
    NSNumber* val = [_labelOpacities objectForKey:[NSNumber numberWithInt:(int)state]];
    if (!val) return 1;
    return [val floatValue];
}

- (void) setBackgroundColor:(CCColor*)color forState:(CCBPControlState)state
{
    [_backgroundColors setObject:color forKey:[NSNumber numberWithInt:(int)state]];
    [self stateChanged];
}

- (CCColor*) backgroundColorForState:(CCBPControlState)state
{
    CCColor* color = [_backgroundColors objectForKey:[NSNumber numberWithInt:(int)state]];
    if (!color) color = [CCColor whiteColor];
    return color;
}

- (void) setBackgroundOpacity:(CGFloat)opacity forState:(CCBPControlState)state
{
    [_backgroundOpacities setObject:[NSNumber numberWithFloat:opacity] forKey:[NSNumber numberWithInt:(int)state]];
    [self stateChanged];
}

- (CGFloat) backgroundOpacityForState:(CCBPControlState)state
{
    NSNumber* val = [_backgroundOpacities objectForKey:[NSNumber numberWithInt:(int)state]];
    if (!val) return 1;
    return [val floatValue];
}

- (void) setBackgroundSpriteFrame:(CCSpriteFrame*)spriteFrame forState:(CCBPControlState)state
{
    if (spriteFrame)
    {
        [_backgroundSpriteFrames setObject:spriteFrame forKey:[NSNumber numberWithInt:(int)state]];
    }
    else
    {
        [_backgroundSpriteFrames removeObjectForKey:[NSNumber numberWithInt:(int)state]];
    }
    [self stateChanged];
}

- (CCSpriteFrame*) backgroundSpriteFrameForState:(CCBPControlState)state
{
    return [_backgroundSpriteFrames objectForKey:[NSNumber numberWithInt:(int)state]];
}

- (void) setTitle:(NSString *)title
{
    _label.string = title;
    [self needsLayout];
}

- (NSString*) title
{
    return _label.string;
}

- (void) setHorizontalPadding:(float)horizontalPadding
{
    _horizontalPadding = horizontalPadding;
    [self needsLayout];
}

- (void) setVerticalPadding:(float)verticalPadding
{
    _verticalPadding = verticalPadding;
    [self needsLayout];
}

- (void) setState:(CCBPControlState)state
{
    _state = state;
    [self stateChanged];
}

- (void) setZoomOnClick:(float)zoomOnClick
{
    _zoomOnClick = zoomOnClick;
    [self stateChanged];
}

- (void) setImageScale:(CGFloat) imageScale
{
    _imageScale = imageScale;
    [self stateChanged];
    [self needsLayout];
}

#pragma mark Setting properties by name

- (CCBPControlState) controlStateFromString:(NSString*)stateName
{
    CCBPControlState state = 0;
    if ([stateName isEqualToString:@"Normal"]) state = CCBPControlStateNormal;
    else if ([stateName isEqualToString:@"Highlighted"]) state = CCBPControlStateHighlighted;
    else if ([stateName isEqualToString:@"Disabled"]) state = CCBPControlStateDisabled;
    else if ([stateName isEqualToString:@"MouseOver"]) state = CCBPControlStateMouseOver;
    
    return state;
}

- (NSArray*) keysForwardedToLabel
{
    return @[@"fontName",
             @"fontColor",
             @"outlineColor",
             @"outlineWidth",
             @"shadowColor",
             @"shadowBlurRadius",
             @"shadowOffsetInPoints",
             @"shadowOffset",
             @"shadowOffsetType",
             @"horizontalAlignment",
             @"verticalAlignment"];
}

- (void) setValue:(id)value forKey:(NSString *)key
{
    if ([[self keysForwardedToLabel] containsObject:key])
    {
        [_label setValue:value forKey:key];
        [self needsLayout];
        return;
    }
    NSRange separatorRange = [key rangeOfString:@"|"];
    NSUInteger separatorLoc = separatorRange.location;
    
    if (separatorLoc == NSNotFound)
    {
        [super setValue:value forKey:key];
        return;
    }
    
    NSString* propName = [key substringToIndex:separatorLoc];
    NSString* stateName = [key substringFromIndex:separatorLoc+1];
    
    CCBPControlState state = [self controlStateFromString:stateName];
    
    [self setValue:value forKey:propName state:state];
}

- (id) valueForKey:(NSString *)key
{
    if ([[self keysForwardedToLabel] containsObject:key])
    {
        return [_label valueForKey:key];
    }
    NSRange separatorRange = [key rangeOfString:@"|"];
    NSUInteger separatorLoc = separatorRange.location;
    
    if (separatorLoc == NSNotFound)
    {
        return [super valueForKey:key];
    }
    
    NSString* propName = [key substringToIndex:separatorLoc];
    NSString* stateName = [key substringFromIndex:separatorLoc+1];
    
    CCBPControlState state = [self controlStateFromString:stateName];
    
    return [self valueForKey:propName state:state];
}

- (void) setValue:(id)value forKey:(NSString *)key state:(CCBPControlState)state
{
    if ([key isEqualToString:@"labelOpacity"])
    {
        [self setLabelOpacity:[value floatValue] forState:state];
    }
    else if ([key isEqualToString:@"labelColor"])
    {
        [self setLabelColor:value forState:state];
    }
    else if ([key isEqualToString:@"backgroundOpacity"])
    {
        [self setBackgroundOpacity:[value floatValue] forState:state];
    }
    else if ([key isEqualToString:@"backgroundColor"])
    {
        [self setBackgroundColor:value forState:state];
    }
    else if ([key isEqualToString:@"backgroundSpriteFrame"])
    {
        [self setBackgroundSpriteFrame:value forState:state];
    }
}

- (id) valueForKey:(NSString *)key state:(CCBPControlState)state
{
    if ([key isEqualToString:@"labelOpacity"])
    {
        return [NSNumber numberWithFloat:[self labelOpacityForState:state]];
    }
    else if ([key isEqualToString:@"labelColor"])
    {
        return [self labelColorForState:state];
    }
    else if ([key isEqualToString:@"backgroundOpacity"])
    {
        return [NSNumber numberWithFloat:[self backgroundOpacityForState:state]];
    }
    else if ([key isEqualToString:@"backgroundColor"])
    {
        return [self backgroundColorForState:state];
    }
    else if ([key isEqualToString:@"backgroundSpriteFrame"])
    {
        return [self backgroundSpriteFrameForState:state];
    }
    
    return NULL;
}

-(void)onSetSizeFromTexture
{
    CCSpriteFrame * spriteFrame = _backgroundSpriteFrames[@(CCBPControlStateNormal)];
    if(spriteFrame == nil)
        return;
    
    [[AppDelegate appDelegate] saveUndoStateWillChangeProperty:@"contentSize"];
    
    self.contentSizeType = CCSizeTypeUIPoints;
    self.contentSizeInPoints = spriteFrame.originalSize;
    
    [self willChangeValueForKey:@"contentSize"];
    [self didChangeValueForKey:@"contentSize"];
    [[InspectorController sharedController] refreshProperty:@"contentSize"];
    [super needsLayout];
}

-(void)onCopyNormalState
{
    [[AppDelegate appDelegate] saveUndoStateWillChangeProperty:@"copyNormalState"];
    
    [self setBackgroundColor:[self backgroundColorForState:CCBPControlStateNormal] forState:CCBPControlStateHighlighted];
    [self setBackgroundColor:[self backgroundColorForState:CCBPControlStateNormal] forState:CCBPControlStateDisabled];
    [self setBackgroundColor:[self backgroundColorForState:CCBPControlStateNormal] forState:CCBPControlStateMouseOver];
    
    [self setBackgroundOpacity:[self backgroundOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateHighlighted];
    [self setBackgroundOpacity:[self backgroundOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateDisabled];
    [self setBackgroundOpacity:[self backgroundOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateMouseOver];
    
    [self setLabelColor:[self labelColorForState:CCBPControlStateNormal] forState:CCBPControlStateHighlighted];
    [self setLabelColor:[self labelColorForState:CCBPControlStateNormal] forState:CCBPControlStateDisabled];
    [self setLabelColor:[self labelColorForState:CCBPControlStateNormal] forState:CCBPControlStateMouseOver];
    
    [self setLabelOpacity:[self labelOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateHighlighted];
    [self setLabelOpacity:[self labelOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateDisabled];
    [self setLabelOpacity:[self labelOpacityForState:CCBPControlStateNormal] forState:CCBPControlStateMouseOver];
    
    [self setBackgroundSpriteFrame:[self backgroundSpriteFrameForState:CCBPControlStateNormal] forState:CCBPControlStateHighlighted];
    [self setBackgroundSpriteFrame:[self backgroundSpriteFrameForState:CCBPControlStateNormal] forState:CCBPControlStateDisabled];
    [self setBackgroundSpriteFrame:[self backgroundSpriteFrameForState:CCBPControlStateNormal] forState:CCBPControlStateMouseOver];
    
    [[InspectorController sharedController] updateInspectorFromSelection];
    
    [super needsLayout];
}

- (void)setMarginLeft:(float)marginLeft
{
    marginLeft = clampf(marginLeft, 0, 1);
    
    if(self.marginRight + marginLeft >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The left & right margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"marginLeft"];
        return;
    }
    [self.background setMarginLeft:marginLeft];
}

- (void)setMarginRight:(float)marginRight
{
    marginRight = clampf(marginRight, 0, 1);
    if(self.marginLeft + marginRight >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The left & right margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"marginRight"];
        
        return;
    }
    
    [self.background setMarginRight:marginRight];
}

- (void)setMarginTop:(float)marginTop
{
    marginTop = clampf(marginTop, 0, 1);
    if(self.marginBottom + marginTop >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The top & bottom margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"marginTop"];
        return;
    }
    
    [self.background setMarginTop:marginTop];
    
}

- (void)setMarginBottom:(float)marginBottom
{
    marginBottom = clampf(marginBottom, 0, 1);
    if(self.marginTop + marginBottom >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The top & bottom margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"marginBottom"];
        return;
    }
    
    [self.background setMarginBottom:marginBottom];
}

- (float)marginBottom
{
    return self.background.marginBottom;
}

- (float)marginLeft
{
    return self.background.marginLeft;
}

- (float)marginRight
{
    return self.background.marginRight;
}

- (float)marginTop
{
    return self.background.marginTop;
}

-(void) setAdjustsFontSizeToFit:(BOOL)value
{
    _adjustsFontSizeToFit = value;
    [self needsLayout];
}

- (void) setFontSize:(CGFloat)fontSize
{
    _fontSize = fontSize;
    [self needsLayout];
}

- (void) setLeftPadding:(float)leftPadding
{
    _leftPadding = leftPadding;
    [self needsLayout];
}

- (void) setRightPadding:(float)rightPadding
{
    _rightPadding = rightPadding;
    [self needsLayout];
}

- (void) setTopPadding:(float)topPadding
{
    _topPadding = topPadding;
    [self needsLayout];
}

- (void) setBottomPadding:(float)bottomPadding
{
    _bottomPadding = bottomPadding;
    [self needsLayout];
}

- (void) setContentSize:(CGSize) contentSize
{
    [super setContentSize:contentSize];
    [self needsLayout];
}

- (void) setContentSizeType:(CCSizeType)contentSizeType
{
    [super setContentSizeType:contentSizeType];
    [self needsLayout];
}

@end

