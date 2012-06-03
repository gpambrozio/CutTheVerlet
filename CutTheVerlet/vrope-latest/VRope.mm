//
//  VRope.m
//
//  Created by patrick on 16/10/2010.
//

#import "VRope.h"


@implementation VRope

@synthesize sticks = vSticks;

#ifdef BOX2D_H

@synthesize joint = joint;

-(id)initWithRopeJoint:(b2RopeJoint*)aJoint spriteSheet:(CCSpriteBatchNode*)spriteSheetArg {
	if((self = [super init])) {
		joint = aJoint;
		CGPoint pointA = ccp(joint->GetAnchorA().x*PTM_RATIO,joint->GetAnchorA().y*PTM_RATIO);
		CGPoint pointB = ccp(joint->GetAnchorB().x*PTM_RATIO,joint->GetAnchorB().y*PTM_RATIO);
		spriteSheet = spriteSheetArg;
		[self createRope:pointA pointB:pointB distance:joint->GetMaxLength()*PTM_RATIO];
	}
	return self;
}

-(void)reset {
	CGPoint pointA = ccp(joint->GetAnchorA().x*PTM_RATIO,joint->GetAnchorA().y*PTM_RATIO);
	CGPoint pointB = ccp(joint->GetAnchorB().x*PTM_RATIO,joint->GetAnchorB().y*PTM_RATIO);
	[self resetWithPoints:pointA pointB:pointB];
}

-(VRope *)cutRopeInStick:(VStick *)stick newBodyA:(b2Body*)newBodyA newBodyB:(b2Body*)newBodyB {
    
    // First, find out where in our array the rope will be cut
    int nPoint = [vSticks indexOfObject:stick];
    
    // Instead of making everything again we'll just use the arrays of
    // sticks, points and sprites we already have and split them
    
    // This is the range that defines the new rope
    NSRange newRopeRange = (NSRange){nPoint, numPoints-nPoint-1};
    
    // Keep the sticks in a new array
    NSArray *newRopeSticks = [vSticks subarrayWithRange:newRopeRange];
    
    // and remove from this object's array
    [vSticks removeObjectsInRange:newRopeRange];
    
    // Same for the sprites
    NSArray *newRopeSprites = [ropeSprites subarrayWithRange:newRopeRange];
    [ropeSprites removeObjectsInRange:newRopeRange];
    
    // Number of points is always the number of sticks + 1
    newRopeRange.length += 1;
    NSArray *newRopePoints = [vPoints subarrayWithRange:newRopeRange];
    [vPoints removeObjectsInRange:newRopeRange];
    
    // The removeObjectsInRange above removed the last point of
    // this rope that now belongs to the new rope. We need to clone
    // that VPoint and add it to this rope, otherwise we'll have a
    // wrong number of points in this rope
    VPoint *pointOfBreak = [newRopePoints objectAtIndex:0];
    VPoint *newPoint = [[VPoint alloc] init];
    [newPoint setPos:pointOfBreak.x y:pointOfBreak.y];
    [vPoints addObject:newPoint];
    
    // And last: fix the last VStick of this rope to point to this new point
    // instead of the old point that now belongs to the new rope
    VStick *lastStick = [vSticks lastObject];
    [lastStick setPointB:newPoint];
    [newPoint release];
    
    // This will determine how long the rope is now and how long the new rope will be
    float32 cutRatio = (float32)nPoint / (numPoints - 1);
    
    // Fix my number of points
    numPoints = nPoint + 1;
    
    // Position in Box2d world where the new bodies will initially be
    b2Vec2 newBodiesPosition = b2Vec2(pointOfBreak.x / PTM_RATIO, pointOfBreak.y / PTM_RATIO);

    // Get a reference to the world to create the new joint
    b2World *world = newBodyA->GetWorld();
    
    // Re-create the joint used in this VRope since bRopeJoint does not allow
    // to re-define the attached bodies
    b2RopeJointDef jd;
    jd.bodyA = joint->GetBodyA();
    jd.bodyB = newBodyB;
    jd.localAnchorA = joint->GetLocalAnchorA();
    jd.localAnchorB = b2Vec2(0, 0);
    jd.maxLength = joint->GetMaxLength() * cutRatio;
    newBodyB->SetTransform(newBodiesPosition, 0.0);
    
    b2RopeJoint *newJoint1 = (b2RopeJoint *)world->CreateJoint(&jd); //create joint

    // Create the new rope joint
    jd.bodyA = newBodyA;
    jd.bodyB = joint->GetBodyB();
    jd.localAnchorA = b2Vec2(0, 0);
    jd.localAnchorB = joint->GetLocalAnchorB();
    jd.maxLength = joint->GetMaxLength() * (1 - cutRatio);
    newBodyA->SetTransform(newBodiesPosition, 0.0);
    
    b2RopeJoint *newJoint2 = (b2RopeJoint *)world->CreateJoint(&jd); //create joint

    // Destroy the old joint and update to the new one
    world->DestroyJoint(joint);
    joint = newJoint1;
    
    // Finally, create the new VRope
    VRope *newRope = [[VRope alloc] initWithRopeJoint:newJoint2
                                          spriteSheet:spriteSheet
                                               points:newRopePoints
                                               sticks:newRopeSticks
                                              sprites:newRopeSprites];
    return [newRope autorelease];
}

-(id)initWithRopeJoint:(b2RopeJoint*)aJoint 
           spriteSheet:(CCSpriteBatchNode*)spriteSheetArg
                points:(NSArray*)points 
                sticks:(NSArray*)sticks
               sprites:(NSArray*)sprites {
	if((self = [super init])) {
        joint = aJoint;
		spriteSheet = spriteSheetArg;
        vPoints = [[NSMutableArray alloc] initWithArray:points];
        vSticks = [[NSMutableArray alloc] initWithArray:sticks];
        ropeSprites = [[NSMutableArray alloc] initWithArray:sprites];
        numPoints = vPoints.count;
	}
	return self;
}

-(void)update:(float)dt {
	CGPoint pointA = ccp(joint->GetAnchorA().x*PTM_RATIO,joint->GetAnchorA().y*PTM_RATIO);
	CGPoint pointB = ccp(joint->GetAnchorB().x*PTM_RATIO,joint->GetAnchorB().y*PTM_RATIO);
	[self updateWithPoints:pointA pointB:pointB dt:dt];
}

#endif

-(id)initWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB spriteSheet:(CCSpriteBatchNode*)spriteSheetArg {
	if((self = [super init])) {
		spriteSheet = spriteSheetArg;
		[self createRope:pointA pointB:pointB distance:ccpDistance(pointA, pointB)];
	}
	return self;
}

-(void)createRope:(CGPoint)pointA pointB:(CGPoint)pointB distance:(float)distance {
	vPoints = [[NSMutableArray alloc] init];
	vSticks = [[NSMutableArray alloc] init];
	ropeSprites = [[NSMutableArray alloc] init];
	int segmentFactor = 6; //increase value to have less segments per rope, decrease to have more segments
	numPoints = distance/segmentFactor;
	CGPoint diffVector = ccpSub(pointB,pointA);
	float multiplier = distance / (numPoints-1);
	antiSagHack = 0.1f; //HACK: scale down rope points to cheat sag. set to 0 to disable, max suggested value 0.1
	for(int i=0;i<numPoints;i++) {
		CGPoint tmpVector = ccpAdd(pointA, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
		VPoint *tmpPoint = [[VPoint alloc] init];
		[tmpPoint setPos:tmpVector.x y:tmpVector.y];
		[vPoints addObject:tmpPoint];
        [tmpPoint release];
	}
	for(int i=0;i<numPoints-1;i++) {
		VStick *tmpStick = [[VStick alloc] initWith:[vPoints objectAtIndex:i] pointb:[vPoints objectAtIndex:i+1]];
		[vSticks addObject:tmpStick];
        [tmpStick release];
	}
	if(spriteSheet!=nil) {
		for(int i=0;i<numPoints-1;i++) {
			VPoint *point1 = [[vSticks objectAtIndex:i] getPointA];
			VPoint *point2 = [[vSticks objectAtIndex:i] getPointB];
			CGPoint stickVector = ccpSub(ccp(point1.x,point1.y),ccp(point2.x,point2.y));
			float stickAngle = ccpToAngle(stickVector);
			CCSprite *tmpSprite = [CCSprite spriteWithTexture:spriteSheet.texture
                                                         rect:CGRectMake(0,0,
                                                                         multiplier,
                                                                         [[[spriteSheet textureAtlas] texture] pixelsHigh]/CC_CONTENT_SCALE_FACTOR())];
			ccTexParams params = {GL_LINEAR,GL_LINEAR,GL_REPEAT,GL_REPEAT};
			[tmpSprite.texture setTexParameters:&params];
			[tmpSprite setPosition:ccpMidpoint(ccp(point1.x,point1.y),ccp(point2.x,point2.y))];
			[tmpSprite setRotation:-1 * CC_RADIANS_TO_DEGREES(stickAngle)];
			[spriteSheet addChild:tmpSprite];
			[ropeSprites addObject:tmpSprite];
		}
	}
}

-(void)resetWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB {
	float distance = ccpDistance(pointA,pointB);
	CGPoint diffVector = ccpSub(pointB,pointA);
	float multiplier = distance / (numPoints - 1);
	for(int i=0;i<numPoints;i++) {
		CGPoint tmpVector = ccpAdd(pointA, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
		VPoint *tmpPoint = [vPoints objectAtIndex:i];
		[tmpPoint setPos:tmpVector.x y:tmpVector.y];
		
	}
}

-(void)removeSprites {
	for(int i=0;i<numPoints-1;i++) {
		CCSprite *tmpSprite = [ropeSprites objectAtIndex:i];
		[spriteSheet removeChild:tmpSprite cleanup:YES];
	}
	[ropeSprites removeAllObjects];
	[ropeSprites release];
}

-(void)updateWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB dt:(float)dt {
	//manually set position for first and last point of rope
	[[vPoints objectAtIndex:0] setPos:pointA.x y:pointA.y];
	[[vPoints objectAtIndex:numPoints-1] setPos:pointB.x y:pointB.y];
	
	//update points, apply gravity
	for(int i=1;i<numPoints-1;i++) {
		[[vPoints objectAtIndex:i] applyGravity:dt];
		[[vPoints objectAtIndex:i] update];
	}
	
	//contract sticks
	int iterations = 4;
	for(int j=0;j<iterations;j++) {
		for(int i=0;i<numPoints-1;i++) {
			[[vSticks objectAtIndex:i] contract];
		}
	}
}

-(void)updateSprites {
	if(spriteSheet!=nil) {
		for(int i=0;i<numPoints-1;i++) {
			VPoint *point1 = [[vSticks objectAtIndex:i] getPointA];
			VPoint *point2 = [[vSticks objectAtIndex:i] getPointB];
			CGPoint point1_ = ccp(point1.x,point1.y);
			CGPoint point2_ = ccp(point2.x,point2.y);
			float stickAngle = ccpToAngle(ccpSub(point1_,point2_));
			CCSprite *tmpSprite = [ropeSprites objectAtIndex:i];
			[tmpSprite setPosition:ccpMidpoint(point1_,point2_)];
			[tmpSprite setRotation: -CC_RADIANS_TO_DEGREES(stickAngle)];
		}
	}	
}

-(void)dealloc {
	[vPoints removeAllObjects];
	[vSticks removeAllObjects];
	[vPoints release];
	[vSticks release];
	[super dealloc];
}

@end
