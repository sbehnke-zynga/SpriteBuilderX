//
//  CCBPSlider.m
//  SpriteBuilder
//
//  Created by Viktor on 10/28/13.
//
//

#import "CCBPSlider.h"
#import "AppDelegate.h"
#import "InspectorController.h"
#import "CCControlSubclass.h"

#import "CCSlider.h"
#import "CCControlSubclass.h"
#import "CCTouch.h"

@implementation CCBPSlider

- (id) init
{
    self = [super init];
    if (!self) return NULL;
    
    _state = CCBPControlStateNormal;
    
    _handleSpriteFrames = [[NSMutableDictionary alloc] init];
    _background = [[CCSprite9Slice alloc] init];
    _background.anchorPoint = ccp(0.f,0.f);
    _background.position = ccp(0.f,0.f);
    _background.positionType = CCPositionTypePoints;
    _background.contentSizeType = CCSizeTypePoints;
    
    _progress = [[CCSprite9Slice alloc] init];
    _progress.anchorPoint = ccp(0.f,0.f);
    _progress.position = ccp(0.f,0.f);
    _progress.positionType = CCPositionTypePoints;
    _progress.contentSizeType = CCSizeTypePoints;
    
    _handle = [[CCSprite alloc] init];
    _handle.anchorPoint = ccp(0.5f,0.5f);
    _handle.positionType = CCPositionTypePoints;
    
    _maxPercent = 100;
    _percent = 0;
    _imageScale = 1.0f;
    
    [self addProtectedChild:_background];
    [self addProtectedChild:_progress];
    [self addProtectedChild:_handle];
    
    [self needsLayout];
    [self stateChanged];
    
    return self;
}

- (void) updateSliderPositionFromValue
{
    CGSize size = [self convertContentSizeToPoints: self.contentSize type:self.contentSizeType];
    float val = clampf((double)_percent / _maxPercent, 0.0f, 1.0f);
    _handle.position = ccp(size.width * val, size.height/2.0f);
    [_progress setContentSize:CGSizeMake(size.width / _imageScale * val, size.height / _imageScale)];
}

- (void) stateChanged
{
    CCSpriteFrame *frame = [_handleSpriteFrames objectForKey:[NSNumber numberWithInt:(int)_state]];
    if(frame)
        [_handle setSpriteFrame:frame];
    else
        [_handle setSpriteFrame:[_handleSpriteFrames objectForKey:[NSNumber numberWithInt:CCBPControlStateNormal]]];
}

- (void) layout
{
    CGSize sizeInPoints = [self convertContentSizeToPoints: self.contentSize type:self.contentSizeType];
    
    [_background setContentSize:CGSizeMake(sizeInPoints.width / _imageScale, sizeInPoints.height / _imageScale)];
    _background.scale = _imageScale;

    _progress.scale = _imageScale;
    
    _handle.scale = _imageScale;
    
    [self updateSliderPositionFromValue];
    [super layout];
}

#pragma mark Properties

- (void) setPercent:(int)percent
{
    _percent = percent;
    
    [self updateSliderPositionFromValue];
}

- (void) setMaxPercent:(int)maxPercent
{
    _maxPercent = maxPercent;
    
    [self updateSliderPositionFromValue];
}

- (void) setBackgroundSpriteFrame:(CCSpriteFrame*)spriteFrame
{
    _background.spriteFrame = spriteFrame;
}

- (CCSpriteFrame*) backgroundSpriteFrame
{
    return _background.spriteFrame;
}

- (void) setProgressSpriteFrame:(CCSpriteFrame*)spriteFrame
{
    _progress.spriteFrame = spriteFrame;
}

- (CCSpriteFrame*) progressSpriteFrame
{
    return _progress.spriteFrame;
}

- (void) setHandleSpriteFrame:(CCSpriteFrame*)spriteFrame forState:(CCBPControlState)state
{
    if (spriteFrame)
        [_handleSpriteFrames setObject:spriteFrame forKey:[NSNumber numberWithInt:(int)state]];
    else
        [_handleSpriteFrames removeObjectForKey:[NSNumber numberWithInt:(int)state]];
    [self stateChanged];
}

- (CCSpriteFrame*) handleSpriteFrameForState:(CCBPControlState)state
{
    return [_handleSpriteFrames objectForKey:[NSNumber numberWithInt:(int)state]];
}

- (void) setState:(CCBPControlState)state
{
    _state = state;
    [self stateChanged];
}

- (void) setImageScale:(CGFloat) imageScale
{
    _imageScale = imageScale;
    [self needsLayout];
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
    _marginLeft = marginLeft;
    [_background setMarginLeft:marginLeft];
    [_progress setMarginLeft:marginLeft];
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
    
    _marginRight = marginRight;
    [_background setMarginRight:marginRight];
    [_progress setMarginRight:marginRight];
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
    
    _marginTop = marginTop;
    [_background setMarginTop:marginTop];
    [_progress setMarginTop:marginTop];
    
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
    
    _marginBottom = marginBottom;
    [_background setMarginBottom:marginBottom];
    [_progress setMarginBottom:marginBottom];
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

- (void) setValue:(id)value forKey:(NSString *)key
{
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
    if ([key isEqualToString:@"handleSpriteFrame"])
    {
        [self setHandleSpriteFrame:value forState:state];
    }
}

- (id) valueForKey:(NSString *)key state:(CCBPControlState)state
{
    if ([key isEqualToString:@"handleSpriteFrame"])
    {
        return [self handleSpriteFrameForState:state];
    }
    
    return NULL;
}

-(void)onSetSizeFromTexture
{
    CCSpriteFrame * spriteFrame = _background.spriteFrame;
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

@end
