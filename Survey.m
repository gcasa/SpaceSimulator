#import <Cocoa/Cocoa.h>
#include <math.h>

typedef struct { double x, y, z; } Vector;
typedef struct {
    NSString *name;
    double ra, dec, lightYears;
} Star;

static const Star stars[] = {
    { @"Sol", 0, 0, 0 },
    { @"Alpha Centauri AB", 219.90, -60.83, 4.37 },
    { @"Proxima Centauri", 217.43, -62.68, 4.25 },
    { @"Barnard's Star", 269.45, 4.69, 5.96 }
};
enum { Sol, Alpha, Proxima, Barnard, StarCount };
enum { Arrival, Evidence, ProbeReturned, OnScreen, Complete };

static Vector Position(int index)
{
    Star star = stars[index];
    double ra = star.ra * M_PI / 180, dec = star.dec * M_PI / 180;
    Vector position = {star.lightYears * cos(dec) * cos(ra),
                       star.lightYears * cos(dec) * sin(ra),
                       star.lightYears * sin(dec)};
    return position;
}

static Vector Difference(Vector a, Vector b)
{
    Vector result = {a.x-b.x, a.y-b.y, a.z-b.z};
    return result;
}

static double Length(Vector a)
{
    return sqrt(a.x*a.x + a.y*a.y + a.z*a.z);
}

static void Label(NSString *label, CGFloat x, CGFloat y, CGFloat size, NSColor *color)
{
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular],
        NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
    [label drawAtPoint:NSMakePoint(x,y) withAttributes:attributes];
}

static void Line(NSPoint a, NSPoint b)
{
    [NSBezierPath strokeLineFromPoint:a toPoint:b];
}

static void Disc(NSPoint p, CGFloat r)
{
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(p.x-r,p.y-r,2*r,2*r)] fill];
}

@interface SurveyView : NSView {
    BOOL chart;
    int current, destination, phase, scans;
    double yaw, pitch;
    Vector ship;
    NSString *status;
}
- (void)report:(NSString *)message;
- (void)reset;
- (NSPoint)project:(Vector)v;
@end

@implementation SurveyView
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) [self reset];
    return self;
}

- (void)dealloc
{
    [status release];
    [super dealloc];
}

- (void)report:(NSString *)message
{
    NSString *next = [message copy];
    [status release];
    status = next;
    [self setNeedsDisplay:YES];
}

- (void)reset
{
    Vector origin = {0,0,0};
    ship = origin;
    chart = YES;
    current = Sol;
    destination = Proxima;
    phase = Arrival;
    scans = 0;
    yaw = 0.3;
    pitch = -0.35;
    [self report:@"Starfleet orders: investigate a repeating signal at Proxima Centauri."];
}

- (BOOL)acceptsFirstResponder { return YES; }

- (NSPoint)project:(Vector)v
{
    double x = cos(yaw)*v.x - sin(yaw)*v.y;
    double z = sin(yaw)*v.x + cos(yaw)*v.y;
    double y = cos(pitch)*v.z - sin(pitch)*z;
    double depth = sin(pitch)*v.z + cos(pitch)*z;
    NSRect bounds = [self bounds];
    double scale = MIN(bounds.size.width, bounds.size.height) / 13.5;
    double perspective = 18 / MAX(4, 18 + depth);
    return NSMakePoint(NSMidX(bounds) + x*scale*perspective,
                       NSMidY(bounds) + y*scale*perspective);
}

- (void)drawRect:(NSRect)dirty
{
    NSRect bounds = [self bounds];
    NSColor *cyan = [NSColor colorWithCalibratedRed:.38 green:.86 blue:1 alpha:1];
    NSColor *orange = [NSColor colorWithCalibratedRed:1 green:.68 blue:.35 alpha:1];
    NSColor *dim = [NSColor colorWithCalibratedRed:.23 green:.40 blue:.53 alpha:1];
    [[NSColor colorWithCalibratedRed:.025 green:.045 blue:.085 alpha:1] set];
    NSRectFill(dirty);

    [NSGraphicsContext saveGraphicsState];
    NSRectClip(NSMakeRect(0,120,bounds.size.width,bounds.size.height-218));
    if (chart) {
        int i;
        [dim set];
        for (i = -7; i <= 7; i++) {
            Vector a = {i,-7,0}, b = {i,7,0}, c = {-7,i,0}, d = {7,i,0};
            Line([self project:a], [self project:b]);
            Line([self project:c], [self project:d]);
        }
        [orange set];
        Line([self project:Position(current)], [self project:Position(destination)]);
        for (i = 0; i < StarCount; i++) {
            NSPoint p = [self project:Position(i)];
            NSColor *color = i == destination ? orange : cyan;
            [color set];
            Disc(p, i == destination ? 6 : 3);
            CGFloat lift = i == Alpha ? -25 : 10;
            Line(p, NSMakePoint(p.x+12,p.y+lift+6));
            Label(stars[i].name,p.x+16,p.y+lift,13,color);
        }
    } else {
        int i;
        for (i = 0; i < 120; i++) {
            [dim set];
            Disc(NSMakePoint((i*137 % 997)*bounds.size.width/997,
                             (i*193 % 991)*bounds.size.height/991), i%9 ? 1 : 1.8);
        }

        Vector star = {-3,3,1}, waypoint = {2,2,1};
        NSPoint starPoint = [self project:Difference(star,ship)];
        for (i = 22; i > 0; i--) {
            double intensity = 1 - i/23.0;
            [[NSColor colorWithCalibratedRed:.6+.4*intensity
                                       green:.13+.75*intensity blue:.06+.64*intensity
                                       alpha:.15+.75*intensity] set];
            Disc(starPoint, 4*i);
        }
        if (current == Proxima) {
            NSPoint point = [self project:Difference(waypoint,ship)];
            [cyan set];
            if (phase >= OnScreen) {
                NSBezierPath *pod = [NSBezierPath bezierPath];
                [pod moveToPoint:NSMakePoint(point.x,point.y+24)];
                [pod lineToPoint:NSMakePoint(point.x+33,point.y)];
                [pod lineToPoint:NSMakePoint(point.x,point.y-24)];
                [pod lineToPoint:NSMakePoint(point.x-33,point.y)];
                [pod closePath];
                [pod fill];
                [[NSColor whiteColor] set];
                Disc(point,6);
            } else {
                [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(point.x-9,point.y-9,18,18)] stroke];
            }
            Label(phase >= OnScreen ? @"DISTRESS POD" : @"SURVEY WAYPOINT",
                  point.x+15,point.y+25,12,cyan);
            [dim set];
            Line(NSMakePoint(NSMidX(bounds)-8,NSMidY(bounds)),NSMakePoint(NSMidX(bounds)+8,NSMidY(bounds)));
            Line(NSMakePoint(NSMidX(bounds),NSMidY(bounds)-8),NSMakePoint(NSMidX(bounds),NSMidY(bounds)+8));
        }
    }
    [NSGraphicsContext restoreGraphicsState];

    CGFloat top = bounds.size.height;
    Label(@"STARFLEET SURVEY   /   USS MERIDIAN",24,top-43,23,orange);
    if (chart) {
        Label([NSString stringWithFormat:@"%@  →  %@    %.2f ly",
            stars[current].name, stars[destination].name,
            Length(Difference(Position(current),Position(destination)))],24,top-72,15,cyan);
        Label(@"CATALOG ASTROMETRY  /  HELIOCENTRIC LIGHT-YEARS",24,top-94,12,dim);
        Label(@"1 Sol   2 Alpha Centauri AB   3 Proxima   4 Barnard   Return Warp   Arrows Rotate",24,42,13,cyan);
    } else {
        Label([NSString stringWithFormat:@"%@  /  LOCAL VIEW",stars[current].name],24,top-72,15,cyan);
        if (current == Proxima) {
            Vector waypoint = {2,2,1};
            Vector offset = Difference(waypoint,ship);
            Label([NSString stringWithFormat:@"FICTIONAL SURVEY  /  WAYPOINT OFFSET  X %+.1f  Y %+.1f  Z %+.1f",
                   offset.x,offset.y,offset.z],24,top-94,12,dim);
            if (scans) {
                int sample;
                [cyan set];
                for (sample = 0; sample < 28; sample++) {
                    double height = (scans & 1) && sample % 7 == 3 ? 27 : 3 + (sample*11 % 6);
                    Line(NSMakePoint(28+5*sample,121),NSMakePoint(28+5*sample,121+height));
                }
            }
        }
        Label(@"A/D X   Q/E Y   W/S Z   R Radio   I Infrared   P Probe   O On Screen",24,42,13,cyan);
    }
    Label(status,24,77,13,[NSColor whiteColor]);
    Label(@"Tab Switch View   •   N Restart Episode",24,18,12,dim);
}

- (void)keyDown:(NSEvent *)event
{
    NSString *keys = [[event charactersIgnoringModifiers] lowercaseString];
    if (![keys length]) return;
    unichar key = [keys characterAtIndex:0];
    if (key == 'n') {
        [self reset];
        return;
    }
    if (key == '\t') {
        chart = !chart;
    } else if (chart) {
        switch (key) {
            case '1': case '2': case '3': case '4': destination = key-'1'; break;
            case NSLeftArrowFunctionKey: yaw -= .10; break;
            case NSRightArrowFunctionKey: yaw += .10; break;
            case NSUpArrowFunctionKey: pitch += .10; break;
            case NSDownArrowFunctionKey: pitch -= .10; break;
            case '\r': case NSEnterCharacter: {
                Vector origin = {0,0,0};
                ship = origin;
                current = destination;
                chart = NO;
                if (current != Proxima) [self report:@"Helm: standard survey complete. Proxima remains available via the chart."];
                else if (phase == Complete) [self report:@"Captain's log: the distress signal investigation is closed."];
                else if (phase == OnScreen) [self report:@"Captain, your orders?  1 Hail   2 Approach quietly   3 Keep observing."];
                else if (phase == ProbeReturned) [self report:@"Probe telemetry received. Press O to put the source on screen."];
                else [self report:@"Helm: zero the waypoint offsets, then take radio and infrared readings."];
                break;
            }
            default: return;
        }
    } else {
        Vector waypoint = {2,2,1};
        switch (key) {
            case 'a': ship.x -= .5; break;
            case 'd': ship.x += .5; break;
            case 'q': ship.y -= .5; break;
            case 'e': ship.y += .5; break;
            case 's': ship.z -= .5; break;
            case 'w': ship.z += .5; break;
            default:
                if (current != Proxima || phase == Complete) return;
                switch (key) {
                    case 'r': case 'i':
                        if (phase >= ProbeReturned) return;
                        if (Length(Difference(waypoint,ship)) > .75) {
                            [self report:@"Sensors: move within 0.75 flight units of the waypoint."];
                            break;
                        }
                        scans |= key == 'r' ? 1 : 2;
                        if (scans == 3) {
                            phase = Evidence;
                            [self report:@"The pulses repeat, and their source is cooler than a flare. Press P."];
                        } else if (key == 'r') {
                            [self report:@"Radio: a regular pulse train. Compare it with an infrared scan."];
                        } else {
                            [self report:@"Infrared: a compact, cool source. Compare it with a radio scan."];
                        }
                        break;
                    case 'p':
                        if (phase != Evidence) return;
                        if (Length(Difference(waypoint,ship)) > .75) {
                            [self report:@"Probe range exceeded. Return to the marked waypoint."];
                            break;
                        }
                        phase = ProbeReturned;
                        [self report:@"Probe telemetry: there is a hull behind the signal. Press O."];
                        break;
                    case 'o':
                        if (phase != ProbeReturned) return;
                        phase = OnScreen;
                        [self report:@"Captain, your orders?  1 Hail   2 Approach quietly   3 Keep observing."];
                        break;
                    case '1': case '2': case '3':
                        if (phase != OnScreen) return;
                        phase = Complete;
                        if (key == '1') [self report:@"Captain's log: the survivors answered our hail and accepted evacuation."];
                        if (key == '2') [self report:@"Captain's log: we docked silently and brought the survivors aboard."];
                        if (key == '3') [self report:@"Captain's log: we logged the beacon and deployed a relay to monitor it."];
                        break;
                    default: return;
                }
                break;
        }
    }
    [self setNeedsDisplay:YES];
}
@end

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Starfleet Survey"];
    [appMenu addItemWithTitle:@"Quit Starfleet Survey" action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu];
    [menu addItem:appItem];
    [app setMainMenu:menu];
    [appMenu release];
    [appItem release];
    [menu release];

    NSRect frame = NSMakeRect(0,0,1000,700);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                  NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setContentMinSize:NSMakeSize(860,520)];
    [window setTitle:@"Starfleet Survey — The Proxima Signal"];
    SurveyView *view = [[SurveyView alloc] initWithFrame:frame];
    [window setContentView:view];
    [window makeFirstResponder:view];
    [view release];
    [window center];
    [window makeKeyAndOrderFront:nil];
    [app activate];
    [app run];
    [window release];
    [pool drain];
    return 0;
}
