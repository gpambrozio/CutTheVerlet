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
    [ropes release];
    [candies release];

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
