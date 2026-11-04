/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
*/

/* A small physics engine with SpriteKit's units and rules: circles and
   convex polygons (rectangles, polygons; textures as their rectangle),
   static edges, gravity, impulses and forces, collisions resolved by the
   bodies' collision masks, and contacts reported by their contact masks.
   No joints, fields or angular dynamics from collisions. */

#import "SKInternal.h"

#define SK_MAX_VERTICES 32

enum { SK_SHAPE_CIRCLE, SK_SHAPE_POLYGON };

typedef struct {
	int kind;
	CGPoint center; /* circles; the centroid for polygons */
	CGFloat radius;
	CGPoint v[SK_MAX_VERTICES];
	int n; /* a polygon's vertices, counterclockwise; 2 for an edge */
} SKShape;

@implementation SKPhysicsBody {
@public
	/* Shapes in the node's coordinates. */
	SKShape *_shapes;
	int _shapeCount;
	/* The node's scale when the body was given to it: shapes are made to
	   the node's size, which includes its scale, so only later changes of
	   the scale scale the body. */
	CGFloat _attachedXScale, _attachedYScale;
	BOOL _edge;
	CGFloat _area; /* points squared */
	BOOL _dynamic, _usesPreciseCollisionDetection, _allowsRotation, _pinned, _resting, _affectedByGravity;
	CGFloat _friction, _charge, _restitution, _linearDamping, _angularDamping, _density, _mass;
	BOOL _massSet;
	uint32_t _fieldBitMask, _categoryBitMask, _collisionBitMask, _contactTestBitMask;
	CGVector _velocity; /* points a second, in the scene */
	CGFloat _angularVelocity;
	CGVector _force;
	CGFloat _torque;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_dynamic = YES;
		_allowsRotation = YES;
		_affectedByGravity = YES;
		_friction = 0.2;
		_restitution = 0.2;
		_linearDamping = 0.1;
		_angularDamping = 0.1;
		_density = 1;
		_categoryBitMask = 0xFFFFFFFF;
		_collisionBitMask = 0xFFFFFFFF;
		_fieldBitMask = 0xFFFFFFFF;
	}
	return self;
}

- (void)dealloc
{
	free(_shapes);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return [self init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (id)copyWithZone:(NSZone *)zone
{
	SKPhysicsBody *copy = [[SKPhysicsBody alloc] init];
	copy->_shapes = malloc(sizeof(SKShape) * MAX(_shapeCount, 1));
	memcpy(copy->_shapes, _shapes, sizeof(SKShape) * _shapeCount);
	copy->_shapeCount = _shapeCount;
	copy->_edge = _edge;
	copy->_area = _area;
	copy->_dynamic = _dynamic;
	copy->_allowsRotation = _allowsRotation;
	copy->_pinned = _pinned;
	copy->_affectedByGravity = _affectedByGravity;
	copy->_friction = _friction;
	copy->_restitution = _restitution;
	copy->_linearDamping = _linearDamping;
	copy->_angularDamping = _angularDamping;
	copy->_density = _density;
	copy->_mass = _mass;
	copy->_massSet = _massSet;
	copy->_categoryBitMask = _categoryBitMask;
	copy->_collisionBitMask = _collisionBitMask;
	copy->_contactTestBitMask = _contactTestBitMask;
	copy->_fieldBitMask = _fieldBitMask;
	return copy;
}

static SKPhysicsBody *SKBodyWithShapes(SKShape *shapes, int count, BOOL edge)
{
	SKPhysicsBody *body = [[SKPhysicsBody alloc] init];
	body->_shapes = malloc(sizeof(SKShape) * MAX(count, 1));
	memcpy(body->_shapes, shapes, sizeof(SKShape) * count);
	body->_shapeCount = count;
	body->_edge = edge;
	if (edge)
		body->_dynamic = NO;
	CGFloat area = 0;
	for (int i = 0; i < count; i++) {
		SKShape *s = &shapes[i];
		if (s->kind == SK_SHAPE_CIRCLE)
			area += M_PI * s->radius * s->radius;
		else if (s->n >= 3)
			for (int k = 0; k < s->n; k++) {
				CGPoint a = s->v[k], b = s->v[(k + 1) % s->n];
				area += (a.x * b.y - b.x * a.y) / 2;
			}
	}
	body->_area = fabs(area);
	return body;
}

static SKShape SKPolygon(const CGPoint *points, int n)
{
	SKShape s = { SK_SHAPE_POLYGON };
	s.n = MIN(n, SK_MAX_VERTICES);
	CGFloat cx = 0, cy = 0, signedArea = 0;
	for (int i = 0; i < s.n; i++) {
		s.v[i] = points[i];
		cx += points[i].x;
		cy += points[i].y;
	}
	for (int i = 0; s.n >= 3 && i < s.n; i++) {
		CGPoint a = s.v[i], b = s.v[(i + 1) % s.n];
		signedArea += a.x * b.y - b.x * a.y;
	}
	/* Counterclockwise, so that edge normals point out. */
	if (signedArea < 0)
		for (int i = 0; i < s.n / 2; i++) {
			CGPoint t = s.v[i];
			s.v[i] = s.v[s.n - 1 - i];
			s.v[s.n - 1 - i] = t;
		}
	s.center = s.n > 0 ? CGPointMake(cx / s.n, cy / s.n) : CGPointZero;
	return s;
}

static SKShape SKRectShape(CGRect r)
{
	CGPoint p[4] = { { CGRectGetMinX(r), CGRectGetMinY(r) }, { CGRectGetMaxX(r), CGRectGetMinY(r) },
		{ CGRectGetMaxX(r), CGRectGetMaxY(r) }, { CGRectGetMinX(r), CGRectGetMaxY(r) } };
	return SKPolygon(p, 4);
}

+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r
{
	return [self bodyWithCircleOfRadius:r center:CGPointZero];
}

+ (SKPhysicsBody *)bodyWithCircleOfRadius:(CGFloat)r center:(CGPoint)center
{
	SKShape s = { SK_SHAPE_CIRCLE, center, r };
	return SKBodyWithShapes(&s, 1, NO);
}

+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)s
{
	return [self bodyWithRectangleOfSize:s center:CGPointZero];
}

+ (SKPhysicsBody *)bodyWithRectangleOfSize:(CGSize)size center:(CGPoint)center
{
	SKShape s = SKRectShape(CGRectMake(center.x - size.width / 2, center.y - size.height / 2, size.width, size.height));
	return SKBodyWithShapes(&s, 1, NO);
}

/* The path's points, flattened roughly: curves by their end points. */
static int SKPathPoints(CGPathRef path, CGPoint *out, int capacity, BOOL *closed)
{
	__block int n = 0;
	__block BOOL isClosed = NO;
	SKPathApply(path, ^(const CGPathElement *e) {
		int count = e->type == kCGPathElementAddQuadCurveToPoint ? 2 : e->type == kCGPathElementAddCurveToPoint ? 3 : 1;
		if (e->type == kCGPathElementCloseSubpath) {
			isClosed = YES;
			return;
		}
		if (n < capacity)
			out[n++] = e->points[count - 1];
	});
	if (closed != NULL)
		*closed = isClosed;
	return n;
}

/* The convex hull (Andrew's monotone chain) of the points. */
static int SKHull(CGPoint *p, int n, CGPoint *hull)
{
	for (int i = 1; i < n; i++)
		for (int j = i; j > 0 && (p[j].x < p[j - 1].x || (p[j].x == p[j - 1].x && p[j].y < p[j - 1].y)); j--) {
			CGPoint t = p[j];
			p[j] = p[j - 1];
			p[j - 1] = t;
		}
	if (n < 3) {
		memcpy(hull, p, sizeof(CGPoint) * n);
		return n;
	}
	int k = 0;
#define CROSS(o, a, b) (((a).x - (o).x) * ((b).y - (o).y) - ((a).y - (o).y) * ((b).x - (o).x))
	for (int i = 0; i < n; i++) {
		while (k >= 2 && CROSS(hull[k - 2], hull[k - 1], p[i]) <= 0)
			k--;
		hull[k++] = p[i];
	}
	for (int i = n - 2, t = k + 1; i >= 0; i--) {
		while (k >= t && CROSS(hull[k - 2], hull[k - 1], p[i]) <= 0)
			k--;
		hull[k++] = p[i];
	}
#undef CROSS
	return k - 1;
}

+ (SKPhysicsBody *)bodyWithPolygonFromPath:(CGPathRef)path
{
	CGPoint points[256], hull[257];
	int n = path != NULL ? SKPathPoints(path, points, 256, NULL) : 0;
	n = SKHull(points, n, hull);
	SKShape s = SKPolygon(hull, n);
	return SKBodyWithShapes(&s, n >= 2 ? 1 : 0, NO);
}

static SKPhysicsBody *SKEdges(const CGPoint *points, int n, BOOL loop)
{
	int count = loop ? n : n - 1;
	if (count <= 0)
		return SKBodyWithShapes(NULL, 0, YES);
	SKShape *shapes = malloc(sizeof(SKShape) * count);
	for (int i = 0; i < count; i++) {
		CGPoint segment[2] = { points[i], points[(i + 1) % n] };
		shapes[i] = SKPolygon(segment, 2);
	}
	SKPhysicsBody *body = SKBodyWithShapes(shapes, count, YES);
	free(shapes);
	return body;
}

+ (SKPhysicsBody *)bodyWithEdgeFromPoint:(CGPoint)p1 toPoint:(CGPoint)p2
{
	CGPoint p[2] = { p1, p2 };
	return SKEdges(p, 2, NO);
}

+ (SKPhysicsBody *)bodyWithEdgeChainFromPath:(CGPathRef)path
{
	CGPoint points[256];
	BOOL closed = NO;
	int n = path != NULL ? SKPathPoints(path, points, 256, &closed) : 0;
	return SKEdges(points, n, closed);
}

+ (SKPhysicsBody *)bodyWithEdgeLoopFromPath:(CGPathRef)path
{
	CGPoint points[256];
	int n = path != NULL ? SKPathPoints(path, points, 256, NULL) : 0;
	return SKEdges(points, n, YES);
}

+ (SKPhysicsBody *)bodyWithEdgeLoopFromRect:(CGRect)r
{
	CGPoint p[4] = { { CGRectGetMinX(r), CGRectGetMinY(r) }, { CGRectGetMaxX(r), CGRectGetMinY(r) },
		{ CGRectGetMaxX(r), CGRectGetMaxY(r) }, { CGRectGetMinX(r), CGRectGetMaxY(r) } };
	return SKEdges(p, 4, YES);
}

/* A texture's outline would be traced from its alpha; its rectangle stands in. */
+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture size:(CGSize)size
{
	return [self bodyWithRectangleOfSize:size];
}

+ (SKPhysicsBody *)bodyWithTexture:(SKTexture *)texture alphaThreshold:(float)alphaThreshold size:(CGSize)size
{
	return [self bodyWithRectangleOfSize:size];
}

+ (SKPhysicsBody *)bodyWithBodies:(NSArray<SKPhysicsBody *> *)bodies
{
	int count = 0;
	for (SKPhysicsBody *body in bodies)
		count += body->_shapeCount;
	SKShape *shapes = malloc(sizeof(SKShape) * MAX(count, 1));
	int at = 0;
	BOOL edge = bodies.count > 0;
	for (SKPhysicsBody *body in bodies) {
		memcpy(shapes + at, body->_shapes, sizeof(SKShape) * body->_shapeCount);
		at += body->_shapeCount;
		edge = edge && body->_edge;
	}
	SKPhysicsBody *body = SKBodyWithShapes(shapes, count, edge);
	free(shapes);
	return body;
}

- (void)sk_setNode:(SKNode *)node
{
	_node = node;
	_attachedXScale = node != nil && node->_xScale != 0 ? node->_xScale : 1;
	_attachedYScale = node != nil && node->_yScale != 0 ? node->_yScale : 1;
}

- (SKNode *)node { return _node; }
- (BOOL)isDynamic { return _dynamic; }
- (void)setDynamic:(BOOL)dynamic { _dynamic = dynamic && !_edge; }
- (BOOL)usesPreciseCollisionDetection { return _usesPreciseCollisionDetection; }
- (void)setUsesPreciseCollisionDetection:(BOOL)value { _usesPreciseCollisionDetection = value; }
- (BOOL)allowsRotation { return _allowsRotation; }
- (void)setAllowsRotation:(BOOL)value { _allowsRotation = value; }
- (BOOL)pinned { return _pinned; }
- (void)setPinned:(BOOL)value { _pinned = value; }
- (BOOL)isResting { return _resting; }
- (void)setResting:(BOOL)value { _resting = value; }
- (CGFloat)friction { return _friction; }
- (void)setFriction:(CGFloat)value { _friction = value; }
- (CGFloat)charge { return _charge; }
- (void)setCharge:(CGFloat)value { _charge = value; }
- (CGFloat)restitution { return _restitution; }
- (void)setRestitution:(CGFloat)value { _restitution = value; }
- (CGFloat)linearDamping { return _linearDamping; }
- (void)setLinearDamping:(CGFloat)value { _linearDamping = value; }
- (CGFloat)angularDamping { return _angularDamping; }
- (void)setAngularDamping:(CGFloat)value { _angularDamping = value; }
- (BOOL)affectedByGravity { return _affectedByGravity; }
- (void)setAffectedByGravity:(BOOL)value { _affectedByGravity = value; }
- (uint32_t)fieldBitMask { return _fieldBitMask; }
- (void)setFieldBitMask:(uint32_t)mask { _fieldBitMask = mask; }
- (uint32_t)categoryBitMask { return _categoryBitMask; }
- (void)setCategoryBitMask:(uint32_t)mask { _categoryBitMask = mask; }
- (uint32_t)collisionBitMask { return _collisionBitMask; }
- (void)setCollisionBitMask:(uint32_t)mask { _collisionBitMask = mask; }
- (uint32_t)contactTestBitMask { return _contactTestBitMask; }
- (void)setContactTestBitMask:(uint32_t)mask { _contactTestBitMask = mask; }
- (NSArray *)joints { return @[]; }
- (CGVector)velocity { return _velocity; }
- (void)setVelocity:(CGVector)velocity { _velocity = velocity; }
- (CGFloat)angularVelocity { return _angularVelocity; }
- (void)setAngularVelocity:(CGFloat)value { _angularVelocity = value; }

/* In square meters, as SpriteKit has it. */
- (CGFloat)area
{
	return _area / (SK_POINTS_PER_METER * SK_POINTS_PER_METER);
}

- (CGFloat)density { return _density; }

- (void)setDensity:(CGFloat)density
{
	_density = density;
	_massSet = NO;
}

- (CGFloat)mass
{
	return _massSet ? _mass : _density * [self area];
}

- (void)setMass:(CGFloat)mass
{
	_mass = mass;
	_massSet = YES;
	CGFloat area = [self area];
	if (area > 0)
		_density = mass / area;
}

- (CGFloat)sk_inverseMass
{
	CGFloat mass = [self mass];
	return _dynamic && !_pinned && mass > 0 ? 1 / mass : 0;
}

/* A newton-second changes a kilogram's velocity by a point a second,
   gravity's meters by 150 points. */
- (void)applyImpulse:(CGVector)impulse
{
	CGFloat inverse = [self sk_inverseMass];
	_velocity.dx += impulse.dx * inverse;
	_velocity.dy += impulse.dy * inverse;
}

- (void)applyImpulse:(CGVector)impulse atPoint:(CGPoint)point
{
	[self applyImpulse:impulse];
}

- (void)applyAngularImpulse:(CGFloat)impulse
{
	if (_allowsRotation && [self sk_inverseMass] > 0)
		_angularVelocity += impulse * [self sk_inverseMass];
}

- (void)applyForce:(CGVector)force
{
	_force.dx += force.dx;
	_force.dy += force.dy;
}

- (void)applyForce:(CGVector)force atPoint:(CGPoint)point
{
	[self applyForce:force];
}

- (void)applyTorque:(CGFloat)torque
{
	_torque += torque;
}

- (NSArray<SKPhysicsBody *> *)allContactedBodies
{
	SKScene *scene = [_node scene];
	return [[scene physicsWorld] sk_contactedBodies:self] ?: @[];
}

@end

#pragma mark Contacts

@implementation SKPhysicsContact {
@public
	SKPhysicsBody *_bodyA, *_bodyB;
	CGPoint _contactPoint;
	CGVector _contactNormal;
	CGFloat _collisionImpulse;
}
- (SKPhysicsBody *)bodyA { return _bodyA; }
- (SKPhysicsBody *)bodyB { return _bodyB; }
- (CGPoint)contactPoint { return _contactPoint; }
- (CGVector)contactNormal { return _contactNormal; }
- (CGFloat)collisionImpulse { return _collisionImpulse; }
@end

#pragma mark Geometry

static CGFloat SKDot(CGPoint a, CGPoint b) { return a.x * b.x + a.y * b.y; }
static CGPoint SKSub(CGPoint a, CGPoint b) { return CGPointMake(a.x - b.x, a.y - b.y); }

static SKShape SKTransformShape(const SKShape *s, CGAffineTransform t)
{
	SKShape out = *s;
	out.center = CGPointApplyAffineTransform(s->center, t);
	if (s->kind == SK_SHAPE_CIRCLE) {
		/* Scale circles by the transform's mean scale. */
		out.radius = s->radius * sqrt(fabs(t.a * t.d - t.b * t.c));
		return out;
	}
	for (int i = 0; i < s->n; i++)
		out.v[i] = CGPointApplyAffineTransform(s->v[i], t);
	/* A mirroring transform turns the winding round. */
	if (t.a * t.d - t.b * t.c < 0)
		for (int i = 0; i < out.n / 2; i++) {
			CGPoint tmp = out.v[i];
			out.v[i] = out.v[out.n - 1 - i];
			out.v[out.n - 1 - i] = tmp;
		}
	return out;
}

static void SKProject(const SKShape *s, CGPoint axis, CGFloat *lo, CGFloat *hi)
{
	if (s->kind == SK_SHAPE_CIRCLE) {
		CGFloat c = SKDot(s->center, axis);
		*lo = c - s->radius;
		*hi = c + s->radius;
		return;
	}
	*lo = *hi = SKDot(s->v[0], axis);
	for (int i = 1; i < s->n; i++) {
		CGFloat d = SKDot(s->v[i], axis);
		*lo = MIN(*lo, d);
		*hi = MAX(*hi, d);
	}
}

static CGPoint SKClosestOnSegment(CGPoint p, CGPoint a, CGPoint b)
{
	CGPoint ab = SKSub(b, a);
	CGFloat l = SKDot(ab, ab);
	CGFloat t = l > 0 ? SKDot(SKSub(p, a), ab) / l : 0;
	t = MAX(0, MIN(1, t));
	return CGPointMake(a.x + ab.x * t, a.y + ab.y * t);
}

static CGPoint SKNormalize(CGPoint v)
{
	CGFloat l = hypot(v.x, v.y);
	return l > 0 ? CGPointMake(v.x / l, v.y / l) : CGPointMake(0, 1);
}

/* Whether a and b overlap (by more than -slop); *normal points from a to b,
   *depth is how far they overlap, *point is about where. */
static BOOL SKCollide(const SKShape *a, const SKShape *b, CGFloat slop, CGPoint *normal, CGFloat *depth, CGPoint *point)
{
	if (a->kind == SK_SHAPE_CIRCLE && b->kind == SK_SHAPE_CIRCLE) {
		CGPoint d = SKSub(b->center, a->center);
		CGFloat dist = hypot(d.x, d.y), r = a->radius + b->radius;
		if (dist > r + slop)
			return NO;
		*normal = dist > 0 ? CGPointMake(d.x / dist, d.y / dist) : CGPointMake(0, 1);
		*depth = r - dist;
		*point = CGPointMake(a->center.x + normal->x * a->radius, a->center.y + normal->y * a->radius);
		return YES;
	}
	if (a->kind == SK_SHAPE_CIRCLE || b->kind == SK_SHAPE_CIRCLE) {
		BOOL swapped = b->kind == SK_SHAPE_CIRCLE;
		const SKShape *circle = swapped ? b : a, *polygon = swapped ? a : b;
		CGPoint c = circle->center;
		/* The nearest point of the outline, and whether the center is inside. */
		CGFloat best = INFINITY;
		CGPoint nearest = c;
		BOOL inside = polygon->n >= 3;
		for (int i = 0; i < (polygon->n >= 3 ? polygon->n : 1); i++) {
			CGPoint p0 = polygon->v[i], p1 = polygon->v[(i + 1) % polygon->n];
			CGPoint q = SKClosestOnSegment(c, p0, p1);
			CGFloat d = hypot(c.x - q.x, c.y - q.y);
			if (d < best) {
				best = d;
				nearest = q;
			}
			CGPoint edge = SKSub(p1, p0);
			if (edge.x * (c.y - p0.y) - edge.y * (c.x - p0.x) < 0)
				inside = NO;
		}
		if (!inside && best > circle->radius + slop)
			return NO;
		/* From the polygon to the circle. */
		CGPoint n = inside ? SKNormalize(SKSub(nearest, c)) : SKNormalize(SKSub(c, nearest));
		if (best == 0 && !inside)
			n = SKNormalize(SKSub(c, polygon->center));
		*depth = inside ? circle->radius + best : circle->radius - best;
		*point = nearest;
		*normal = swapped ? n : CGPointMake(-n.x, -n.y);
		return YES;
	}
	/* Separating axes: the edges' normals. */
	CGFloat least = INFINITY;
	CGPoint axis = CGPointZero;
	const SKShape *shapes[2] = { a, b };
	for (int s = 0; s < 2; s++) {
		const SKShape *shape = shapes[s];
		int edges = shape->n == 2 ? 1 : shape->n;
		for (int i = 0; i < edges; i++) {
			CGPoint e = SKSub(shape->v[(i + 1) % shape->n], shape->v[i]);
			CGPoint n = SKNormalize(CGPointMake(e.y, -e.x));
			CGFloat alo, ahi, blo, bhi;
			SKProject(a, n, &alo, &ahi);
			SKProject(b, n, &blo, &bhi);
			CGFloat overlap = MIN(ahi - blo, bhi - alo);
			if (overlap < -slop)
				return NO;
			if (overlap < least) {
				least = overlap;
				axis = n;
			}
		}
	}
	if (SKDot(SKSub(b->center, a->center), axis) < 0)
		axis = CGPointMake(-axis.x, -axis.y);
	*normal = axis;
	*depth = least;
	*point = CGPointMake((a->center.x + b->center.x) / 2, (a->center.y + b->center.y) / 2);
	return YES;
}

#pragma mark The world

typedef struct {
	SKPhysicsBody *__unsafe_unretained body;
	SKNode *__unsafe_unretained node;
	SKShape *shapes; /* in the scene */
	CGRect bounds;
	CGFloat inverseMass;
} SKBodyState;

@implementation SKPhysicsWorld {
	CGVector _gravity;
	CGFloat _speed;
	__weak id<SKPhysicsContactDelegate> _contactDelegate;
	__weak SKScene *_scene;
	/* "%p %p" of the body pairs in contact, lower address first. */
	NSMutableSet<NSString *> *_contacts;
	NSMapTable *_pairs;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_gravity = CGVectorMake(0, -9.8);
		_speed = 1;
		_contacts = [NSMutableSet set];
		_pairs = [NSMapTable strongToStrongObjectsMapTable];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	self = [self init];
	if (self == nil)
		return nil;
	id gravity = [coder decodeObjectForKey:@"gravity"];
	if ([gravity isKindOfClass:[NSString class]]) {
		CGPoint g = CGPointFromString(gravity);
		_gravity = CGVectorMake(g.x, g.y);
	} else if ([gravity isKindOfClass:[NSValue class]]) {
		CGPoint g = [gravity CGPointValue];
		_gravity = CGVectorMake(g.x, g.y);
	}
	if ([coder containsValueForKey:@"speedMultiplier"])
		_speed = SKDecodeNumber(coder, @"speedMultiplier", 0);
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:NSStringFromCGPoint(CGPointMake(_gravity.dx, _gravity.dy)) forKey:@"gravity"];
	[coder encodeDouble:_speed forKey:@"speedMultiplier"];
}

- (CGVector)gravity { return _gravity; }
- (void)setGravity:(CGVector)gravity { _gravity = gravity; }
- (CGFloat)speed { return _speed; }
- (void)setSpeed:(CGFloat)speed { _speed = speed; }
- (id<SKPhysicsContactDelegate>)contactDelegate { return _contactDelegate; }
- (void)setContactDelegate:(id<SKPhysicsContactDelegate>)delegate { _contactDelegate = delegate; }
- (void)addJoint:(id)joint {}
- (void)removeJoint:(id)joint {}
- (void)removeAllJoints {}

static void SKCollectBodies(SKNode *node, NSMutableArray *bodies)
{
	if (node->_physicsBody != nil)
		[bodies addObject:node->_physicsBody];
	for (SKNode *child in node->_children)
		SKCollectBodies(child, bodies);
}

static NSString *SKPairKey(SKPhysicsBody *a, SKPhysicsBody *b)
{
	return (__bridge void *)a < (__bridge void *)b ? [NSString stringWithFormat:@"%p %p", a, b] : [NSString stringWithFormat:@"%p %p", b, a];
}

- (NSArray<SKPhysicsBody *> *)sk_contactedBodies:(SKPhysicsBody *)body
{
	NSMutableArray *found = [NSMutableArray array];
	for (NSString *key in _contacts) {
		NSArray *pair = [_pairs objectForKey:key];
		if (pair.count == 2 && (pair[0] == body || pair[1] == body))
			[found addObject:pair[0] == body ? pair[1] : pair[0]];
	}
	return found;
}

static void SKPlaceShapes(SKBodyState *state)
{
	SKPhysicsBody *body = state->body;
	CGAffineTransform t = CGAffineTransformConcat(
		CGAffineTransformMakeScale(1 / body->_attachedXScale, 1 / body->_attachedYScale), [state->node sk_sceneTransform]);
	CGRect bounds = CGRectNull;
	for (int i = 0; i < body->_shapeCount; i++) {
		SKShape *s = &state->shapes[i];
		*s = SKTransformShape(&body->_shapes[i], t);
		CGRect box;
		if (s->kind == SK_SHAPE_CIRCLE)
			box = CGRectMake(s->center.x - s->radius, s->center.y - s->radius, 2 * s->radius, 2 * s->radius);
		else {
			CGFloat x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
			for (int k = 0; k < s->n; k++) {
				x0 = MIN(x0, s->v[k].x);
				y0 = MIN(y0, s->v[k].y);
				x1 = MAX(x1, s->v[k].x);
				y1 = MAX(y1, s->v[k].y);
			}
			box = CGRectMake(x0, y0, x1 - x0, y1 - y0);
		}
		bounds = CGRectIsNull(bounds) ? box : CGRectUnion(bounds, box);
	}
	state->bounds = bounds;
}

/* Moves the body's node by d, in scene coordinates. */
static void SKMoveNode(SKBodyState *state, CGVector d)
{
	SKNode *node = state->node, *parent = node->_parent;
	if (d.dx == 0 && d.dy == 0)
		return;
	CGAffineTransform inverse = CGAffineTransformInvert([parent sk_sceneTransform]);
	CGFloat dx = d.dx * inverse.a + d.dy * inverse.c, dy = d.dx * inverse.b + d.dy * inverse.d;
	node.position = CGPointMake(node->_position.x + dx, node->_position.y + dy);
	for (int i = 0; i < state->body->_shapeCount; i++) {
		SKShape *s = &state->shapes[i];
		s->center.x += d.dx;
		s->center.y += d.dy;
		for (int k = 0; k < s->n; k++) {
			s->v[k].x += d.dx;
			s->v[k].y += d.dy;
		}
	}
	state->bounds = CGRectOffset(state->bounds, d.dx, d.dy);
}

/* The deepest overlap of two bodies' shapes. */
static BOOL SKBodiesTouch(SKBodyState *a, SKBodyState *b, CGFloat slop, CGPoint *normal, CGFloat *depth, CGPoint *point)
{
	if (!CGRectIntersectsRect(CGRectInset(a->bounds, -slop, -slop), b->bounds))
		return NO;
	BOOL touching = NO;
	*depth = -INFINITY;
	for (int i = 0; i < a->body->_shapeCount; i++)
		for (int k = 0; k < b->body->_shapeCount; k++) {
			CGPoint n, p;
			CGFloat d;
			if (SKCollide(&a->shapes[i], &b->shapes[k], slop, &n, &d, &p) && d > *depth) {
				touching = YES;
				*depth = d;
				*normal = n;
				*point = p;
			}
		}
	return touching;
}

- (void)sk_simulate:(NSTimeInterval)dt scene:(SKScene *)scene
{
	_scene = scene;
	dt *= _speed;
	NSMutableArray<SKPhysicsBody *> *bodies = [NSMutableArray array];
	SKCollectBodies(scene, bodies);
	NSUInteger count = bodies.count;
	if (count == 0) {
		[_contacts removeAllObjects];
		[_pairs removeAllObjects];
		return;
	}

	/* Forces, gravity and damping, then motion. */
	CGFloat g = SK_POINTS_PER_METER;
	for (SKPhysicsBody *body in bodies) {
		SKNode *node = body->_node;
		if (node == nil || !body->_dynamic || body->_pinned || dt <= 0) {
			body->_force = CGVectorMake(0, 0);
			body->_torque = 0;
			continue;
		}
		CGFloat inverse = [body sk_inverseMass];
		if (body->_affectedByGravity) {
			body->_velocity.dx += _gravity.dx * g * dt;
			body->_velocity.dy += _gravity.dy * g * dt;
		}
		body->_velocity.dx += body->_force.dx * g * inverse * dt;
		body->_velocity.dy += body->_force.dy * g * inverse * dt;
		body->_force = CGVectorMake(0, 0);
		if (body->_allowsRotation)
			body->_angularVelocity += body->_torque * inverse * dt;
		body->_torque = 0;
		CGFloat damping = 1 / (1 + dt * body->_linearDamping);
		body->_velocity.dx *= damping;
		body->_velocity.dy *= damping;
		body->_angularVelocity *= 1 / (1 + dt * body->_angularDamping);
	}

	SKBodyState *states = calloc(count, sizeof(SKBodyState));
	for (NSUInteger i = 0; i < count; i++) {
		SKPhysicsBody *body = bodies[i];
		states[i].body = body;
		states[i].node = body->_node;
		states[i].shapes = malloc(sizeof(SKShape) * MAX(body->_shapeCount, 1));
		states[i].inverseMass = [body sk_inverseMass];
		SKPlaceShapes(&states[i]);
		if (states[i].inverseMass > 0 && dt > 0) {
			SKMoveNode(&states[i], CGVectorMake(body->_velocity.dx * dt, body->_velocity.dy * dt));
			if (body->_allowsRotation && body->_angularVelocity != 0) {
				states[i].node.zRotation = states[i].node->_zRotation + body->_angularVelocity * dt;
				SKPlaceShapes(&states[i]);
			}
		}
	}

	/* Collisions, a few passes, and the contacts as they are now. */
	NSMutableSet<NSString *> *contacts = [NSMutableSet set];
	NSMutableArray<SKPhysicsContact *> *began = [NSMutableArray array];
	for (int pass = 0; pass < 4; pass++) {
		for (NSUInteger i = 0; i < count; i++) {
			for (NSUInteger k = i + 1; k < count; k++) {
				SKBodyState *a = &states[i], *b = &states[k];
				/* No retains in the n-squared loop: the states hold the bodies. */
				SKPhysicsBody *__unsafe_unretained A = a->body;
				SKPhysicsBody *__unsafe_unretained B = b->body;
				if (a->node == nil || b->node == nil)
					continue;
				BOOL aCollides = (A->_collisionBitMask & B->_categoryBitMask) != 0;
				BOOL bCollides = (B->_collisionBitMask & A->_categoryBitMask) != 0;
				BOOL contact = pass == 0 && ((A->_contactTestBitMask & B->_categoryBitMask) != 0 || (B->_contactTestBitMask & A->_categoryBitMask) != 0)
					&& (A->_dynamic || B->_dynamic);
				CGFloat wa = aCollides ? a->inverseMass : 0, wb = bCollides ? b->inverseMass : 0;
				if (!contact && wa + wb == 0)
					continue;
				CGPoint n, p;
				CGFloat depth;
				if (!SKBodiesTouch(a, b, contact ? 0.5 : 0, &n, &depth, &p))
					continue;
				if (contact) {
					NSString *key = SKPairKey(A, B);
					[contacts addObject:key];
					if (![_contacts containsObject:key]) {
						SKPhysicsContact *c = [SKPhysicsContact new];
						c->_bodyA = A;
						c->_bodyB = B;
						c->_contactPoint = p;
						c->_contactNormal = CGVectorMake(n.x, n.y);
						CGFloat closing = (B->_velocity.dx - A->_velocity.dx) * n.x + (B->_velocity.dy - A->_velocity.dy) * n.y;
						CGFloat mass = (a->inverseMass + b->inverseMass) > 0 ? 1 / (a->inverseMass + b->inverseMass) : 0;
						c->_collisionImpulse = fabs(closing) * mass;
						[began addObject:c];
						[_pairs setObject:@[ A, B ] forKey:key];
					}
				}
				if (wa + wb == 0 || depth <= 0)
					continue;
				/* Push apart, in proportion to the inverse masses. */
				SKMoveNode(a, CGVectorMake(-n.x * depth * wa / (wa + wb), -n.y * depth * wa / (wa + wb)));
				SKMoveNode(b, CGVectorMake(n.x * depth * wb / (wa + wb), n.y * depth * wb / (wa + wb)));
				/* And stop them closing, bouncing by the restitution. */
				CGFloat closing = (B->_velocity.dx - A->_velocity.dx) * n.x + (B->_velocity.dy - A->_velocity.dy) * n.y;
				if (closing >= 0)
					continue;
				CGFloat e = MAX(A->_restitution, B->_restitution);
				/* Slow impacts don't bounce. */
				if (fabs(closing) < 30)
					e = 0;
				CGFloat j = -(1 + e) * closing / (wa + wb);
				A->_velocity.dx -= j * wa * n.x;
				A->_velocity.dy -= j * wa * n.y;
				B->_velocity.dx += j * wb * n.x;
				B->_velocity.dy += j * wb * n.y;
				/* Friction along the surface. */
				CGPoint tangent = CGPointMake(-n.y, n.x);
				CGFloat sliding = (B->_velocity.dx - A->_velocity.dx) * tangent.x + (B->_velocity.dy - A->_velocity.dy) * tangent.y;
				CGFloat mu = sqrt(A->_friction * B->_friction);
				CGFloat jt = MAX(-mu * j, MIN(mu * j, -sliding / (wa + wb)));
				A->_velocity.dx -= jt * wa * tangent.x;
				A->_velocity.dy -= jt * wa * tangent.y;
				B->_velocity.dx += jt * wb * tangent.x;
				B->_velocity.dy += jt * wb * tangent.y;
			}
		}
	}

	NSMutableArray<SKPhysicsContact *> *ended = [NSMutableArray array];
	for (NSString *key in _contacts) {
		if ([contacts containsObject:key])
			continue;
		NSArray *pair = [_pairs objectForKey:key];
		if (pair.count == 2) {
			SKPhysicsContact *c = [SKPhysicsContact new];
			c->_bodyA = pair[0];
			c->_bodyB = pair[1];
			[ended addObject:c];
		}
		[_pairs removeObjectForKey:key];
	}
	_contacts = contacts;
	for (NSUInteger i = 0; i < count; i++)
		free(states[i].shapes);
	free(states);

	id<SKPhysicsContactDelegate> delegate = _contactDelegate;
	if ([delegate respondsToSelector:@selector(didBeginContact:)])
		for (SKPhysicsContact *c in began)
			[delegate didBeginContact:c];
	if ([delegate respondsToSelector:@selector(didEndContact:)])
		for (SKPhysicsContact *c in ended)
			[delegate didEndContact:c];
}

- (SKPhysicsBody *)bodyAtPoint:(CGPoint)point
{
	__block SKPhysicsBody *found = nil;
	[self enumerateBodiesAtPoint:point usingBlock:^(SKPhysicsBody *body, BOOL *stop) {
		found = body;
		*stop = YES;
	}];
	return found;
}

- (SKPhysicsBody *)bodyInRect:(CGRect)rect
{
	__block SKPhysicsBody *found = nil;
	[self enumerateBodiesInRect:rect usingBlock:^(SKPhysicsBody *body, BOOL *stop) {
		found = body;
		*stop = YES;
	}];
	return found;
}

- (void)enumerateBodiesAtPoint:(CGPoint)point usingBlock:(void (^)(SKPhysicsBody *body, BOOL *stop))block
{
	[self enumerateBodiesInRect:CGRectMake(point.x, point.y, 0, 0) usingBlock:block];
}

- (void)enumerateBodiesInRect:(CGRect)rect usingBlock:(void (^)(SKPhysicsBody *body, BOOL *stop))block
{
	SKScene *scene = [self sk_scene];
	if (scene == nil || block == nil)
		return;
	NSMutableArray<SKPhysicsBody *> *bodies = [NSMutableArray array];
	SKCollectBodies(scene, bodies);
	SKShape probe = SKRectShape(rect);
	for (SKPhysicsBody *body in bodies) {
		SKBodyState state = { body, body->_node, malloc(sizeof(SKShape) * MAX(body->_shapeCount, 1)) };
		SKPlaceShapes(&state);
		BOOL hit = NO;
		for (int i = 0; i < body->_shapeCount && !hit; i++) {
			CGPoint n, p;
			CGFloat d;
			hit = SKCollide(&probe, &state.shapes[i], 0, &n, &d, &p);
		}
		free(state.shapes);
		BOOL stop = NO;
		if (hit)
			block(body, &stop);
		if (stop)
			break;
	}
}

/* The scene whose world this is. */
- (SKScene *)sk_scene
{
	return _scene;
}

@end
