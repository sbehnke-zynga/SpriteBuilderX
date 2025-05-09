//
//  CCBPSlider.m
//  SpriteBuilder
//
//  Created by Viktor on 10/28/13.
//
//

#import "CCBPScrollBar.h"
#import "AppDelegate.h"
#import "InspectorController.h"
#import "CCControlSubclass.h"

#import "CCControlSubclass.h"
#import "CCTouch.h"

@implementation CCBPScrollBar

- (id) init
{
    self = [super init];
    if (!self) return NULL;
    
    _state = CCBPControlStateNormal;
    
    _handleSpriteFrames = [[NSMutableDictionary alloc] init];
    _background = [[CCSprite9Slice alloc] init];
    _background.anchorPoint = ccp(0.5f,0.5f);
    _background.position = ccp(0.5f,0.5f);
    _background.positionType = CCPositionTypeNormalized;
    _background.contentSizeType = CCSizeTypePoints;
    
    _handle = [[CCSprite9Slice alloc] init];
    _handle.anchorPoint = ccp(0.5f,0.5f);
    _handle.positionType = CCPositionTypePoints;
    _percent = 0.0f;
    _imageScale = 1.0f;
    _barSize = 100;
    
    [self addProtectedChild:_background];
    [self addProtectedChild:_handle];
    
    [self needsLayout];
    [self stateChanged];
    
    return self;
}

- (void) updateSliderPositionFromValue
{
    CGSize size = [self convertContentSizeToPoints: self.contentSize type:self.contentSizeType];
    float val = clampf((double)(_percent) / 100.0f, 0.0f, 1.0f);
    if(_vertical)
        _handle.position = ccp(size.width/2.0f, size.height * (1.0f - val));
    else
        _handle.position = ccp(size.width * val, size.height/2.0f);
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
    
    if(_vertical)
    {
        [_background setContentSize:CGSizeMake(sizeInPoints.height / _imageScale, sizeInPoints.width / _imageScale)];
        _background.rotation = 90.0f;
        [_handle setContentSize:CGSizeMake(sizeInPoints.height / _imageScale * (_barSize / 100.0f), sizeInPoints.width / _imageScale)];
        _handle.rotation = 90.0f;
    }
    else
    {
        [_background setContentSize:CGSizeMake(sizeInPoints.width / _imageScale, sizeInPoints.height / _imageScale)];
        _background.rotation = 0.0f;
        [_handle setContentSize:CGSizeMake(sizeInPoints.width / _imageScale * (_barSize / 100.0f), sizeInPoints.height / _imageScale)];
        _handle.rotation = 0.0f;
    }
    _background.scale = _imageScale;
    _handle.scale = _imageScale;
    
    [self updateSliderPositionFromValue];
    [super layout];
}

#pragma mark Properties

- (void) setBarSize:(float) barSize
{
    _barSize = barSize;
    [self needsLayout];
}

- (void) setVertical:(BOOL)vertical
{
    _vertical = vertical;
    [self needsLayout];
}

- (void) setPercent:(float)percent
{
    _percent = percent;
    
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

- (void)setHandleMarginLeft:(float)marginLeft
{
    marginLeft = clampf(marginLeft, 0, 1);
    
    if(self.handleMarginRight + marginLeft >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The left & right margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"handleMarginLeft"];
        return;
    }
    _handleMarginLeft = marginLeft;
    [_handle setMarginLeft:marginLeft];
}

- (void)setHandleMarginRight:(float)marginRight
{
    marginRight = clampf(marginRight, 0, 1);
    if(self.handleMarginLeft + marginRight >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The left & right margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"handleMarginRight"];
        
        return;
    }
    
    _handleMarginRight = marginRight;
    [_handle setMarginRight:marginRight];
}

- (void)setHandleMarginTop:(float)marginTop
{
    marginTop = clampf(marginTop, 0, 1);
    if(self.handleMarginBottom + marginTop >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The top & bottom margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"handleMarginTop"];
        return;
    }
    
    _handleMarginTop = marginTop;
    [_handle setMarginTop:marginTop];
    
}

- (void)setHandleMarginBottom:(float)marginBottom
{
    marginBottom = clampf(marginBottom, 0, 1);
    if(self.handleMarginTop + marginBottom >= 1)
    {
        [[AppDelegate appDelegate] modalDialogTitle:@"Margin Restrictions" message:@"The top & bottom margins should add up to less than 1"];
        [[InspectorController sharedController] refreshProperty:@"handleMarginBottom"];
        return;
    }
    
    _handleMarginBottom = marginBottom;
    [_handle setMarginBottom:marginBottom];
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

- (NSArray*) ccbExcludePropertiesForSave
{
    return [NSArray arrayWithObjects:
            @"barSize",
            nil];
}

@end
