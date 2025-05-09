/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2011 Viktor Lidholt
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

#import "CocosScene.h"
#import "CCBGlobals.h"
#import "SceneGraph.h"
#import "AppDelegate.h"
#import "CCBReaderInternalV1.h"
#import "NodeInfo.h"
#import "PlugInManager.h"
#import "PlugInNode.h"
#import "RulersLayer.h"
#import "GuidesLayer.h"
#import "NotesLayer.h"
#import "SnapLayer.h"
#import "CCBTransparentWindow.h"
#import "CCBTransparentView.h"
#import "PositionPropertySetter.h"
#import "CCBGLView.h"
#import "MainWindow.h"
#import "CCNode+NodeInfo.h"
#import "SequencerHandler.h"
#import "SequencerSequence.h"
#import "SequencerNodeProperty.h"
#import "SequencerKeyframe.h"
#import "Tupac.h"
#import "PhysicsHandler.h"
#import "CCBUtil.h"
#import "CCTextureCache.h"
#import "NSArray+Query.h"
#import "GeometryUtil.h"
#import "NSPasteboard+CCB.h"
#import "InspectorController.h"
#import "ResolutionSetting.h"
#import "CCBDocument.h"
#import "CCBWriterInternal.h"
#import "ResourceManagerUtil.h"
#import "ResourceTypes.h"
#import "RMResource.h"
#import "RMSpriteFrame.h"
#import "TexturePropertySetter.h"
#import "SpriteObjectMenuFlipController.h"

#define kCCBSelectionOutset 3
#define kCCBSinglePointSelectionRadius 23
#define kCCBAnchorPointRadius 3
#define kCCBTransformHandleRadius 5

static CocosScene* sharedCocosScene;
static NSString * kZeroContentSizeImage = @"sel-round.png";

@interface Segment : NSObject {
@public
    CGPoint A;
    CGPoint B;
}
@end

@implementation Segment

-(id) initWithA:(CGPoint ) a b:(CGPoint) b {
    self = [super init];
    A = a;
    B = b;
    return self;
}

@end

@implementation CocosScene

@synthesize bgLayer;
@synthesize anchorPointCompensationLayer;
@synthesize rootNode;
@synthesize isMouseTransforming;
@synthesize scrollOffset;
@dynamic    currentTool;
@synthesize guideLayer;
@synthesize rulerLayer;
@synthesize notesLayer;
@synthesize snapLayer;
@synthesize physicsLayer;

+(id) sceneWithAppDelegate:(AppDelegate*)app
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	CocosScene *layer = [[CocosScene alloc] initWithAppDelegate:app];
    sharedCocosScene = layer;
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

+ (CocosScene*) cocosScene
{
	WARN(sharedCocosScene, @"sharedCocosScene is nil");
    return sharedCocosScene;
}

-(void) setupEditorNodes
{
    // Rulers
    rulerLayer = [RulersLayer node];
    rulerLayer.visible = appDelegate.showRulers;
    [self addChild:rulerLayer z:7];
    
    // Guides
    guideLayer = [GuidesLayer node];
    [self addChild:guideLayer z:3];
    
    // Sticky notes
    notesLayer = [NotesLayer node];
    [self addChild:notesLayer z:7];
    
    // Snapping
    snapLayer = [SnapLayer node];
    [self addChild:snapLayer z:4];
    
    // Selection layer
    selectionLayer = [CCNode node];
    selectionLayer.name = @"selectionLayer";
    [self addChild:selectionLayer z:5];
    
    // Physics layer
    physicsLayer = [CCNode node];
    physicsLayer.name = @"physicsLayer";
    [self addChild:physicsLayer z:6];
    
    // Border layer
    borderLayer = [CCNode node];
    [self addChild:borderLayer z:1];
	
	CCColor* borderColor = [CCColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.7];
    
    borderBottom = [CCNodeColor nodeWithColor:borderColor];
    borderTop = [CCNodeColor nodeWithColor:borderColor];
    borderLeft = [CCNodeColor nodeWithColor:borderColor];
    borderRight = [CCNodeColor nodeWithColor:borderColor];
    
    borderBottom.userInteractionEnabled = NO;
    borderTop.userInteractionEnabled = NO;
    borderLeft.userInteractionEnabled = NO;
    borderRight.userInteractionEnabled = NO;
    
    [borderLayer addChild:borderBottom];
    [borderLayer addChild:borderTop];
    [borderLayer addChild:borderLeft];
    [borderLayer addChild:borderRight];
    
    borderDevice = [CCSprite node];
    [borderLayer addChild:borderDevice z:1];
    
    // Gray background
    bgLayer = [CCNodeColor nodeWithColor:[CCColor grayColor] width:4096 height:4096];
    bgLayer.position = ccp(0,0);
    bgLayer.anchorPoint = ccp(0,0);
    bgLayer.userInteractionEnabled = NO;
    [self addChild:bgLayer z:-1];
    
    // Black content layer
    stageBgLayer = [CCNodeColor nodeWithColor:[CCColor blackColor] width:0 height:0];
    stageBgLayer.anchorPoint = ccp(0.5,0.5);
    stageBgLayer.userInteractionEnabled = NO;
    stageBgLayer.name = @"stageBgLayer";
    //stageBgLayer.ignoreAnchorPointForPosition = NO;
    [self addChild:stageBgLayer z:0];
    
    contentLayer = [CCNode node];
    contentLayer.name = @"contentLayer";
    contentLayer.contentSizeType = CCSizeTypeNormalized;
    contentLayer.contentSize = CGSizeMake(1, 1);
    
    anchorPointCompensationLayer = [CCNode node];
    anchorPointCompensationLayer.contentSizeType = CCSizeTypeNormalized;
    anchorPointCompensationLayer.contentSize = CGSizeMake(1, 1);
    
    [stageBgLayer addChild:anchorPointCompensationLayer];
    [anchorPointCompensationLayer addChild:contentLayer];
    
    stageJointsLayer = [CCNode node];
    stageJointsLayer.name = @"stageJointsLayer";
    stageJointsLayer.anchorPoint = ccp(0.5,0.5);
    stageJointsLayer.userInteractionEnabled = NO;
     [self addChild:stageJointsLayer z:1];
    
    // Joints Layer
    jointsLayer = [CCNode node];
    jointsLayer.name = @"jointsLayer";
    jointsLayer.contentSizeType = CCSizeTypeNormalized;
    jointsLayer.contentSize = CGSizeMake(1, 1);
    [stageJointsLayer addChild:jointsLayer];

}

- (void) setStageBorder:(int)type
{
    borderDevice.visible = NO;
    
    if (stageBgLayer.contentSize.width == 0 || stageBgLayer.contentSize.height == 0)
    {
        type = kCCBBorderNone;
        stageBgLayer.visible = NO;
    }
    else
    {
        stageBgLayer.visible = YES;
    }
    
    if (type == kCCBBorderDevice)
    {
        [borderBottom setOpacity:1.0f];
        [borderTop setOpacity:1.0f];
        [borderLeft setOpacity:1.0f];
        [borderRight setOpacity:1.0f];
        
        CCTexture* deviceTexture = NULL;
        
        CGSize realStageBgLayer = CGSizeMake(stageBgLayer.contentSize.width * [CCDirector sharedDirector].contentScaleFactor,stageBgLayer.contentSize.height * [CCDirector sharedDirector].contentScaleFactor);
        
        DeviceBorder *deviceBorder = [appDelegate orientedDeviceTypeForSize:realStageBgLayer];
        
        if(deviceBorder)
        {
            deviceTexture = [[CCTextureCache sharedTextureCache] addImage:deviceBorder.frameName];
            borderDeviceScale = deviceBorder.scale;
            if (deviceTexture)
            {
                if (deviceBorder.rotated) borderDevice.rotation = 90;
                else borderDevice.rotation = 0;
                
                borderDevice.texture = deviceTexture;
                borderDevice.textureRect = CGRectMake(0, 0, deviceTexture.contentSize.width, deviceTexture.contentSize.height);
                
                borderDevice.visible = YES;
            }
        }
        
        [borderBottom setOpacity:1.0f];
        [borderTop setOpacity:1.0f];
        [borderLeft setOpacity:1.0f];
        [borderRight setOpacity:1.0f];
        
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderTransparent)
    {
        [borderBottom   setOpacity:0.5f];
        [borderTop      setOpacity:0.5f];
        [borderLeft     setOpacity:0.5f];
        [borderRight    setOpacity:0.5f];
        
        borderLayer.visible = YES;
    }
    else if (type == kCCBBorderOpaque)
    {
        [borderBottom setOpacity:1.0f];
        [borderTop setOpacity:1.0f];
        [borderLeft setOpacity:1.0f];
        [borderRight setOpacity:1.0f];
        borderLayer.visible = YES;
    }
    else
    {
        borderLayer.visible = NO;
    }
    
    stageBorderType = type;
    
    [appDelegate updateCanvasBorderMenu];
}

- (int) stageBorder
{
    return stageBorderType;
}

- (void) setStageColor: (int) type forDocDimensionsType: (int) docDimensionsType
{
    CCColor *color;
    switch (type)
    {
        case kCCBCanvasColorBlack:
            color = [CCColor blackColor];
            break;
        case kCCBCanvasColorWhite:
            color = [CCColor whiteColor];
            break;
        case kCCBCanvasColorLightGray:
            color = [CCColor grayColor];
            break;
        case kCCBCanvasColorMediumGray:
            color = [CCColor colorWithRed:83.0/255.0 green:83.0/255.0 blue:83.0/255.0]; //Adobe Illustrator values
            break;
        case kCCBCanvasColorDarkGray:
            color = [CCColor colorWithRed:50/255.0 green:50/255.0 blue:50/255.0];
            break;
        case kCCBCanvasColorOrange:
            color = [CCColor orangeColor];
            break;
        case kCCBCanvasColorGreen:
            color = [CCColor greenColor];
            break;
        default:
            NSAssert (NO, @"Illegal stage color");
    }
    NSAssert(color != nil, @"No stage color");
    stageBgLayer.color = color;
}

- (void) setBgColor:(int) colorType {
    CCColor *color;
    switch (colorType)
    {
        case kCCBCanvasColorBlack:
            color = [CCColor blackColor];
            break;
        case kCCBCanvasColorWhite:
            color = [CCColor whiteColor];
            break;
        case kCCBCanvasColorLightGray:
            color = [CCColor grayColor];
            break;
        case kCCBCanvasColorMediumGray:
            color = [CCColor colorWithRed:83.0/255.0 green:83.0/255.0 blue:83.0/255.0]; //Adobe Illustrator values
            break;
        case kCCBCanvasColorDarkGray:
            color = [CCColor colorWithRed:50/255.0 green:50/255.0 blue:50/255.0];
            break;
        case kCCBCanvasColorOrange:
            color = [CCColor orangeColor];
            break;
        case kCCBCanvasColorGreen:
            color = [CCColor greenColor];
            break;
        default:
            NSAssert (NO, @"Illegal bg color");
    }
    NSAssert(color != nil, @"No bg color");
    bgLayer.color = color;
    
    [borderBottom setColor:color];
    [borderTop setColor:color];
    [borderLeft setColor:color];
    [borderRight setColor:color];
}

- (void) setupDefaultNodes
{
}

#pragma mark Stage properties

- (void) setStageSize: (CGSize) size centeredOrigin:(BOOL)centeredOrigin
{
    snapLinesNeedUpdate = YES; // This will cause the snap/alignment lines to update after undo/redo are called
    stageBgLayer.contentSize = size;
    stageJointsLayer.contentSize = size;

    
    if (centeredOrigin)
    {
        contentLayer.position = ccp(size.width/2, size.height/2);
        jointsLayer.position = contentLayer.position;
    }
    else
    {
        contentLayer.position = ccp(0,0);
        jointsLayer.position = contentLayer.position;
    }
    
    [self setStageBorder:stageBorderType];
    
    
    if (renderedScene)
    {
        [self removeChild:renderedScene cleanup:YES];
        renderedScene = NULL;
    }
    
    if (size.width > 0 && size.height > 0 && size.width <= 1024 && size.height <= 1024)
    {
        // Use a new autorelease pool
        // Otherwise, two successive calls to the running method (_cmd) cause a crash!
        @autoreleasepool {
        
            renderedScene = [CCRenderTexture renderTextureWithWidth:size.width height:size.height];
            renderedScene.anchorPoint = ccp(0.5f,0.5f);
            [self addChild:renderedScene];

        }
    }
}

- (CGSize) stageSize
{
    return stageBgLayer.contentSize;
}

- (BOOL) centeredOrigin
{
    return (contentLayer.position.x != 0);
}

- (void) setStageZoom:(float) zoom
{
    float zoomFactor = zoom/stageZoom;
    
    scrollOffset = ccpMult(scrollOffset, zoomFactor);
    
    stageBgLayer.scale = zoom;
    borderDevice.scale = zoom * borderDeviceScale;
    stageJointsLayer.scale = zoom;
    
    stageZoom = zoom;
    snapLinesNeedUpdate = YES;
}

- (float) stageZoom
{
    return stageZoom;
}

#pragma mark Extra properties

- (void) setupExtraPropsForNode:(CCNode*) node
{
    [node setExtraProp:[NSNumber numberWithInt:-1] forKey:@"tag"];
    [node setExtraProp:[NSNumber numberWithBool:YES] forKey:@"lockedScaleRatio"];
    
    [node setExtraProp:@"" forKey:@"customClass"];
    [node setExtraProp:[NSNumber numberWithInt:0] forKey:@"memberVarAssignmentType"];
    [node setExtraProp:@"" forKey:@"memberVarAssignmentName"];
    
    [node setExtraProp:[NSNumber numberWithBool:NO] forKey:@"isExpanded"];
}

#pragma mark Replacing content

- (void) replaceSceneNodes:(SceneGraph*)sceneGraph
{
    [contentLayer removeChild:rootNode cleanup:YES];
    [jointsLayer removeAllChildrenWithCleanup:YES];
    
    self.rootNode = sceneGraph.rootNode;
    
    if (sceneGraph.rootNode)
        [contentLayer addChild:sceneGraph.rootNode];
    
    if(sceneGraph.joints.node)
        [jointsLayer addChild:sceneGraph.joints.node];
}

#pragma mark Handle selections

- (float) selectionZoom
{
    if(stageZoom>1.0f)
        return 1.0f;
    else
        return sqrt(stageZoom);
}

- (BOOL) selectedNodeHasReadOnlyProperty:(NSString*)prop
{
    CCNode* selectedNode = appDelegate.selectedNode;
    
    if (!selectedNode) return NO;
    NodeInfo* info = selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    NSDictionary* propInfo = [plugIn.nodePropertiesDict objectForKey:prop];
    return [[propInfo objectForKey:@"readOnly"] boolValue];
}


-(void)renderBorder:(CCNode*)node
{
	// Selection corners in world space
	CGPoint points[8]; //{bl,br,tr,tl}
	[self getCornerPointsForNode:node withPoints:points];
	
    CCSprite* blSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* brSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* tlSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* trSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    
    CCSprite* lSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* bSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* rSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    CCSprite* tSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
    
    blSprt.position = points[0];
    brSprt.position = points[1];
    trSprt.position = points[2];
    tlSprt.position = points[3];
    
    lSprt.position = points[4];
    bSprt.position = points[5];
    rSprt.position = points[6];
    tSprt.position = points[7];
    
    [selectionLayer addChild:blSprt];
    [selectionLayer addChild:brSprt];
    [selectionLayer addChild:tlSprt];
    [selectionLayer addChild:trSprt];
    
    [selectionLayer addChild:lSprt];
    [selectionLayer addChild:bSprt];
    [selectionLayer addChild:rSprt];
    [selectionLayer addChild:tSprt];
    
    CCDrawNode* drawing = [CCDrawNode node];
    float borderWidth = 1.0 / [CCDirector sharedDirector].contentScaleFactor;
    [drawing drawPolyWithVerts:points count:4
                     fillColor:[CCColor clearColor]
                   borderWidth:borderWidth
                   borderColor:[CCColor colorWithRed:1 green:1 blue:1 alpha:0.3]];
    [selectionLayer addChild:drawing z:-1];

}

-(void) updateMouseSelection {
  
    if (mouseSelectPosDown.x != 0 && mouseSelectPosDown.y != 0 &&
        mouseSelectPosMove.x != 0 && mouseSelectPosMove.y != 0 &&
        ccpDistance(mouseSelectPosDown, mouseSelectPosMove) > 2.0 &&
        currentMouseTransform == kCCBTransformHandleMouseSelect) {//kCCBTransformHandleMove && currentMouseTransform != kCCBTransformHandleDownInside) {
        
        CCDrawNode *selectNode = [CCDrawNode node];
        float borderWidth = 1.0 / [CCDirector sharedDirector].contentScaleFactor;
        
        CGPoint points[4];
        points[0] = mouseSelectPosDown;
        points[1] = ccp(mouseSelectPosMove.x, mouseSelectPosDown.y);
        points[2] = mouseSelectPosMove;
        points[3] = ccp(mouseSelectPosDown.x,mouseSelectPosMove.y);

        [selectNode drawPolyWithVerts:points
                                count:4
                            fillColor:[CCColor clearColor] borderWidth:borderWidth
                          borderColor:[CCColor colorWithRed:1 green:1 blue:1 alpha:1.0]];

        [selectionLayer addChild:selectNode z:-1];
    }
}

- (void) updateSelection
{
    NSArray* nodes = appDelegate.selectedNodes;
    
    uint overTypeField = 0x0;
    
    if (nodes.count > 0)
    {
        for (CCNode* node in nodes)
        {
            //Don't display if special case rendering flag is present.
            if([[node extraPropForKey:@"disableStageRendering"] boolValue])
            {
                continue;
            }
            
            if(node.locked)
            {
                //Locked nodes shouldn't render
                continue;
            }
            
            
            {
                CGPoint localAnchor = ccp(node.anchorPoint.x * node.contentSizeInPoints.width,
                                          node.anchorPoint.y * node.contentSizeInPoints.height);
                //when changing size, anchor temporary changed too for size operation
                //but we should display real anchor of node
                if (currentMouseTransform == kCCBTransformHandleSize) {
                    localAnchor = ccp(anchorBefore.x * node.contentSizeInPoints.width,
                                      anchorBefore.y * node.contentSizeInPoints.height);
                }
                CGPoint anchorPointPos = ccpRound([node convertToWorldSpace:localAnchor]);
                
                CCSprite* anchorPointSprite = [CCSprite spriteWithImageNamed:@"select-pt.png"];
                anchorPointSprite.position = anchorPointPos;
                [selectionLayer addChild:anchorPointSprite z:1];
                
                CGPoint points[8]; //{bl,br,tr,tl}
                BOOL isContentSizeZero = NO;
                
                if (node.contentSize.width > 0 && node.contentSize.height > 0)
                {
                    // Selection corners in world space
                    [self getCornerPointsForNode:node withPoints:points];
                    
                    CCSprite* blSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* brSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* tlSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* trSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    
                    CCSprite* lSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* bSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* rSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    CCSprite* tSprt = [CCSprite spriteWithImageNamed:@"select-corner.png"];
                    
                    blSprt.position = points[0];
                    brSprt.position = points[1];
                    trSprt.position = points[2];
                    tlSprt.position = points[3];
                    [selectionLayer addChild:blSprt];
                    [selectionLayer addChild:brSprt];
                    [selectionLayer addChild:tlSprt];
                    [selectionLayer addChild:trSprt];
                    
                    NodeInfo* nodeInfo = node.userObject;
                    if (nodeInfo) {
//                        NSDictionary* propInfo = [nodeInfo.plugIn.nodePropertiesDict objectForKey:@"contentSize"];
//                        BOOL disabledContentSize = CGSizeEqualToSize(transformSizeNode.contentSizeInPoints, CGSizeZero);
                        
                        lSprt.position = points[4];
                        rSprt.position = points[6];
                        [selectionLayer addChild:lSprt];
                        [selectionLayer addChild:rSprt];
        
                        bSprt.position = points[5];
                        tSprt.position = points[7];
                        [selectionLayer addChild:bSprt];
                        [selectionLayer addChild:tSprt];
                    }

                    CCDrawNode* drawing = [CCDrawNode node];
                
                    float borderWidth = 1.0 / [CCDirector sharedDirector].contentScaleFactor;
                    
                    [drawing drawPolyWithVerts:points count:4 fillColor:[CCColor clearColor] borderWidth:borderWidth borderColor:[CCColor colorWithRed:1 green:1 blue:1 alpha:0.3]];
                    
                    [selectionLayer addChild:drawing z:-1];
                }
                else
                {
                    isContentSizeZero = YES;
                    CGPoint pos = [node convertToWorldSpace: ccp(0,0)];
                    

                    CCSprite* sel = [CCSprite spriteWithImageNamed:kZeroContentSizeImage];
                    sel.anchorPoint = ccp(0.5f, 0.5f);
                    sel.position = pos;
                    [selectionLayer addChild:sel];
                    
                    [self getCornerPointsForZeroContentSizeNode:node withImageContentSize:sel.contentSizeInPoints withPoints:points];
                }
				
				
                if(!isContentSizeZero && !(overTypeField & kCCBToolAnchor) && currentMouseTransform == kCCBTransformHandleNone)
                {
                    if([self isOverAnchor:node withPoint:mousePos])
                    {
                        overTypeField |= kCCBToolAnchor;
                    }
                }

                if(!(overTypeField & kCCBToolRotate) && currentMouseTransform == kCCBTransformHandleNone)
                {
                    if([self isOverRotation:mousePos withPoints:points withCorner:&cornerIndex withOrientation:&cornerOrientation])
                    {
                        overTypeField |= kCCBToolRotate;
                    }
                }

                if(!isContentSizeZero &&!(overTypeField & kCCBToolSize) && currentMouseTransform == kCCBTransformHandleNone)
                {
                   if([self isOverSize:mousePos withPoints:points withCorner:&cornerIndex withOrientation:&cornerOrientation])
                   {
                       overTypeField |= kCCBToolSize;
                   }
                }
                
                if(!(overTypeField & kCCBToolTranslate) && currentMouseTransform == kCCBTransformHandleNone)
                {
                    if([self isOverContentBorders:mousePos withPoints:points])
                    {
                        overTypeField |= kCCBToolTranslate;
                    }
                }
            }
        }
    }
    
    
    
    if(currentMouseTransform == kCCBTransformHandleNone)
    {
        if(!(overTypeField & currentTool))
        {
            self.currentTool = kCCBToolSelection;
        }
        
        
        if (overTypeField)
        {
            for(int i = 0; (1 << i) != kCCBToolMax; i++)
            {
                CCBTool type = (1 << i);
                if(overTypeField & type && self.currentTool > type)
                {
                    self.currentTool = type; 
                    break;
                }
            }
        }
    }
}

- (void) selectBehind
{
    if (currentNodeAtSelectionPtIdx < 0) return;
    
    currentNodeAtSelectionPtIdx -= 1;
    if (currentNodeAtSelectionPtIdx < 0)
    {
        currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    }
    if (nodesAtSelectionPt.count) {
        [appDelegate setSelectedNodes:[NSArray arrayWithObject:[nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx]]];
    }
}

//{bl,br,tr,tl}
-(void)getCornerPointsForNode:(CCNode*)node withPoints:(CGPoint*)points
{
    // Selection corners in world space
    points[0] = ccpRound([node convertToWorldSpace: ccp(0, 0)]);
    points[1] = ccpRound([node convertToWorldSpace: ccp(node.contentSizeInPoints.width, 0)]);
    points[2] = ccpRound([node convertToWorldSpace: ccp(node.contentSizeInPoints.width, node.contentSizeInPoints.height)]);
    points[3] = ccpRound([node convertToWorldSpace: ccp(0, node.contentSizeInPoints.height)]);
    
    points[4] = ccpRound([node convertToWorldSpace: ccp(0, node.contentSizeInPoints.height / 2)]);
    points[5] = ccpRound([node convertToWorldSpace: ccp(node.contentSizeInPoints.width / 2, 0)]);
    points[6] = ccpRound([node convertToWorldSpace: ccp(node.contentSizeInPoints.width, node.contentSizeInPoints.height / 2)]);
    points[7] = ccpRound([node convertToWorldSpace: ccp(node.contentSizeInPoints.width / 2, node.contentSizeInPoints.height)]);
  
}

//{bl,br,tr,tl}
-(void)getCornerPointsForZeroContentSizeNode:(CCNode*)node withImageContentSize:(CGSize)contentSize withPoints:(CGPoint*)points
{
    //Hard coded offst
    const CGPoint cornerPos = {11.0f,11.0f};
    
    CGPoint diaganol = ccp(contentSize.width/2, contentSize.height/2);
    diaganol = ccpSub(diaganol, cornerPos);
    CGPoint position  = [node convertToWorldSpace:ccp(0.0f,0.0f)];
    
    points[0] = ccpRound( ccpAdd(position, ccpMult(diaganol, -1.0f)));
    points[1] = ccpRound( ccpAdd(position,ccpRPerp(diaganol)));
    points[2] = ccpRound( ccpAdd(position,diaganol));
    points[3] = ccpRound( ccpAdd(position, ccpPerp(diaganol)));
    points[4] = ccpRound(ccp(points[0].x, (points[0].y + points[2].y) / 2));
    points[5] = ccpRound(ccp((points[0].x + points[2].x) / 2, points[0].y));
    points[6] = ccp(points[2].x, points[4].y);
    points[7] = ccp(points[5].x, points[2].y);

}

- (BOOL) isOverAnchor:(CCNode*)node withPoint:(CGPoint)pt
{
    CGPoint localAnchor = ccp(node.anchorPoint.x * node.contentSizeInPoints.width,
                              node.anchorPoint.y * node.contentSizeInPoints.height);
    
    CGPoint center = [node convertToWorldSpace:localAnchor];

    if (ccpDistance(pt, center) < kCCBAnchorPointRadius * [self selectionZoom])
        return YES;
    
    return NO;
}

- (BOOL) isOverContentBorders:(CGPoint)_mousePoint withPoints:(const CGPoint *)points /*{bl,br,tr,tl}*/ 
{
    CGMutablePathRef mutablePath = CGPathCreateMutable();
    CGPathAddLines(mutablePath, nil, points, 4 * [self selectionZoom]);
    CGPathCloseSubpath(mutablePath);
    BOOL result = CGPathContainsPoint(mutablePath, nil, _mousePoint, NO);
    CFRelease(mutablePath);
    return result;
    
}

- (BOOL) isOverSize:(CGPoint)_mousePos withPoints:(const CGPoint*)points/*{bl,br,tr,tl}*/  withCorner:(int*)_cornerIndex withOrientation:(CGPoint*)_orientation
{
    int lCornerIndex = -1;
    CGPoint orientation;
    float minDistance = INFINITY;
    //first show rotate cursor, then size, check isOverRotation for same values
    //0..7 = size. 7..15 = rotation.
    const float kMinDistanceToCorner = 0.0f * [self selectionZoom];
    const float kMaxDistanceToCorner = 7.0f * [self selectionZoom];
    
    for (int i = 0; i < 4; i++)
    {
        CGPoint p1 = points[i % 4];
        CGPoint p2 = points[(i + 1) % 4];
        CGPoint p3 = points[(i + 2) % 4];
        
        float distance = ccpLength(ccpSub(_mousePos, p2));
        if(distance > kMinDistanceToCorner && distance < kMaxDistanceToCorner)
        {
            CGPoint segment1 = ccpSub(p2, p1);
            CGPoint segment2 = ccpSub(p2, p3);
            
            orientation = ccpNormalize(ccpAdd(segment1, segment2));
            lCornerIndex = (i + 1) % 4;
            minDistance = kMinDistanceToCorner;
        }
    }
    
    if(lCornerIndex != -1)
    {
        if(_orientation)
        {
            *_orientation = orientation;
        }
        
        if(_cornerIndex)
        {
            *_cornerIndex = lCornerIndex;
        }
        return YES;
    }
    
    for (int i = 0; i < 4; i++)
    {
        CGPoint p1 = points[i % 4 + 4];
        CGPoint p2 = points[(i + 1) % 4 + 4];
        CGPoint p3 = points[(i + 2) % 4 + 4];
        
        float distance = ccpLength(ccpSub(_mousePos, p2));
        if(distance > kMinDistanceToCorner && distance < kMaxDistanceToCorner)
        {
            CGPoint segment1 = ccpSub(p2, p1);
            CGPoint segment2 = ccpSub(p2, p3);
            
            orientation = ccpNormalize(ccpAdd(segment1, segment2));
            lCornerIndex = (i + 1) % 4 + 4;
            minDistance = distance;
        }
    }
    
    if(lCornerIndex != -1)
    {
        if(_orientation)
        {
            *_orientation = orientation;
        }
        
        if(_cornerIndex)
        {
            *_cornerIndex = lCornerIndex;
        }
        return YES;
    }
    return NO;
}

- (BOOL) isOverRotation:(CGPoint)_mousePos withPoints:(const CGPoint*)points/*{bl,br,tr,tl}*/ withCorner:(int*)_cornerIndex withOrientation:(CGPoint*)orientation
{
    for (int i = 0; i < 4; i++)
    {
        CGPoint p1 = points[i % 4];
        CGPoint p2 = points[(i + 1) % 4];
        CGPoint p3 = points[(i + 2) % 4];

        CGPoint segment1 = ccpSub(p2, p1);
        CGPoint unitSegment1 = ccpNormalize(segment1);
        
        CGPoint segment2 = ccpSub(p2, p3);
        CGPoint unitSegment2 = ccpNormalize(segment2);
        
        NodeInfo *info = appDelegate.selectedNode.userObject;
        PlugInNode *plugIn = info.plugIn;
        //CCLOG(@"%@",plugIn.nodeEditorClassName);
        
        float distanceSprite = 7.0;
        if ([plugIn.nodeEditorClassName isEqualToString:@"CCBPSprite"]) {
            //if this is Sprite, we can't resize it
            //so make any distance for corners from 0 till maximum
            distanceSprite = 0;
        }
        
        float kMinDistanceForRotation = distanceSprite * [self selectionZoom];
        const float kMaxDistanceForRotation = 15.0f * [self selectionZoom];
        
        CGPoint mouseVector = ccpSub(_mousePos, p2);
        
        float dot1 = ccpDot(mouseVector, unitSegment1);
        float dot2 = ccpDot(mouseVector, unitSegment2);
        float distanceToCorner = ccpLength(mouseVector);
        
        if(dot1 > 0.0f && dot2 > 0.0f && distanceToCorner > kMinDistanceForRotation && distanceToCorner < kMaxDistanceForRotation)
        {
            if(_cornerIndex)
            {
                *_cornerIndex = (i + 1) % 4;
            }
            
            if(orientation)
            {
                *orientation = ccpNormalize(ccpAdd(unitSegment1, unitSegment2));
            }
            return YES;
        }
    }
    return NO;
}

-(void)findObjectsAtPoint:(CGPoint)point node:(CCNode*)node nodes:(NSMutableArray*)nodes
{
	if([node hitTestWithWorldPos:point])
	{
		[nodes addObject:node];
	}
    
    for (CCNode * child in node.children)
	{
        [self findObjectsAtPoint:point node:child nodes:nodes];
    }
}


- (CCNode*)findObjectAtPoint:(CGPoint)point ofTypes:(NSArray*)filterClassTypes
{
    SceneGraph * g = [SceneGraph instance];
    
    NSMutableArray * nodes = [NSMutableArray array];
	[self findObjectsAtPoint:point node:g.rootNode nodes:nodes];
	
	
    //Find bodies we're inside the physics poly of.


	[nodes filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CCNode * testNode, NSDictionary *bindings) {
		
		for (NSString * classTypeName in filterClassTypes) {

			Class classType = NSClassFromString(classTypeName);
			
			if([testNode isKindOfClass:classType])
				return YES;
		}
		
		return NO;
		
	}]];
	
	
	//Filder bodies that are children of CCBPCCBFiles
	[nodes removeObjectsInArray:[nodes where:^BOOL(CCNode* node, int idx) {
		CCNode * parent = node.parent;
		while (parent) {
			if([[[parent class] description] isEqualToString:@"CCBPCCBFile"])
				return YES;
			parent=parent.parent;
		}
		return NO;
	}]];
	
    
    //Select the one we're closest too.
    CCNode * currentBody;
    
    for (CCNode * body in nodes) {
        if(currentBody == nil)
            currentBody = body;
        else
        {
            CGPoint loc1 = [body convertToNodeSpaceAR:point];
            CGPoint loc2 = [currentBody convertToNodeSpaceAR:point];
            
            if(ccpDistance(CGPointZero, loc1) < ccpDistance(CGPointZero, loc2))
            {
                currentBody = body;
            }
        }
    }
    
    return currentBody;
}


#pragma mark Handle Drag Input

-(void)updateDragging
{
	if(effectSpriteDragging)
	{
		NSArray * classTypes = @[NSStringFromClass([CCSprite class])];
		
		CCNode * node = [[CocosScene cocosScene] findObjectAtPoint:effectSpriteDraggingLocation ofTypes:classTypes];
		if(node)
		{
			[self renderBorder:node];
		}
	}
	
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender pos:(CGPoint)pos
{
    NSDragOperation operation;
    if([appDelegate.physicsHandler draggingEntered:sender pos:pos result:&operation])
    {
        return operation;
    }
	
	NSPasteboard* pb = [sender draggingPasteboard];
    
    // Textures
	
	NSArray* pbSprites = [pb propertyListsForType:@"com.cocosbuilder.effectSprite"];

	if(pbSprites.count > 0)
	{
		effectSpriteDragging = YES;
		effectSpriteDraggingLocation = pos;
		return NSDragOperationGeneric;
	}
	
    return NSDragOperationGeneric;

}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender pos:(CGPoint)pos
{
    NSDragOperation operation;
    if([appDelegate.physicsHandler draggingUpdated:sender pos:pos result:&operation])
    {
        return operation;
    }
	
	effectSpriteDraggingLocation = pos;
    
    return NSDragOperationGeneric;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender pos:(CGPoint)pos
{
    [appDelegate.physicsHandler draggingExited:sender pos:pos];
	effectSpriteDragging = NO;
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
    [appDelegate.physicsHandler draggingEnded:sender];
	effectSpriteDragging = NO;
	
}

#pragma mark Handle mouse input

- (CGPoint) convertToDocSpace:(CGPoint)viewPt
{
    return [contentLayer convertToNodeSpace:viewPt];
}

- (CGPoint) convertToViewSpace:(CGPoint)docPt
{
    return [contentLayer convertToWorldSpace:docPt];
}

- (NSString*) positionPropertyForSelectedNode
{
    NodeInfo* info = appDelegate.selectedNode.userObject;
    PlugInNode* plugIn = info.plugIn;
    
    return plugIn.positionProperty;
}

- (CGPoint) selectedNodePos
{
    if (!appDelegate.selectedNode) return CGPointZero;
    
    return NSPointToCGPoint([PositionPropertySetter positionForNode:appDelegate.selectedNode prop:[self positionPropertyForSelectedNode]]);
}



- (CCBTransformHandle) transformHandleUnderPt:(CGPoint)pt
{
    for (CCNode* node in appDelegate.selectedNodes)
    {
        if(node.locked)
            continue;
        
        transformSizeNode = node;
        
        BOOL isJoint = node.plugIn.isJoint;
        
        BOOL isContentSizeZero = NO;
        CGPoint points[8];
        
        
        if (transformSizeNode.contentSize.width == 0 || transformSizeNode.contentSize.height == 0)
        {
            isContentSizeZero = YES;
            CCSprite * sel = [CCSprite spriteWithImageNamed:kZeroContentSizeImage];
            [self getCornerPointsForZeroContentSizeNode:node withImageContentSize:sel.contentSize withPoints:points];
        }
        else
        {
            [self getCornerPointsForNode:node withPoints:points];
        }
        
        //WARNING: The following return statements should go in order of the CCBTool enumeration.
        //kCCBToolAnchor
        if(!isJoint && !isContentSizeZero && [self isOverAnchor:node withPoint:pt])
            return kCCBTransformHandleAnchorPoint;
        
        if([self isOverContentBorders:pt withPoints:points])
            return kCCBTransformHandleDownInside;        
        
        //kCCBToolRotate
        if(!isJoint && [self isOverRotation:pt withPoints:points withCorner:nil withOrientation:nil])
            return kCCBTransformHandleRotate;
        
        //kCCBToolSize
        if(!isJoint && !isContentSizeZero && [self isOverSize:pt withPoints:points withCorner:nil withOrientation:nil])
            return kCCBTransformHandleSize;
    }
    
    transformSizeNode = NULL;
    return kCCBTransformHandleNone;
}

- (void) nodesUnderPt:(CGPoint)pt rootNode:(CCNode*) node nodes:(NSMutableArray*)nodes
{
    if (!node) return;
    
    NodeInfo* parentInfo = node.parent.userObject;
    PlugInNode* parentPlugIn = parentInfo.plugIn;
    if (parentPlugIn && !parentPlugIn.canHaveChildren) return;
    
    if ((node.contentSize.width == 0 || node.contentSize.height == 0) && !node.plugIn.isJoint)
    {
        CGPoint worldPos = [node.parent convertToWorldSpace:node.position];
        if (node.visible && ccpDistance(worldPos, pt) < kCCBSinglePointSelectionRadius * [self selectionZoom])
        {
            [nodes addObject:node];
        }
    }
    else
    {
        if (node.visible && [node hitTestWithWorldPos:pt])
        {
            [nodes addObject:node];
        }
    }
    
    // Visit children
    if (node.visible)
        for (int i = 0; i < [node.children count]; i++)
        {
            [self nodesUnderPt:pt rootNode:[node.children objectAtIndex:i] nodes:nodes];
        }
  
    //Don't select nodes that are locked or hidden.
    NSArray * selectableNodes = [nodes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CCNode * node, NSDictionary *bindings) {
        return !node.locked && !node.hidden && !node.parentHidden;
    }]];
    [nodes removeAllObjects];
    [nodes addObjectsFromArray:selectableNodes];

    
}

-(void) selectableNodesFromNode:(CCNode *) node nodes:(NSMutableArray*) nodes {
    if (!node) return;
    
    NodeInfo* parentInfo = node.parent.userObject;
    PlugInNode* parentPlugIn = parentInfo.plugIn;
    if (parentPlugIn && !parentPlugIn.canHaveChildren) return;
    
    if (node != rootNode && node.visible) {
        [nodes addObject:node];
    }
    
    // Visit children
    if (node.visible) {
        for (int i = 0; i < node.children.count; i++) {
            [self selectableNodesFromNode:[node.children objectAtIndex:i] nodes:nodes];
        }
    }
    
    //Don't select nodes that are locked or hidden.
    NSArray * selectableNodes = [nodes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(CCNode * node, NSDictionary *bindings) {
        return !node.locked && !node.hidden && !node.parentHidden;
    }]];
    [nodes removeAllObjects];
    [nodes addObjectsFromArray:selectableNodes];
}

- (BOOL) isLocalCoordinateSystemFlipped:(CCNode*)node
{
    // TODO: Can this be done more efficiently?
    BOOL isMirroredX = NO;
    BOOL isMirroredY = NO;
    CCNode* nodeMirrorCheck = node;
    while (nodeMirrorCheck != rootNode && nodeMirrorCheck != NULL)
    {
        if (nodeMirrorCheck.scaleY < 0) isMirroredY = !isMirroredY;
        if (nodeMirrorCheck.scaleX < 0) isMirroredX = !isMirroredX;
        nodeMirrorCheck = nodeMirrorCheck.parent;
    }
    
    return (isMirroredX ^ isMirroredY);
}

- (void)rightMouseDown:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    CGPoint pos = [[CCDirectorMac sharedDirector] convertEventToGL:event];
    if ([appDelegate.physicsHandler rightMouseDown:pos event:event]) return;
    
    mouseDownPos = pos;
    [nodesAtSelectionPt removeAllObjects];
    [self nodesUnderPt:pos rootNode:rootNode nodes:nodesAtSelectionPt];
    
    [[jointsLayer.children.firstObject children] forEach:^(CCNode * jointNode, int idx) {
        [self nodesUnderPt:pos rootNode:jointNode nodes:self->nodesAtSelectionPt];
    }];
    
    currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    currentMouseTransform = kCCBTransformHandleNone;
    if ([event modifierFlags] & NSControlKeyMask || currentNodeAtSelectionPtIdx<0)
    {
        appDelegate.selectedNodes = NULL;
        [self setMouseSelectState];
        return;
    }
    else
    {
        currentMouseTransform = kCCBTransformHandleDownInside;
    }
    // shortcut for Select Behind: Alt + LeftClick
    if ([event modifierFlags] & NSAlternateKeyMask)
    {
        [self selectBehind];
    }

    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            [self addNodeToSelection:clickedNode];
        }
        else
        {
            // Replace selection
            [appDelegate setSelectedNodes:[NSArray arrayWithObject:clickedNode]];
        }
        
        currentMouseTransform = kCCBTransformHandleNone;
    }
}

- (void) selectedResource:(id)sender
{
    NSString *propertyName = @"spriteFrame";
    [appDelegate saveUndoStateWillChangeProperty:propertyName];
    
    CCNode *selection = appDelegate.selectedNode;
    
    id item = [sender representedObject];
    
    // Fetch info about the sprite name
    NSString* sf = NULL;
    NSString* ssf = NULL;
    
    if (!item)
    {
        sf = @"";
        ssf = @"";
    }
    else if ([item isKindOfClass:[RMResource class]])
    {
        RMResource* res = item;
        
        if (res.type == kCCBResTypeImage)
        {
            sf = [ResourceManagerUtil relativePathFromAbsolutePath:res.filePath];
            ssf = kCCBUseRegularFile;
        }
    }
    else if ([item isKindOfClass:[RMSpriteFrame class]])
    {
        RMSpriteFrame* frame = item;
        sf = frame.spriteFrameName;
        ssf = [ResourceManagerUtil relativePathFromAbsolutePath:frame.spriteSheetFile];
    }
    
    // Set the properties and sprite frames
    if (sf && ssf)
    {
        [selection setExtraProp:sf forKey:propertyName];
        [selection setExtraProp:ssf forKey:[NSString stringWithFormat:@"%@Sheet", propertyName]];
        
        [TexturePropertySetter setSpriteFrameForNode:selection andProperty:propertyName withFile:sf andSheetFile:ssf];
        
        // Setup menu
        if([selection isKindOfClass:[CCNode class]])
        {
            [selection updateAnimateablePropertyValue:[NSArray arrayWithObjects:sf, ssf , nil] forProperty:propertyName];
        }
    }
    
    [[InspectorController sharedController] refreshProperty: propertyName];
}

- (void) mouseDown:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    CGPoint pos = [[CCDirectorMac sharedDirector] convertEventToGL:event];
    
    if ([notesLayer mouseDown:pos event:event]) return;
    if ([guideLayer mouseDown:pos event:event]) return;
    [snapLayer mouseDown:pos event:event];
    if ([appDelegate.physicsHandler mouseDown:pos event:event]) return;
    
    mouseDownPos = pos;
    mouseSelectPosDown = pos;
    mouseSelectPosMove = pos;
    // Handle grab tool
    if (currentTool == kCCBToolGrab || ([event modifierFlags] & NSCommandKeyMask))
    {

        self.currentTool = kCCBToolGrab;
        isPanning = YES;
        panningStartScrollOffset = scrollOffset;
        return;
    }
    
    // Find out which objects were clicked
    
    // Transform handles
    
    if (!appDelegate.physicsHandler.editingPhysicsBody)
    {
        CCBTransformHandle th = [self transformHandleUnderPt:pos];
        
        if (th == kCCBTransformHandleAnchorPoint)
        {
            // Anchor points are fixed for singel point nodes
            if (transformSizeNode.contentSizeInPoints.width == 0 || transformSizeNode.contentSizeInPoints.height == 0)
            {
                return;
            }
            
            BOOL readOnly = [[[transformSizeNode.plugIn.nodePropertiesDict objectForKey:@"anchorPoint"] objectForKey:@"readOnly"] boolValue];
            if (readOnly)
            {
                return;
            }
            
            // Transform anchor point
            currentMouseTransform = kCCBTransformHandleAnchorPoint;
            [transformSizeNode cacheStartTransformAndAnchor];
            return;
        }
        if(th == kCCBTransformHandleRotate && appDelegate.selectedNode != rootNode)
        {
            // Start rotation transform
            currentMouseTransform = kCCBTransformHandleRotate;
            transformStartRotation = transformSizeNode.rotation;
            return;
        }
        
        if (th == kCCBTransformHandleSize && appDelegate.selectedNode != rootNode)
        {
            // Start scale transform
            currentMouseTransform = kCCBTransformHandleSize;
            anchorBefore = transformSizeNode.anchorPoint;
            transformContentSize = transformSizeNode.contentSizeInPoints;
            transformStartScaleX = [PositionPropertySetter scaleXForNode:transformSizeNode prop:@"scale"];
            transformStartScaleY = [PositionPropertySetter scaleYForNode:transformSizeNode prop:@"scale"];
            return;
        }

    }
    
    
    // Clicks inside objects
    [nodesAtSelectionPt removeAllObjects];
    
   
	[self nodesUnderPt:pos rootNode:rootNode nodes:nodesAtSelectionPt];
	
	[[jointsLayer.children.firstObject children] forEach:^(CCNode * jointNode, int idx) {
        [self nodesUnderPt:pos rootNode:jointNode nodes:self->nodesAtSelectionPt];
    }];

    currentNodeAtSelectionPtIdx = (int)[nodesAtSelectionPt count] -1;
    
    currentMouseTransform = kCCBTransformHandleNone;
    
    if ([event modifierFlags] & NSControlKeyMask || currentNodeAtSelectionPtIdx<0)
    {
        appDelegate.selectedNodes = NULL;
        [self setMouseSelectState];
        return;
    }
    else
    {
        currentMouseTransform = kCCBTransformHandleDownInside;
    }
    
    // shortcut for Select Behind: Alt + LeftClick
    if ([event modifierFlags] & NSAlternateKeyMask)
    {
        [self selectBehind];
    }
    
    return;
}

-(void) setMouseSelectState {
    currentMouseTransform = kCCBTransformHandleMouseSelect;
    [selectableNodesOnScene removeAllObjects];
    [self selectableNodesFromNode:rootNode nodes:selectableNodesOnScene];
}

- (void) rightMouseUp:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    isMouseTransforming = NO;
    if (isPanning)
    {
        self.currentTool = kCCBToolSelection;
        isPanning = NO;
    }
    mouseSelectPosDown = CGPointZero;
    mouseSelectPosMove = CGPointZero;
    currentMouseTransform = kCCBTransformHandleNone;
    
    //Object Menu
    if (appDelegate.selectedNode) {
        [appDelegate.spriteObjectMenu removeAllItems];
        
        CCNode *selection = appDelegate.selectedNode;
        NodeInfo *info = appDelegate.selectedNode.userObject;
        PlugInNode *plugIn = info.plugIn;
        //CCLOG(@"%@",plugIn.nodeEditorClassName);
        
        if ([plugIn.nodeEditorClassName isEqualToString:@"CCBPSprite"] ||
            [plugIn.nodeEditorClassName isEqualToString:@"CCBPSprite9Slice"] ||
            [plugIn.nodeEditorClassName isEqualToString:@"CCBPImage"] ||
            [plugIn.nodeEditorClassName isEqualToString:@"CCBPTiledImage"]) {
            
            //Add menu displayName
            NSMenuItem *spriteDisplayNameItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@:", plugIn.displayName]
                                                                           action:nil
                                                                    keyEquivalent:@""];
            spriteDisplayNameItem.enabled = NO;
            [appDelegate.spriteObjectMenu addItem:spriteDisplayNameItem];
            
            //---------------
            NSMenuItem *separator1 = [NSMenuItem separatorItem];
            [appDelegate.spriteObjectMenu addItem: separator1];
            
            //Menu FlipXY
            NSMenuItem *brightness = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
            SpriteObjectMenuFlipController *flipMenu = [[SpriteObjectMenuFlipController alloc] initWithNibName:@"SpriteObjectMenuFlipController"
                                                                                                        bundle:nil];
            flipMenu.selection = selection;
            [brightness setView:flipMenu.view];
            [appDelegate.spriteObjectMenu addItem:brightness];
            
            
            //Menu SpriteFrame
            NSString *propertyName = @"spriteFrame";
            // Setup menu for the SpriteFrame
            NSString *spriteFrameTitle = [info.extraProps valueForKey:propertyName];
            bool isNull = (spriteFrameTitle.length == 0);
            NSMenuItem *spriteFrameMenuItem = [[NSMenuItem alloc] initWithTitle: isNull ? @"<NULL>" : spriteFrameTitle
                                                                         action: nil
                                                                  keyEquivalent: @""];
            
            [appDelegate.spriteObjectMenu addItem:spriteFrameMenuItem];
            
            NSMenu *subMenu = [[NSMenu alloc] init];
            spriteFrameMenuItem.submenu = subMenu;
            
            if ([selection isKindOfClass:[CCNode class]]) {
                SequencerSequence* seq = [SequencerHandler sharedHandler].currentSequence;
                id value = [selection valueForProperty:propertyName atTime:seq.timelinePosition sequenceId:seq.sequenceId];
                
                NSString* sf = [value objectAtIndex:0];
                NSString* ssf = [value objectAtIndex:1];
                
                if ([ssf isEqualToString:kCCBUseRegularFile] || [ssf isEqualToString:@""]) ssf = NULL;
                
                [ResourceManagerUtil populateResourceMenu: subMenu
                                                  resType: kCCBResTypeImage
                                        allowSpriteFrames: YES
                                             selectedFile: sf
                                            selectedSheet: ssf
                                                   target: self];
            } else {
                //[TexturePropertySetter
                NSString* sf = [selection extraPropForKey:propertyName];
                NSString* ssf = [selection extraPropForKey:[propertyName stringByAppendingString:@"Sheet"]];
                
                if ([ssf isEqualToString:kCCBUseRegularFile] || [ssf isEqualToString:@""]) ssf = NULL;
                
                [ResourceManagerUtil populateResourceMenu: subMenu
                                                  resType: kCCBResTypeImage
                                        allowSpriteFrames: YES
                                             selectedFile: sf
                                            selectedSheet: ssf
                                                   target: self];
            }
            //remove NULL at submenu if already NULL at main menu
            if (isNull) {
                [subMenu removeItemAtIndex:0];
            }
            
            //---------------
            NSMenuItem *separator2 = [NSMenuItem separatorItem];
            [appDelegate.spriteObjectMenu addItem: separator2];
            if (!isNull) {
                [self selectItemWithPath:spriteFrameTitle forMenu:subMenu];
            }
            
        }
        
        [NSMenu popUpContextMenu:appDelegate.spriteObjectMenu withEvent:event forView:appDelegate.cocosView];
    }
}

- (void)selectItemWithPath:(NSString *)path forMenu:(NSMenu *) menu {
    
    NSArray *parts = [path componentsSeparatedByString:@"/"];
    NSMenuItem *currentItem = [menu itemWithTitle:[parts objectAtIndex:0]];
    if (currentItem) {
        NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString: currentItem.title];
        NSFont *defaultFont = [NSFont boldSystemFontOfSize:menu.font.pointSize];
        [str setAttributes: @{ NSFontAttributeName : defaultFont } range: NSMakeRange(0, [str length])];
        [currentItem setAttributedTitle:str];
        
        if ([parts count] == 1) {
            currentItem.state = NSControlStateValueOn;
        } else {
            NSString *newPath = @"";
            for (int i = 1; i < [parts count]; i++) {
                newPath = [newPath stringByAppendingPathComponent:[parts objectAtIndex:i]];
            }
            [self selectItemWithPath:newPath forMenu:currentItem.submenu];
        }
    }
}

- (void) mouseDragged:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    [self mouseMoved:event];
    
    CGPoint pos = [[CCDirectorMac sharedDirector] convertEventToGL:event];
    
    if ([notesLayer mouseDragged:pos event:event]) return;
    if ([guideLayer mouseDragged:pos event:event]) return;
    if ([appDelegate.physicsHandler mouseDragged:pos event:event]) return;
    //if (currentMouseTransform != kCCBTransformHandleMouseSelect && (!nodesAtSelectionPt || nodesAtSelectionPt.count == 0) && !isPanning) return;
    
    if (currentMouseTransform == kCCBTransformHandleDownInside && nodesAtSelectionPt && nodesAtSelectionPt.count>0)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        BOOL selectedNodeUnderClickPt = NO;
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            if ([nodesAtSelectionPt containsObject:selectedNode])
            {
                selectedNodeUnderClickPt = YES;
                break;
            }
        }
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
			[self addNodeToSelection:clickedNode];
        }
        else if (![appDelegate.selectedNodes containsObject:clickedNode]
                 && ! selectedNodeUnderClickPt)
        {
            // Replace selection
            appDelegate.selectedNodes = [NSArray arrayWithObject:clickedNode];
        }
        
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            if(selectedNode.locked)
                continue;
          
            [selectedNode cacheStartTransformAndAnchor];
        }
    
        if (appDelegate.selectedNode != rootNode && appDelegate.selectedNodes.count &&
            ![[[appDelegate.selectedNodes objectAtIndex:0] parent] isKindOfClass:[CCLayout class]]
			//And if its not a joint, or if it is, its draggable.
			&& (!appDelegate.selectedNode.plugIn.isJoint || [(CCBPhysicsJoint*)appDelegate.selectedNode isDraggable]))
        {
            currentMouseTransform = kCCBTransformHandleMove;
        }
    }
    
    if (currentMouseTransform == kCCBTransformHandleMove)
    {
        for (CCNode* selectedNode in appDelegate.selectedNodes)
        {
            if(selectedNode.locked)
                continue;
          
            CGPoint delta = ccp((int)(pos.x - mouseDownPos.x), (int)(pos.y - mouseDownPos.y));
          
            // Handle shift key (straight drags)
            if ([event modifierFlags] & NSShiftKeyMask)
            {
                if (fabs(delta.x) > fabs(delta.y))
                {
                    delta.y = 0;
                }
                else
                {
                    delta.x = 0;
                }
            }
          
            CGAffineTransform startTransform = selectedNode.startTransform;
            CGPoint newAbsPos = ccpAdd(selectedNode.transformStartPosition, delta);
            CGPoint snapDelta = CGPointZero;
            
            // Guide Snap Rules
            if ( ((appDelegate.showGuides && appDelegate.snapToGuides && appDelegate.snapToggle) ||
                 (appDelegate.showGuideGrid && appDelegate.showGuideGrid && appDelegate.snapToggle)) &&
                !([event modifierFlags] & NSCommandKeyMask))
            {
                CGSize size = selectedNode.contentSizeInPoints;

                // Perform snapping (snapping happens in world space)
                CGPoint snapDeltaAP = ccpSub([guideLayer snapPoint:newAbsPos], newAbsPos);
                snapDelta = ccpAdd(snapDelta,snapDeltaAP);
                
                CGPoint cornerBL = ccpAdd(CGPointApplyAffineTransform(ccp(0, 0), startTransform), delta);
                CGPoint snapDeltaBL = ccpSub([guideLayer snapPoint:cornerBL], cornerBL);
                
                // Unique Snaps
                if(snapDelta.x!=snapDeltaBL.x && snapDelta.x==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(snapDeltaBL.x,0));
                }
                if(snapDelta.y!=snapDeltaBL.y && snapDelta.y==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(0,snapDeltaBL.y));
                }
                
                CGPoint cornerBR = ccpAdd(CGPointApplyAffineTransform(ccp(size.width, 0), startTransform), delta);
                CGPoint snapDeltaBR = ccpSub([guideLayer snapPoint:cornerBR], cornerBR);
                if(snapDelta.x!=snapDeltaBR.x && snapDelta.x==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(snapDeltaBR.x,0));
                }
                if(snapDelta.y!=snapDeltaBR.y && snapDelta.y==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(0,snapDeltaBR.y));
                }
                
                CGPoint cornerTL = ccpAdd(CGPointApplyAffineTransform(ccp(0, size.height), startTransform), delta);
                CGPoint snapDeltaTL = ccpSub([guideLayer snapPoint:cornerTL], cornerTL);
                if(snapDelta.x!=snapDeltaTL.x && snapDelta.x==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(snapDeltaTL.x,0));
                }
                if(snapDelta.y!=snapDeltaTL.y && snapDelta.y==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(0,snapDeltaTL.y));
                }
       
                CGPoint cornerTR = ccpAdd(CGPointApplyAffineTransform(ccp(size.width, size.height), startTransform), delta);
                CGPoint snapDeltaTR = ccpSub([guideLayer snapPoint:cornerTR], cornerTR);
                if(snapDelta.x!=snapDeltaTR.x && snapDelta.x==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(snapDeltaTR.x,0));
                }
                if(snapDelta.y!=snapDeltaTR.y && snapDelta.y==0) {
                    snapDelta = ccpAdd(snapDelta,ccp(0,snapDeltaTR.y));
                }
            
            }
            
            newAbsPos = ccpAdd(newAbsPos, snapDelta);
            CGPoint newLocalPos = [selectedNode.parent convertToNodeSpace:newAbsPos];
            
            [appDelegate saveUndoStateWillChangeProperty:@"position"];
            
            selectedNode.position = [selectedNode convertPositionFromPoints:newLocalPos type:selectedNode.positionType];
        }
        [[InspectorController sharedController] refreshProperty:@"position"];
        [snapLayer mouseDragged:pos event:event];
    }
    else if (currentMouseTransform == kCCBTransformHandleSize)
    {
        CGPoint anchorPointSize = ccp(0.5f, 0.5f);
        CGPoint vertexScaler = ccp(0.0f, 0.0f);
        
        switch (cornerIndex) {
            case 0: //bl
                anchorPointSize = ccp(1.0f, 1.0f);
                vertexScaler = ccp(-1.0f, -1.0f);
                break;
                
            case 1: //br
                anchorPointSize = ccp(0.0f, 1.0f);
                vertexScaler = ccp(1.0f, -1.0f);
                break;
                
            case 2: //tR
                anchorPointSize = ccp(0.0f, 0.0f);
                vertexScaler = ccp(1.0f, 1.0f);
                break;
                
            case 3: //tL
                anchorPointSize = ccp(1.0f, 0.0f);
                vertexScaler = ccp(-1.0f, 1.0f);
                break;
                
            case 4: //l
                anchorPointSize = ccp(1.0f, 0.5f);
                vertexScaler = ccp(-1.0f, 0.0f);
                break;
                
            case 5: //b
                anchorPointSize = ccp(0.5f, 1.0f);
                vertexScaler = ccp(0.0f, -1.0f);
                break;
                
            case 6: //r
                anchorPointSize = ccp(0.0f, 0.5f);
                vertexScaler = ccp(1.0f, 0.0f);
                break;
                
            case 7: //t
                anchorPointSize = ccp(0.5f, 0.0f);
                vertexScaler = ccp(0.0f, 1.0f);
                break;
        }
        NodeInfo* nodeInfo = transformSizeNode.userObject;
        NSDictionary* propInfo = [nodeInfo.plugIn.nodePropertiesDict objectForKey:@"contentSize"];
        BOOL disabledContentSize = [transformSizeNode shouldDisableProperty:@"contentSize"] || [[propInfo objectForKey:@"readOnly"] boolValue];
        bool widthLock = [nodeInfo.extraProps[@"contentSizeLockedWidth"] boolValue];
        bool heightLock = [nodeInfo.extraProps[@"contentSizeLockedHeight"] boolValue];
        //if all locked, don't save undo.. well don't do anything
        /*if (widthLock && heightLock) {
            return;
        }*/
        [appDelegate saveUndoStateWillChangeProperty:@"position"];
        [self setAnchorPoint:anchorPointSize forNode:transformSizeNode];
        
        int scaleType = [PositionPropertySetter scaledFloatTypeForNode:transformSizeNode prop:@"scale"];
        [PositionPropertySetter setScaledX:transformStartScaleX Y:transformStartScaleY type:scaleType forNode:transformSizeNode prop:@"scale"];
        
        CGPoint startPos = [transformSizeNode convertToNodeSpace:mouseDownPos];
        CGPoint currentPos = [transformSizeNode convertToNodeSpace:pos];
        
        float dx = (currentPos.x - startPos.x) / transformContentSize.width;
        float dy = (currentPos.y - startPos.y) / transformContentSize.height;
        
        float xScaleNew = 1.0f + dx * vertexScaler.x;
        float yScaleNew = 1.0f + dy * vertexScaler.y;

        if ([event modifierFlags] & NSShiftKeyMask && cornerIndex <4)
        {
            // Use the smallest scale composit
            if (fabs(xScaleNew) < fabs(yScaleNew))
                yScaleNew = xScaleNew;
            else
                xScaleNew = yScaleNew;
        }
        
        if ([event modifierFlags] & NSAlternateKeyMask) {
            [self setAnchorPoint:ccp(0.5,0.5) forNode:transformSizeNode];
        }
        
        if ([event modifierFlags] & NSControlKeyMask || disabledContentSize) {
            
            // Set new scale
            [PositionPropertySetter setScaledX:transformStartScaleX * xScaleNew Y:transformStartScaleY * yScaleNew type:scaleType forNode:transformSizeNode prop:@"scale"];
            [[InspectorController sharedController] refreshProperty:@"scale"];
            
            [self setAnchorPoint:anchorBefore forNode:transformSizeNode];
            [[InspectorController sharedController] refreshProperty:@"position"];
            [self setAnchorPoint:anchorPointSize forNode:transformSizeNode];
        }
        else
        {
            transformSizeNode.contentSizeInPoints = CGSizeMake(widthLock ? transformContentSize.width : transformContentSize.width * xScaleNew,
                                                               heightLock ? transformContentSize.height : transformContentSize.height * yScaleNew);
            
            [[InspectorController sharedController] refreshProperty:@"contentSize"];
            
            //this will show position changes in the inspector
            //but will cause little jitter when start drag if mouse close to the initial anhor.
            [self setAnchorPoint:anchorBefore forNode:transformSizeNode];
            [[InspectorController sharedController] refreshProperty:@"position"];
            [self setAnchorPoint:anchorPointSize forNode:transformSizeNode];
        }
    }
    else if (currentMouseTransform == kCCBTransformHandleRotate)
    {
        CGPoint nodePos = [transformSizeNode.parent convertToWorldSpace:transformSizeNode.positionInPoints];
        
        CGPoint handleAngleVectorStart = ccpSub(nodePos, mouseDownPos);
        CGPoint handleAngleVectorNew = ccpSub(nodePos, pos);
        
        float handleAngleRadStart = atan2f(handleAngleVectorStart.y, handleAngleVectorStart.x);
        float handleAngleRadNew = atan2f(handleAngleVectorNew.y, handleAngleVectorNew.x);
        
        float deltaRotationRad = handleAngleRadNew - handleAngleRadStart;
        float deltaRotation = -(deltaRotationRad/(2*M_PI))*360;
        
        if ([self isLocalCoordinateSystemFlipped:transformSizeNode.parent])
        {
            deltaRotation = -deltaRotation;
        }
        
        while ( deltaRotation > 180.0f )
            deltaRotation -= 360.0f;
        while ( deltaRotation < -180.0f )
            deltaRotation += 360.0f;
        
        float newRotation = (transformStartRotation + deltaRotation);
                // Handle shift key (fixed rotation angles)
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            float factor = 360.0f/16.0f;
            newRotation = roundf(newRotation/factor)*factor;
        }
        
        //Update the rotation tool.
        float cursorRotationRad = -M_PI * (newRotation - transformSizeNode.rotation) / 180.0f;
        CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(cursorRotationRad);
        cornerOrientation = CGPointApplyAffineTransform(cornerOrientation, rotationTransform);
        self.currentTool = kCCBToolRotate; //Force it to update.
        
        [appDelegate saveUndoStateWillChangeProperty:@"rotation"];
        transformSizeNode.rotation = newRotation;
        [[InspectorController sharedController] refreshProperty:@"rotation"];
    }
    else if (currentMouseTransform == kCCBTransformHandleAnchorPoint)
    {
        CGPoint localPos = [transformSizeNode convertToNodeSpace:pos];
        CGPoint localDownPos = [transformSizeNode convertToNodeSpace:mouseDownPos];
        
        CGPoint deltaLocal = ccpSub(localPos, localDownPos);
        CGPoint deltaAnchorPoint = ccp(deltaLocal.x / transformSizeNode.contentSizeInPoints.width, deltaLocal.y / transformSizeNode.contentSizeInPoints.height);
        
        [appDelegate saveUndoStateWillChangeProperty:@"anchorPoint"];
        transformSizeNode.anchorPoint = ccpAdd(transformSizeNode.startAnchorPoint, deltaAnchorPoint);
        [[InspectorController sharedController] refreshProperty:@"anchorPoint"];
        
        [self updateAnchorPointCompensation];
    }
    else if (currentMouseTransform == kCCBTransformHandleMouseSelect) {
       
        //super efficient way to select nodes.. can it be better? lol, programmed at ~3am at night
        [nodesAtMouseSelection removeAllObjects];
        
        for (CCNode *node in selectableNodesOnScene) {
            
            CGPoint nodePoints[4];
            [self getCornerPointsForNode:node withPoints:nodePoints];

            NSMutableArray *nodeSegments = [NSMutableArray array];
            
            Segment *nodeSegment1 = [[Segment alloc] initWithA:nodePoints[0] b:nodePoints[1]];
            Segment *nodeSegment2 = [[Segment alloc] initWithA:nodePoints[1] b:nodePoints[2]];
            Segment *nodeSegment3 = [[Segment alloc] initWithA:nodePoints[2] b:nodePoints[3]];
            Segment *nodeSegment4 = [[Segment alloc] initWithA:nodePoints[3] b:nodePoints[0]];
            
            [nodeSegments addObject:nodeSegment1];
            [nodeSegments addObject:nodeSegment2];
            [nodeSegments addObject:nodeSegment3];
            [nodeSegments addObject:nodeSegment4];

            //--------
            NSMutableArray *mouseSegments = [NSMutableArray array];
            
            CGPoint mouseSelectPoints[4];
            mouseSelectPoints[0] = mouseSelectPosDown;
            mouseSelectPoints[1] = ccp(mouseSelectPosMove.x, mouseSelectPosDown.y);
            mouseSelectPoints[2] = mouseSelectPosMove;
            mouseSelectPoints[3] = ccp(mouseSelectPosDown.x,mouseSelectPosMove.y);

            Segment *mouseSegment1 = [[Segment alloc] initWithA:mouseSelectPoints[0] b:mouseSelectPoints[1]];
            Segment *mouseSegment2 = [[Segment alloc] initWithA:mouseSelectPoints[1] b:mouseSelectPoints[2]];
            Segment *mouseSegment3 = [[Segment alloc] initWithA:mouseSelectPoints[2] b:mouseSelectPoints[3]];
            Segment *mouseSegment4 = [[Segment alloc] initWithA:mouseSelectPoints[3] b:mouseSelectPoints[0]];
            
            [mouseSegments addObject:mouseSegment1];
            [mouseSegments addObject:mouseSegment2];
            [mouseSegments addObject:mouseSegment3];
            [mouseSegments addObject:mouseSegment4];

            CGRect mouseSelectRect = CGRectMake(mouseSelectPosDown.x,
                                                mouseSelectPosDown.y,
                                                mouseSelectPosMove.x - mouseSelectPosDown.x,
                                                mouseSelectPosMove.y - mouseSelectPosDown.y);
            
            if ((node.contentSize.width == 0 || node.contentSize.height == 0) && !node.plugIn.isJoint) {
                CGPoint worldPos = [node.parent convertToWorldSpace:node.position];
                if (node.visible && CGRectContainsPoint(mouseSelectRect, worldPos)) {
                    [nodesAtMouseSelection addObject:node];
                }
            } else {
                for (Segment *nodeSegment in nodeSegments) {
                    for (Segment *mouseSegment in mouseSegments) {
                        for (int i = 0; i < 4; i++) {
                            if (CGRectContainsPoint(mouseSelectRect, nodePoints[i])) {
                                [nodesAtMouseSelection addObject:node];
                                break;
                            }
                        }
                        if (ccpSegmentIntersect(nodeSegment->A, nodeSegment->B, mouseSegment->A, mouseSegment->B)) {
                            [nodesAtMouseSelection addObject:node];
                            break;
                        }
                    }
                }
            }
        }
        //CCLOG(@"%@",nodesAtMouseSelection);
        [appDelegate setSelectedNodes:[NSArray arrayWithArray:[nodesAtMouseSelection allObjects]]];
    }
    
    else if (isPanning)
    {
        CGPoint delta = ccpSub(pos, mouseDownPos);
        scrollOffset = ccpAdd(panningStartScrollOffset, delta);
    }
    
    return;
}

- (void) updateAnimateablePropertyValue:(id)value propName:(NSString*)propertyName type:(int)type
{
    snapLinesNeedUpdate = YES;
    CCNode* selectedNode = appDelegate.selectedNode;
    
    NodeInfo* nodeInfo = selectedNode.userObject;
    PlugInNode* plugIn = nodeInfo.plugIn;
    SequencerHandler* sh = [SequencerHandler sharedHandler];
    
    if ([plugIn isAnimatableProperty:propertyName node:selectedNode])
    {
        SequencerSequence* seq = sh.currentSequence;
        int seqId = seq.sequenceId;
        SequencerNodeProperty* seqNodeProp = [selectedNode sequenceNodeProperty:propertyName sequenceId:seqId];
        
        if (seqNodeProp)
        {
            SequencerKeyframe* keyframe = [seqNodeProp keyframeAtTime:seq.timelinePosition];
            if (keyframe)
            {
                keyframe.value = value;
            }
            else
            {
                SequencerKeyframe* keyframe = [[SequencerKeyframe alloc] init];
                keyframe.time = seq.timelinePosition;
                keyframe.value = value;
                keyframe.type = type;
                keyframe.name = seqNodeProp.propName;
                
                [seqNodeProp setKeyframe:keyframe];
                [[InspectorController sharedController] updateInspectorFromSelection];
            }
            
            [sh redrawTimeline];
        }
        else
        {
            [nodeInfo.baseValues setObject:value forKey:propertyName];
        }
    }
}

-(void)addNodeToSelection:(CCNode*)clickedNode
{
	// Add to/subtract from selection
	NSMutableArray* modifiedSelection = [NSMutableArray arrayWithArray: appDelegate.selectedNodes];
	
	if ([modifiedSelection containsObject:clickedNode])
	{
		[modifiedSelection removeObject:clickedNode];
	}
	else
	{
		[modifiedSelection addObject:clickedNode];
	}
	
	
	//If we selected a joint. Only select one joint.
	CCBPhysicsJoint * anyJoint = [modifiedSelection findLast:^BOOL(CCNode * node, int idx) {
		return node.plugIn.isJoint;
	}];
	
	if(anyJoint)
	{
		appDelegate.selectedNodes = @[anyJoint];
	}
	else
	{
		appDelegate.selectedNodes = modifiedSelection;
	}

}


- (void) mouseUp:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    CCNode* selectedNode = appDelegate.selectedNode;
    
    CGPoint pos = [[CCDirectorMac sharedDirector] convertEventToGL:event];
    
    if ([appDelegate.physicsHandler mouseUp:pos event:event]) return;
    
    if (currentMouseTransform == kCCBTransformHandleDownInside)
    {
        CCNode* clickedNode = [nodesAtSelectionPt objectAtIndex:currentNodeAtSelectionPtIdx];
        
        if ([event modifierFlags] & NSShiftKeyMask)
        {
            [self addNodeToSelection:clickedNode];
            
        }
        else
        {
            // Replace selection
            [appDelegate setSelectedNodes:[NSArray arrayWithObject:clickedNode]];
        }
        
        currentMouseTransform = kCCBTransformHandleNone;
    }
    
    if (currentMouseTransform != kCCBTransformHandleNone)
    {
        // Update keyframes & base value
        id value = NULL;
        NSString* propName = NULL;
        int type = kCCBKeyframeTypeDegrees;
        
        if (currentMouseTransform == kCCBTransformHandleRotate)
        {
            value = [NSNumber numberWithFloat: selectedNode.rotation];
            propName = @"rotation";
            type = kCCBKeyframeTypeDegrees;
        }
        else if (currentMouseTransform == kCCBTransformHandleSize)
        {
//            float x = [PositionPropertySetter scaleXForNode:selectedNode prop:@"scale"];
//            float y = [PositionPropertySetter scaleYForNode:selectedNode prop:@"scale"];
//            value = [NSArray arrayWithObjects:
//                     [NSNumber numberWithFloat:x],
//                     [NSNumber numberWithFloat:y],
//                     nil];
//            propName = @"scale";
//            type = kCCBKeyframeTypeScaleLock;
            
            [self setAnchorPoint:anchorBefore forNode:transformSizeNode];
            [[InspectorController sharedController] refreshProperty:@"anchorPoint"];
        }
        else if (currentMouseTransform == kCCBTransformHandleMove)
        {
            CGPoint pt = NSPointToCGPoint([PositionPropertySetter positionForNode:selectedNode prop:@"position"]);
            value = [NSArray arrayWithObjects:
                     [NSNumber numberWithFloat:pt.x],
                     [NSNumber numberWithFloat:pt.y],
                     nil];
            propName = @"position";
            type = kCCBKeyframeTypePosition;
        }
        
        if (value)
        {
            [self updateAnimateablePropertyValue:value propName:propName type:type];
        }
    }
    
    if ([notesLayer mouseUp:pos event:event]) return;
    if ([guideLayer mouseUp:pos event:event]) return;
    [snapLayer mouseUp:pos event:event];
    
    isMouseTransforming = NO;
    
    if (isPanning)
    {
        self.currentTool = kCCBToolSelection;
        isPanning = NO;
    }
    mouseSelectPosDown = CGPointZero;
    mouseSelectPosMove = CGPointZero;
    currentMouseTransform = kCCBTransformHandleNone;
    return;
}

- (void)mouseMoved:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
    CGPoint pos = [[CCDirectorMac sharedDirector] convertEventToGL:event];
    
    mousePos = pos;
    mouseSelectPosMove = pos;
    
    [appDelegate.physicsHandler mouseMove:pos event:event];
    
}

- (void)mouseEntered:(NSEvent *)event
{
    mouseInside = YES;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseEntered:event];
}
- (void)mouseExited:(NSEvent *)event
{
    mouseInside = NO;
    
    if (!appDelegate.hasOpenedDocument) return;
    
    [rulerLayer mouseExited:event];
}

- (void)cursorUpdate:(NSEvent *)event
{
    if (!appDelegate.hasOpenedDocument) return;
    
}
- (NSImage *)rotateImage:(NSImage *)image rotation:(float)rotation
{
    CGSize imageSize = image.size;
    CGRect rect ={ 0,0, imageSize };
    
    
    NSBitmapImageRep *offscreenRep = [[NSBitmapImageRep alloc]
                                       initWithBitmapDataPlanes:NULL
                                       pixelsWide:imageSize.width
                                       pixelsHigh:imageSize.height
                                       bitsPerSample:8
                                       samplesPerPixel:4
                                       hasAlpha:YES
                                       isPlanar:NO
                                       colorSpaceName:NSDeviceRGBColorSpace
                                       bitmapFormat:NSAlphaFirstBitmapFormat
                                       bytesPerRow:0
                                       bitsPerPixel:0]; ;
    
    NSGraphicsContext * graphicsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:offscreenRep];
    
    CGContextRef context = [graphicsContext graphicsPort];
	if (context)
	{
		CGPoint centerPoint=CGPointMake( imageSize.width/2, imageSize.height/2);
		CGPoint vertex = CGPointMake( -imageSize.width/2, -imageSize.height/2);
		CGAffineTransform tranform = CGAffineTransformMakeRotation(rotation);
		CGPoint vertex2 = CGPointApplyAffineTransform(vertex, tranform);
		CGPoint vertex3 = CGPointMake(centerPoint.x + vertex2.x, centerPoint.y + vertex2.y);
		
		
		CGContextTranslateCTM(context, vertex3.x,vertex3.y);
		CGContextRotateCTM(context, rotation);
		
		CGImageRef maskImage = [image CGImageForProposedRect:nil context:graphicsContext hints:nil];
		CGContextDrawImage(context, rect, maskImage);
	}
	else
	{
		NSLog(@"CocosScene rotateImage: CG draw context is nil");
	}
    
    NSImage*img = [[NSImage alloc] initWithSize:imageSize];;
    [img addRepresentation:offscreenRep];
    return img;
}


-(CCBTool)currentTool
{
    return currentTool;
}

- (void)setCurrentTool:(CCBTool)_currentTool
{
    //First pop any non-selection tools.
    if (currentTool != kCCBToolSelection)
    {
        [NSCursor pop];
    }
    
    currentTool = _currentTool;
    
    if (currentTool == kCCBToolGrab)
    {
        [[NSCursor closedHandCursor] push];
    }
    else if(currentTool == kCCBToolAnchor)
    {
        NSImage * image = [NSImage imageNamed:@"select-crosshair.png"];
        CGPoint centerPoint = CGPointMake(image.size.width/2, image.size.height/2);
        NSCursor * cursor =  [[NSCursor alloc] initWithImage:image hotSpot:centerPoint];
        [cursor push];
    }
    else if (currentTool == kCCBToolRotate)
    {
        NSImage * image = [NSImage imageNamed:@"select-rotation.png"];
        
        float rotation = atan2f(cornerOrientation.y, cornerOrientation.x) - M_PI/4.0f;
        NSImage *img =[self rotateImage:image rotation:rotation];
        CGPoint centerPoint = CGPointMake(img.size.width/2, img.size.height/2);
        NSCursor * cursor =  [[NSCursor alloc] initWithImage:img hotSpot:centerPoint];
        [cursor push];
    }
    else if(currentTool == kCCBToolSize)
    {
        bool showCursor = YES;
        CCNode* currentNode = transformSizeNode ? transformSizeNode : appDelegate.selectedNode;
        NodeInfo *nodeInfo = currentNode.userObject;
        if (nodeInfo) {
            //NSDictionary* propInfo = [nodeInfo.plugIn.nodePropertiesDict objectForKey:@"contentSize"];
            BOOL disabledContentSize = CGSizeEqualToSize(currentNode.contentSizeInPoints, CGSizeZero);
            
            //disable size cursor for corners of Sprites
            showCursor = !disabledContentSize;
        }
        if (showCursor) {
            NSImage *image = [NSImage imageNamed:@"select-scale.png"];
            float rotation = atan2f(cornerOrientation.y, cornerOrientation.x) + M_PI/2.0f;
            NSImage *img = [self rotateImage:image rotation:rotation];
            CGPoint centerPoint = CGPointMake(img.size.width/2, img.size.height/2);
            NSCursor *cursor = [[NSCursor alloc] initWithImage:img hotSpot:centerPoint];
            [cursor push];
        }
    }
    else if(currentTool == kCCBToolTranslate)
    {
        NSImage * image = [NSImage imageNamed:@"select-move.png"];
        CGPoint centerPoint = CGPointMake(image.size.width/2, image.size.height/2);
        NSCursor * cursor =  [[NSCursor alloc] initWithImage:image hotSpot:centerPoint];
        [cursor push];
    }
    
}

- (void) scrollWheel:(NSEvent *)theEvent
{
    snapLinesNeedUpdate = YES; // Disabled in update
    if (!appDelegate.window.isKeyWindow) return;
    if (isMouseTransforming || isPanning || currentMouseTransform != kCCBTransformHandleNone) return;
    if (!appDelegate.hasOpenedDocument) return;
    
    float dx = [theEvent deltaX];
    float dy = -[theEvent deltaY];
    
    if([theEvent modifierFlags] & NSCommandKeyMask)
    {
        if(appDelegate.currentDocument)
        {
            float maxZoom = 8;
            float minZoom = 0.1f;
            float zoom = [self stageZoom];
            if(dy>0)
            {
                while(dy>0)
                {
                    dy -= 1;
                    zoom *= 1/1.05;
                }
            }
            else
            {
                while(dy<0)
                {
                    dy += 1;
                    zoom *= 1.05f;
                }
            }
            if(zoom > maxZoom)
                zoom = maxZoom;
            if(zoom < minZoom)
                zoom = minZoom;
            
            //try to zoom with into mouse cursor, but some problems..
//            CGPoint anchor = ccp([stageBgLayer convertToNodeSpace:mousePos].x / stageBgLayer.contentSize.width,
//                                           [stageBgLayer convertToNodeSpace:mousePos].y / stageBgLayer.contentSize.height);
//            CCLOG(@"%@",NSStringFromPoint(anchor));
//            [self setAnchorPoint:anchor forNode:stageBgLayer];
            
            [self setStageZoom:zoom];           
            
        }
    }
    else
    {
        scrollOffset.x = scrollOffset.x+dx*8;
        scrollOffset.y = scrollOffset.y+dy*8;
    }
    //finally, save all anyway
    CCBDocument *curDoc = appDelegate.currentDocument;
    [curDoc.stageScrollOffsets setValue:@(scrollOffset.x) forKey:[NSString stringWithFormat:@"offset_x_%d",curDoc.currentResolution]];
    [curDoc.stageScrollOffsets setValue:@(scrollOffset.y) forKey:[NSString stringWithFormat:@"offset_y_%d",curDoc.currentResolution]];
    [curDoc.stageZooms setValue:@(self.stageZoom) forKey:[NSString stringWithFormat:@"zoom_%d",curDoc.currentResolution]];
    
}

- (void)setAnchorPoint:(CGPoint)anchorPoint forNode:(CCNode *) node {
    if (!CGPointEqualToPoint(node.anchorPoint, anchorPoint)) {
        CGPoint newPoint = ccp(node.contentSizeInPoints.width * anchorPoint.x,
                               node.contentSizeInPoints.height * anchorPoint.y);
        
        CGPoint oldPoint = ccp(node.contentSizeInPoints.width * node.anchorPoint.x,
                               node.contentSizeInPoints.height * node.anchorPoint.y);
        
        newPoint = CGPointApplyAffineTransform(newPoint, node.nodeToParentTransform);
        oldPoint = CGPointApplyAffineTransform(oldPoint, node.nodeToParentTransform);
        
        CGPoint position = node.positionInPoints;
        
        position.x -= oldPoint.x;
        position.x += newPoint.x;
        
        position.y -= oldPoint.y;
        position.y += newPoint.y;
        
        node.positionInPoints = position;
        node.anchorPoint = anchorPoint;
    }
}


#pragma mark Post update methods

// This method is called once anytime the selection changes
- (void)selectionUpdated {
    snapLinesNeedUpdate = YES;
}

#pragma mark Updates every frame

- (void) forceRedraw
{
    [self update:0];
    snapLinesNeedUpdate = YES; // Required after the update call to prevent lines from being in random places when switching screen sizes.
}

-(BOOL)hideJoints
{
	if([SequencerHandler sharedHandler].currentSequence.timelinePosition != 0.0f || ![SequencerHandler sharedHandler].currentSequence.autoPlay)
    {
        return YES;
    }
    
    if([AppDelegate appDelegate].playingBack)
    {
        return YES;
    }
	
	if(![AppDelegate appDelegate].showJoints)
	{
		return YES;
	}
	
	return NO;
}


- (void) update:(CCTime)delta
{
    // Recenter the content layer
    BOOL winSizeChanged = !CGSizeEqualToSize(winSize, [[CCDirector sharedDirector] viewSize]);
    winSize = [[CCDirector sharedDirector] viewSize];
    CGPoint stageCenter = ccp((int)(winSize.width/2+scrollOffset.x) , (int)(winSize.height/2+scrollOffset.y));
    
    self.contentSize = winSize;
    
    stageBgLayer.position = stageCenter;
    stageJointsLayer.position = stageCenter;
    renderedScene.position = stageCenter;
    renderedScene.anchorPoint = ccp(0.0f, 0.0f);
    
    //i don't understand whats the fuck
    if (stageZoom <= 100 || !renderedScene)
    {
        // Use normal rendering
        stageBgLayer.visible = YES;
        renderedScene.visible = NO;
        [borderDevice texture].antialiased = YES;;
    }
    else
    {
        // Render with render-texture
        stageBgLayer.visible = NO;
        renderedScene.visible = YES;
        renderedScene.scale = stageZoom;
        [renderedScene beginWithClear:0 g:0 b:0 a:1];
        [anchorPointCompensationLayer visit];
        [renderedScene end];
        [borderDevice texture].antialiased = NO;
    }
    // Update selection & physics editor
    [selectionLayer removeAllChildrenWithCleanup:YES];
    [physicsLayer removeAllChildrenWithCleanup:YES];
	jointsLayer.visible = ![self hideJoints];
	
    if (appDelegate.physicsHandler.editingPhysicsBody || appDelegate.selectedNode.plugIn.isJoint)
    {
        [appDelegate.physicsHandler updatePhysicsEditor:physicsLayer];
    }
    else
    {
        [self updateMouseSelection];
        [self updateSelection];
		[self updateDragging];
    }
    
    // Setup border layer
    CGRect bounds = [stageBgLayer boundingBox];
    
    borderBottom.position = ccp(0,0);
    [borderBottom setContentSize:CGSizeMake(winSize.width, bounds.origin.y)];
    
    borderTop.position = ccp(0, bounds.size.height + bounds.origin.y);
    [borderTop setContentSize:CGSizeMake(winSize.width, winSize.height - bounds.size.height - bounds.origin.y)];
    
    borderLeft.position = ccp(0,bounds.origin.y);
    [borderLeft setContentSize:CGSizeMake(bounds.origin.x, bounds.size.height)];
    
    borderRight.position = ccp(bounds.origin.x+bounds.size.width, bounds.origin.y);
    [borderRight setContentSize:CGSizeMake(winSize.width - bounds.origin.x - bounds.size.width, bounds.size.height)];
    
    CGPoint center = ccp(bounds.origin.x+bounds.size.width/2, bounds.origin.y+bounds.size.height/2);
    borderDevice.position = center;
    
    // Update rulers
    origin = ccpAdd(stageCenter, ccpMult(contentLayer.position,stageZoom));
    origin.x -= stageBgLayer.contentSize.width/2 * stageZoom;
    origin.y -= stageBgLayer.contentSize.height/2 * stageZoom;
    
    [rulerLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    [rulerLayer updateMousePos:mousePos];
    
    // Update guides
    guideLayer.visible = (appDelegate.showGuides || appDelegate.showGuideGrid) && appDelegate.showExtras;
    [guideLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    // Update sticky notes
    notesLayer.visible = appDelegate.showStickyNotes && appDelegate.showExtras;
    [notesLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];
    
    // Update Node Snap
    snapLayer.visible = appDelegate.snapNode && appDelegate.snapToggle;
    [snapLayer updateWithSize:winSize stageOrigin:origin zoom:stageZoom];

    if (winSizeChanged)
    {
        // Update mouse tracking
        if (trackingArea)
        {
            [[appDelegate cocosView] removeTrackingArea:trackingArea];
        }
        
				CGSize sizeInPixels = [[CCDirector sharedDirector] viewSizeInPixels];
        trackingArea = [[NSTrackingArea alloc] initWithRect:NSMakeRect(0, 0, sizeInPixels.width, sizeInPixels.height) options:NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow  owner:[appDelegate cocosView] userInfo:NULL];
        [[appDelegate cocosView] addTrackingArea:trackingArea];
    }
    
    [self updateAnchorPointCompensation];
}

- (void) updateAnchorPointCompensation
{
    if (rootNode)
    {
        CGPoint compensation = ccp(rootNode.anchorPoint.x * contentLayer.contentSizeInPoints.width,
                                   rootNode.anchorPoint.y * contentLayer.contentSizeInPoints.height);
        anchorPointCompensationLayer.position = compensation;
    }
}

#pragma mark Document previews

- (void) savePreviewToFile:(NSString*)path
{
    // Remember old position of root node
    CGPoint oldPosition = rootNode.position;
    //and scale
    float oldScale = rootNode.scale;
    
    // Create render context
    CCRenderTexture* render = NULL;
    BOOL trimImage = NO;
    if (self.stageSize.width > 0 && self.stageSize.height > 0)
    {
        //fix for GL_MAX_TEXTURE_SIZE: 16384
        float maxSize = [CCConfiguration sharedConfiguration].maxTextureSize;
        ResolutionSetting *res = [appDelegate.currentDocument.resolutions objectAtIndex:appDelegate.currentDocument.currentResolution];
        float stageHight = res.height;
        float scale = maxSize / stageHight;
        float renderHeight = self.stageSize.height * scale;
        if (stageHight > maxSize) {
            render = [CCRenderTexture renderTextureWithWidth:self.stageSize.width height:renderHeight];
            rootNode.scale = scale;
        } else {
            render = [CCRenderTexture renderTextureWithWidth:self.stageSize.width height:self.stageSize.height];
        }
        rootNode.position = ccp(0,0);
    }
    else
    {
        render = [CCRenderTexture renderTextureWithWidth:2048 height:2048];
        rootNode.position = ccp(1024,1024);
        trimImage = YES;
    }
    
    // Render the root node
    [render beginWithClear:0 g:0 b:0 a:0];
    [anchorPointCompensationLayer visit];
    [render end];
    
    // Reset old position
    rootNode.position = oldPosition;
    //back to old scale
    
    rootNode.scale = oldScale;
    
    CGImageRef imgRef = [render newCGImage];
    
    // Trim image if needed
    if (trimImage)
    {
        CGRect trimRect = [Tupac trimmedRectForImage:imgRef];
        CGImageRef trimmedImgRef = CGImageCreateWithImageInRect(imgRef, trimRect);
        CGImageRelease(imgRef);
        imgRef = trimmedImgRef;
    }
    
    // Save preview file
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
	CGImageDestinationRef dest = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
	CGImageDestinationAddImage(dest, imgRef, nil);
	CGImageDestinationFinalize(dest);
	CFRelease(dest);
    
    // Release image
    CGImageRelease(imgRef);
    
    //resize preview
    NSImageView* kView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 640, 640)];
    [kView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [kView setImage:[[NSImage alloc] initWithContentsOfFile:path]];
    
    NSRect kRect = kView.frame;
    NSBitmapImageRep* kRep = [kView bitmapImageRepForCachingDisplayInRect:kRect];
    [kView cacheDisplayInRect:kRect toBitmapImageRep:kRep];
    
    NSData* kData = [kRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    [kData writeToFile:path atomically:NO];


}

#pragma mark Init and dealloc

-(id) initWithAppDelegate:(AppDelegate*)app;
{
    appDelegate = app;
    
    nodesAtSelectionPt = [NSMutableArray array];
    nodesAtMouseSelection = [NSMutableSet set];
    selectableNodesOnScene = [NSMutableArray array];
    
	if( (self=[super init] ))
    {
        
        [self setupEditorNodes];
        [self setupDefaultNodes];
        
        // self.mouseEnabled = YES;
        self.userInteractionEnabled = YES;
        
        stageZoom = 1;
        
        [self update:0];
	}
	return self;
}

-(void) dealloc
{
	SBLogSelf();
}

#pragma mark Debug


@end
