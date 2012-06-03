//
//  HelloWorldLayer.mm
//  CutTheVerlet
//
//  Created by Gustavo Ambrozio on 2/6/12.
//  Copyright OpenTheJob 2012. All rights reserved.
//

// Import the interfaces
#import "HelloWorldLayer.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"

#import "PhysicsSprite.h"
#import "VRope.h"

#import <set>

enum {
	kTagParentNode = 1,
};


#pragma mark - HelloWorldLayer

@interface HelloWorldLayer()
-(void) initPhysics;
@end

@implementation HelloWorldLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	HelloWorldLayer *layer = [HelloWorldLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(id) init
{
	if( (self=[super init])) {
		
		// enable events
		
		self.isTouchEnabled = YES;
		
        ropes = [[NSMutableArray alloc] init];
        candies = [[NSMutableArray alloc] init];
        ropeSpriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"rope_texture.png"];
        [self addChild:ropeSpriteSheet];

        // Load the sprite sheet into the sprite cache
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:@"CutTheVerlet.plist"];
        
		// Add the background
        CCSprite *background = [CCSprite spriteWithSpriteFrameName:@"bg.png"];
        background.anchorPoint = CGPointZero;
        [self addChild:background z:-1];
        
        // Add the croc
        croc_ = [CCSprite spriteWithSpriteFrameName:@"croc_front_mouthclosed.png"];
        croc_.anchorPoint = CGPointMake(1.0, 0.0);
        croc_.position = CGPointMake(320.0, 30.0);
        [self addChild:croc_ z:1];
        
		// init physics
		[self initPhysics];
        [self initLevel];
		
		[self scheduleUpdate];
	}
	return self;
}

-(void) dealloc
{
    [crocAttitudeTimer invalidate];
    [crocAttitudeTimer release];

    [ropes release];
    [candies release];

    delete contactListener;
    contactListener = NULL;

	delete world;
	world = NULL;
	
	delete m_debugDraw;
	m_debugDraw = NULL;
	
	[super dealloc];
}	

-(void) initPhysics
{
	
	CGSize s = [[CCDirector sharedDirector] winSize];
	
	b2Vec2 gravity;
	gravity.Set(0.0f, -10.0f);
	world = new b2World(gravity);
	
	
	// Do we want to let bodies sleep?
	world->SetAllowSleeping(true);
	
	world->SetContinuousPhysics(true);
	
	m_debugDraw = new GLESDebugDraw( PTM_RATIO );
	world->SetDebugDraw(m_debugDraw);
	
	uint32 flags = 0;
	flags += b2Draw::e_shapeBit;
	//		flags += b2Draw::e_jointBit;
	//		flags += b2Draw::e_aabbBit;
	//		flags += b2Draw::e_pairBit;
	//		flags += b2Draw::e_centerOfMassBit;
	m_debugDraw->SetFlags(flags);		
	
	
	// Define the ground body.
	b2BodyDef groundBodyDef;
	groundBodyDef.position.Set(0, 0); // bottom-left corner
	
	// Call the body factory which allocates memory for the ground body
	// from a pool and creates the ground box shape (also from a pool).
	// The body is also added to the world.
	groundBody = world->CreateBody(&groundBodyDef);
	
	// Define the ground box shape.
	b2EdgeShape groundBox;		
	
	// bottom
	
	groundBox.Set(b2Vec2(0,0), b2Vec2(s.width/PTM_RATIO,0));
	groundBody->CreateFixture(&groundBox,0);
	
	// top
	groundBox.Set(b2Vec2(0,s.height/PTM_RATIO), b2Vec2(s.width/PTM_RATIO,s.height/PTM_RATIO));
	groundBody->CreateFixture(&groundBox,0);
	
	// left
	groundBox.Set(b2Vec2(0,s.height/PTM_RATIO), b2Vec2(0,0));
	groundBody->CreateFixture(&groundBox,0);
	
	// right
	groundBox.Set(b2Vec2(s.width/PTM_RATIO,s.height/PTM_RATIO), b2Vec2(s.width/PTM_RATIO,0));
	groundBody->CreateFixture(&groundBox,0);
    
	// Define the croc's "mouth".
	b2BodyDef crocBodyDef;
	crocBodyDef.position.Set((s.width - croc_.textureRect.size.width)/PTM_RATIO, (croc_.position.y)/PTM_RATIO);
	
	crocMouth_ = world->CreateBody(&crocBodyDef);
	
	// Define the croc's box shape.
	b2EdgeShape crocBox;
	
	// bottom
	crocBox.Set(b2Vec2(5.0/PTM_RATIO,15.0/PTM_RATIO), b2Vec2(45.0/PTM_RATIO,15.0/PTM_RATIO));
	crocMouthBottom_ = crocMouth_->CreateFixture(&crocBox,0);
	
    crocMouth_->SetActive(NO);

    // Create contact listener
    contactListener = new MyContactListener();
    world->SetContactListener(contactListener);
}

-(void) draw
{
	//
	// IMPORTANT:
	// This is only for debug purposes
	// It is recommend to disable it
	//
	[super draw];
	
	ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
	
	kmGLPushMatrix();
	
	world->DrawDebugData();	
	
	kmGLPopMatrix();
}

-(void) update: (ccTime) dt
{
	//It is recommended that a fixed time step is used with Box2D for stability
	//of the simulation, however, we are using a variable time step here.
	//You need to make an informed choice, the following URL is useful
	//http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed.
	world->Step(dt, velocityIterations, positionIterations);	

	//Iterate over the bodies in the physics world
	for (b2Body* b = world->GetBodyList(); b; b = b->GetNext())
	{
        CCSprite *myActor = (CCSprite*)b->GetUserData();
		if (myActor)
        {
            //Synchronize the AtlasSprites position and rotation with the corresponding body
            myActor.position = CGPointMake( b->GetPosition().x * PTM_RATIO, b->GetPosition().y * PTM_RATIO);
            myActor.rotation = -1 * CC_RADIANS_TO_DEGREES(b->GetAngle());
		}	
	}
    
    // Update all the ropes
    for (VRope *rope in ropes)
    {
        [rope update:dt];
        [rope updateSprites];
    }
    
    // Check for collisions
    bool shouldCloseCrocMouth = NO;
    std::vector<b2Body *>toDestroy;
    std::vector<MyContact>::iterator pos;
    for(pos = contactListener->_contacts.begin(); pos != contactListener->_contacts.end(); ++pos)
    {
        MyContact contact = *pos;
        
        bool hitTheFloor = NO;
        b2Body *potentialCandy = nil;
        
        // The candy can hit the floor or the croc's mouth. Let's check
        // what it's touching.
        if (contact.fixtureA == crocMouthBottom_)
        {
            potentialCandy = contact.fixtureB->GetBody();
        }
        else if (contact.fixtureB == crocMouthBottom_)
        {
            potentialCandy = contact.fixtureA->GetBody();
        }
        else if (contact.fixtureA->GetBody() == groundBody)
        {
            potentialCandy = contact.fixtureB->GetBody();
            hitTheFloor = YES;
        }
        else if (contact.fixtureB->GetBody() == groundBody)
        {
            potentialCandy = contact.fixtureA->GetBody();
            hitTheFloor = YES;
        }
        
        // Check if the body was indeed one of the candies
        if (potentialCandy && [candies indexOfObject:[NSValue valueWithPointer:potentialCandy]] != NSNotFound)
        {
            // Set it to be destroyed
            toDestroy.push_back(potentialCandy);
            if (hitTheFloor)
            {
                // If it hits the floor we'll remove all the physics of it and just simulate the pineapple sinking
                CCSprite *sinkingCandy = (CCSprite*)potentialCandy->GetUserData();
                
                // Sink the pineapple
                CCFiniteTimeAction *sink = [CCMoveBy actionWithDuration:3.0 position:CGPointMake(0, -sinkingCandy.textureRect.size.height)];
                
                // Remove the sprite and check if should finish the level.
                CCFiniteTimeAction *finish = [CCCallBlockN actionWithBlock:^(CCNode *node)
                                    {
                                        [self removeChild:node cleanup:YES];
                                        [self checkLevelFinish:YES];
                                    }];
                
                // Run the actions sequentially.
                [sinkingCandy runAction:[CCSequence actions:
                                         sink,
                                         finish,
                                         nil]];
                
                // All the physics will be destroyed below, but we don't want the
                // sprite do be removed, so we set it to null here.
                potentialCandy->SetUserData(NULL);
            }
            else
            {
                shouldCloseCrocMouth = YES;
            }
        }
    }
    
    std::vector<b2Body *>::iterator pos2;
    for(pos2 = toDestroy.begin(); pos2 != toDestroy.end(); ++pos2)
    {
        b2Body *body = *pos2;
        if (body->GetUserData() != NULL)
        {
            // Remove the sprite
            CCSprite *sprite = (CCSprite *) body->GetUserData();
            [self removeChild:sprite cleanup:YES];
            body->SetUserData(NULL);
        }
        
        // Iterate though the joins and check if any are a rope
        b2JointEdge* joints = body->GetJointList();
        while (joints)
        {
            b2Joint *joint = joints->joint;
            
            // Look in all the ropes
            for (VRope *rope in ropes)
            {
                if (rope.joint == joint)
                {
                    // This "destroys" the rope
                    [rope removeSprites];
                    [ropes removeObject:rope];
                    break;
                }
            }
            
            joints = joints->next;
            world->DestroyJoint(joint);
        }
        
        // Destroy the physics body
        world->DestroyBody(body);
        
        // Removes from the candies array
        [candies removeObject:[NSValue valueWithPointer:body]];
    }
    
    if (shouldCloseCrocMouth)
    {
        // If the pineapple went into the croc's mouth, immediatelly closes it.
        [self changeCrocAttitude];
        
        // Check if the level should finish
        [self checkLevelFinish:NO];
    }
}

-(void)checkLevelFinish:(BOOL)forceFinish
{
    if ([candies count] == 0 || forceFinish)
    {
        // Destroy everything
        [self finishedLevel];
        
        // Schedule a level restart 2 seconds from now
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self initLevel];
        });
    }
}

-(void) finishedLevel
{
    std::set<b2Body *>toDestroy;
    
    // Destroy every rope and add the objects that should be destroyed
    for (VRope *rope in ropes)
    {
        [rope removeSprites];
        
        // Don't destroy the ground body...
        if (rope.joint->GetBodyA() != groundBody)
            toDestroy.insert(rope.joint->GetBodyA());
        if (rope.joint->GetBodyB() != groundBody)
            toDestroy.insert(rope.joint->GetBodyB());
        
        // Destroy the joint already
        world->DestroyJoint(rope.joint);
    }
    [ropes removeAllObjects];
    
    // Destroy all the objects
    std::set<b2Body *>::iterator pos;
    for(pos = toDestroy.begin(); pos != toDestroy.end(); ++pos)
    {
        b2Body *body = *pos;
        if (body->GetUserData() != NULL)
        {
            // Remove the sprite
            CCSprite *sprite = (CCSprite *) body->GetUserData();
            [self removeChild:sprite cleanup:YES];
            body->SetUserData(NULL);
        }
        world->DestroyBody(body);
    }
    
    [candies removeAllObjects];
}

-(b2Body *) createCandyAt:(CGPoint)pt
{
    // Get the sprite from the sprite sheet
    CCSprite *sprite = [CCSprite spriteWithSpriteFrameName:@"pineapple.png"];
    [self addChild:sprite];
    
    // Defines the body of our candy
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;
    bodyDef.position = b2Vec2(pt.x/PTM_RATIO, pt.y/PTM_RATIO);
    bodyDef.userData = sprite;
    bodyDef.linearDamping = 0.3f;
    b2Body *body = world->CreateBody(&bodyDef);
    
    // Define the fixture as a polygon
    b2FixtureDef fixtureDef;
    b2PolygonShape spriteShape;
    
    b2Vec2 verts[] = {
        b2Vec2(-7.6f / PTM_RATIO, -34.4f / PTM_RATIO),
        b2Vec2(8.3f / PTM_RATIO, -34.4f / PTM_RATIO),
        b2Vec2(15.55f / PTM_RATIO, -27.15f / PTM_RATIO),
        b2Vec2(13.8f / PTM_RATIO, 23.05f / PTM_RATIO),
        b2Vec2(-3.35f / PTM_RATIO, 35.25f / PTM_RATIO),
        b2Vec2(-16.25f / PTM_RATIO, 25.55f / PTM_RATIO),
        b2Vec2(-15.55f / PTM_RATIO, -23.95f / PTM_RATIO)
    };
    
    spriteShape.Set(verts, 7);
    fixtureDef.shape = &spriteShape;
    fixtureDef.density = 30.0f;
    fixtureDef.filter.categoryBits = 0x01;
    fixtureDef.filter.maskBits = 0x01;
    body->CreateFixture(&fixtureDef);
    
    [candies addObject:[NSValue valueWithPointer:body]];

    return body;
}

-(void) createRopeWithBodyA:(b2Body*)bodyA anchorA:(b2Vec2)anchorA
                      bodyB:(b2Body*)bodyB anchorB:(b2Vec2)anchorB
                        sag:(float32)sag
{
    b2RopeJointDef jd;
    jd.bodyA = bodyA;
    jd.bodyB = bodyB;
    jd.localAnchorA = anchorA;
    jd.localAnchorB = anchorB;
    
    // Max length of joint = current distance between bodies * sag
    float32 ropeLength = (bodyA->GetWorldPoint(anchorA) - bodyB->GetWorldPoint(anchorB)).Length() * sag;
    jd.maxLength = ropeLength;

    // Create joint
    b2RopeJoint *ropeJoint = (b2RopeJoint *)world->CreateJoint(&jd);
    
    VRope *newRope = [[VRope alloc] initWithRopeJoint:ropeJoint spriteSheet:ropeSpriteSheet];
    
    [ropes addObject:newRope];
    [newRope release];
}


#define cc_to_b2Vec(x,y)   (b2Vec2((x)/PTM_RATIO, (y)/PTM_RATIO))

-(void) initLevel 
{
	CGSize s = [[CCDirector sharedDirector] winSize];
    
    // Add the candy
    b2Body *body1 = [self createCandyAt:CGPointMake(s.width * 0.5, s.height * 0.7)]; 
    
    // Add a bunch of ropes
    [self createRopeWithBodyA:groundBody anchorA:cc_to_b2Vec(s.width * 0.15, s.height * 0.8) 
                        bodyB:body1 anchorB:body1->GetLocalCenter()
                          sag:1.1];
    
    [self createRopeWithBodyA:body1 anchorA:body1->GetLocalCenter()
                        bodyB:groundBody anchorB:cc_to_b2Vec(s.width * 0.85, s.height * 0.8)
                          sag:1.1];
    
    [self createRopeWithBodyA:body1 anchorA:body1->GetLocalCenter()
                        bodyB:groundBody anchorB:cc_to_b2Vec(s.width * 0.83, s.height * 0.6)
                          sag:1.1];

    // Add the candy
    b2Body *body2 = [self createCandyAt:CGPointMake(s.width * 0.5, s.height)];
    
    // Change the linear dumping so it swings more
    body2->SetLinearDamping(0.01);
    
    // Add a bunch of ropes
    [self createRopeWithBodyA:groundBody anchorA:cc_to_b2Vec(s.width * 0.65, s.height + 5)
                        bodyB:body2 anchorB:body2->GetLocalCenter()
                          sag:1.0];
    
    // Advance the world by a few seconds to stabilize everything.
    int n = 10 * 60;
    int32 velocityIterations = 8;
    int32 positionIterations = 1;
    float32 dt = 1.0 / 60.0;
    while (n--)
    {
        // Instruct the world to perform a single step of simulation.
        world->Step(dt, velocityIterations, positionIterations);
        for (VRope *rope in ropes)
        {
            [rope update:dt];
        }
    }
    
    // This last update takes care of the texture repositioning.
    [self update:dt];
    
    crocMouthOpened = YES;
    [self changeCrocAttitude];
}

- (BOOL)checkLineIntersection:(CGPoint)p1 :(CGPoint)p2 :(CGPoint)p3 :(CGPoint)p4
{
    // http://local.wasp.uwa.edu.au/~pbourke/geometry/lineline2d/
    CGFloat denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);

    // In this case the lines are parallel so we assume they don't intersect
    if (denominator == 0.0f)
        return NO;
    CGFloat ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator;
    CGFloat ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator;
    
    if (ua >= 0.0 && ua <= 1.0 && ub >= 0.0 && ub <= 1.0)
    {
        return YES;
    }
    
    return NO;
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    static CGSize s = [[CCDirector sharedDirector] winSize];
    
    UITouch *touch = [touches anyObject];
    CGPoint pt0 = [touch previousLocationInView:[touch view]];
    CGPoint pt1 = [touch locationInView:[touch view]];
    
    // Correct Y axis coordinates to cocos2d coordinates
    pt0.y = s.height - pt0.y;
    pt1.y = s.height - pt1.y;
    
    for (VRope *rope in ropes)
    {
        for (VStick *stick in rope.sticks)
        {
            CGPoint pa = [[stick getPointA] point];
            CGPoint pb = [[stick getPointB] point];
            
            if ([self checkLineIntersection:pt0 :pt1 :pa :pb])
            {
                // Cut the rope here
                b2Body *newBodyA = [self createRopeTipBody];
                b2Body *newBodyB = [self createRopeTipBody];
                
                VRope *newRope = [rope cutRopeInStick:stick newBodyA:newBodyA newBodyB:newBodyB];
                [ropes addObject:newRope];
                return;
            }
        }
    }
}

-(b2Body *) createRopeTipBody
{
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;
    bodyDef.linearDamping = 0.5f;
    b2Body *body = world->CreateBody(&bodyDef);
    
    b2FixtureDef circleDef;
    b2CircleShape circle;
    circle.m_radius = 1.0/PTM_RATIO;
    circleDef.shape = &circle;
    circleDef.density = 10.0f;
    
    // Since these tips don't have to collide with anything
    // set the mask bits to zero
    circleDef.filter.maskBits = 0;
    body->CreateFixture(&circleDef);
    
    return body;
}

-(void)changeCrocAttitude
{
    crocMouthOpened = !crocMouthOpened;
    NSString *spriteName = crocMouthOpened ? @"croc_front_mouthopen.png" : @"croc_front_mouthclosed.png";
    [croc_ setDisplayFrame:[[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:spriteName]];
    [croc_ setZOrder:crocMouthOpened ? 1 : -1];
    
    crocMouth_->SetActive(crocMouthOpened);
    
    [crocAttitudeTimer invalidate];
    [crocAttitudeTimer release];
    crocAttitudeTimer = [[NSTimer scheduledTimerWithTimeInterval:3.0 + 2.0 * CCRANDOM_0_1() 
                                                          target:self 
                                                        selector:@selector(changeCrocAttitude) 
                                                        userInfo:nil 
                                                         repeats:NO] retain];
}

#pragma mark GameKit delegate

-(void) achievementViewControllerDidFinish:(GKAchievementViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}

-(void) leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController
{
	AppController *app = (AppController*) [[UIApplication sharedApplication] delegate];
	[[app navController] dismissModalViewControllerAnimated:YES];
}

@end
