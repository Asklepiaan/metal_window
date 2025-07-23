#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include "quartz_window.h"
#include <string.h>

struct PlushImage {
	int width, height;
	unsigned char* pixels;
};

@interface QuartzImageView : NSView {
	CGImageRef _cgImage;
	unsigned char _clearColor[3];
	BOOL _needsClear;
	int _mouseX;
	int _mouseY;
	BOOL _mouseButtonLeft;
	BOOL _mouseButtonRight;
	BOOL _mouseButtonMiddle;
}

@property (assign) int mouseX;
@property (assign) int mouseY;
@property (assign) BOOL mouseButtonLeft;
@property (assign) BOOL mouseButtonRight;
@property (assign) BOOL mouseButtonMiddle;

- (void)updateImage:(const struct PlushImage*)image;
- (void)setClearColorRed:(unsigned char)r green:(unsigned char)g blue:(unsigned char)b;
- (void)updateMousePosition:(NSEvent*)event;
@end

@interface QuartzWindow : NSObject {
	NSWindow* _window;
	QuartzImageView* _contentView;
	BOOL _shouldClose;
	int _width;
	int _height;
}

@property (retain) NSWindow* window;
@property (retain) QuartzImageView* contentView;
@property (assign) BOOL shouldClose;
@property (assign) int width;
@property (assign) int height;

- (instancetype)initWithTitle:(NSString*)title width:(int)width height:(int)height;
@end

@implementation QuartzImageView

@synthesize mouseX = _mouseX;
@synthesize mouseY = _mouseY;
@synthesize mouseButtonLeft = _mouseButtonLeft;
@synthesize mouseButtonRight = _mouseButtonRight;
@synthesize mouseButtonMiddle = _mouseButtonMiddle;

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		_cgImage = NULL;
		_needsClear = NO;
		_clearColor[0] = 0;
		_clearColor[1] = 0;
		_clearColor[2] = 0;
		_mouseX = 0;
		_mouseY = 0;
		_mouseButtonLeft = NO;
		_mouseButtonRight = NO;
		_mouseButtonMiddle = NO;
	}
	return self;
}

- (void)dealloc {
	if (_cgImage) CGImageRelease(_cgImage);
	[super dealloc];
}

- (void)updateImage:(const struct PlushImage*)image {
	if (!image || !image->pixels || image->width <= 0 || image->height <= 0) return;

	if (_cgImage) CGImageRelease(_cgImage);
	
	CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, image->pixels, 
															 image->width * image->height * 4, NULL);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	_cgImage = CGImageCreate(image->width, image->height, 8, 32, image->width * 4, colorSpace,
							 kCGBitmapByteOrderDefault | kCGImageAlphaLast,
							 provider, NULL, NO, kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	CGDataProviderRelease(provider);

	_needsClear = NO;
	[self setNeedsDisplay:YES];
}

- (void)setClearColorRed:(unsigned char)r green:(unsigned char)g blue:(unsigned char)b {
	_clearColor[0] = r;
	_clearColor[1] = g;
	_clearColor[2] = b;
	_needsClear = YES;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	
	if (_needsClear) {
		CGContextSetRGBFillColor(ctx, _clearColor[0]/255.0, _clearColor[1]/255.0, 
								_clearColor[2]/255.0, 1.0);
		CGContextFillRect(ctx, NSRectToCGRect(self.bounds));
	}

	if (_cgImage) {
		CGContextSaveGState(ctx);
		
		CGRect imageRect = CGRectMake(0, 0, CGImageGetWidth(_cgImage), CGImageGetHeight(_cgImage));
		CGContextDrawImage(ctx, imageRect, _cgImage);
		CGContextRestoreGState(ctx);
	}
}

- (void)mouseDown:(NSEvent*)event      { _mouseButtonLeft = YES; }
- (void)mouseUp:(NSEvent*)event        { _mouseButtonLeft = NO; }
- (void)rightMouseDown:(NSEvent*)event { _mouseButtonRight = YES; }
- (void)rightMouseUp:(NSEvent*)event   { _mouseButtonRight = NO; }

- (void)otherMouseDown:(NSEvent*)event {
	if ([event buttonNumber] == 2) _mouseButtonMiddle = YES;
}

- (void)otherMouseUp:(NSEvent*)event {
	if ([event buttonNumber] == 2) _mouseButtonMiddle = NO;
}

- (void)mouseMoved:(NSEvent*)event        { [self updateMousePosition:event]; }
- (void)mouseDragged:(NSEvent*)event      { [self updateMousePosition:event]; }
- (void)rightMouseDragged:(NSEvent*)event { [self updateMousePosition:event]; }
- (void)otherMouseDragged:(NSEvent*)event { [self updateMousePosition:event]; }

- (void)updateMousePosition:(NSEvent*)event {
	NSPoint location = [event locationInWindow];
	location = [self convertPoint:location fromView:nil];
	_mouseX = (int)location.x;
	_mouseY = (int)(self.bounds.size.height - location.y);
}

@end

@implementation QuartzWindow

@synthesize window = _window;
@synthesize contentView = _contentView;
@synthesize shouldClose = _shouldClose;
@synthesize width = _width;
@synthesize height = _height;

- (instancetype)initWithTitle:(NSString*)title width:(int)width height:(int)height {
	self = [super init];
	if (self) {
		_width = width;
		_height = height;
		_shouldClose = NO;

		NSRect rect = NSMakeRect(0, 0, width, height);
		_window = [[NSWindow alloc] initWithContentRect:rect
											  styleMask:NSTitledWindowMask | NSClosableWindowMask
												backing:NSBackingStoreBuffered
												  defer:NO];
		[_window setTitle:title];
		[_window setDelegate:self];
		[_window setContentMinSize:rect.size];
		[_window setContentMaxSize:rect.size];
		[_window setAcceptsMouseMovedEvents:YES];
		
		_contentView = [[QuartzImageView alloc] initWithFrame:rect];
		[_window setContentView:_contentView];
		[_contentView release];

		[_window center];
		[_window makeKeyAndOrderFront:nil];
	}
	return self;
}

- (void)dealloc {
	[_window release];
	[super dealloc];
}

- (BOOL)windowShouldClose:(id)sender {
	_shouldClose = YES;
	return YES;
}

@end

static void ensureApplication() {
	static BOOL initialized = NO;
	if (!initialized) {
		[NSApplication sharedApplication];
		if ([NSApp respondsToSelector:@selector(setActivationPolicy:)]) {
			[NSApp setActivationPolicy:0];
		}
		[NSApp activateIgnoringOtherApps:YES];
		[NSApp finishLaunching];
		initialized = YES;
	}
}

QuartzWindowHandle createWindow(const char* title, int width, int height) {
	ensureApplication();
	NSString* nsTitle = [NSString stringWithUTF8String:title];
	QuartzWindow* qw = [[QuartzWindow alloc] initWithTitle:nsTitle width:width height:height];
	return (QuartzWindowHandle)qw;
}

void closeWindow(QuartzWindowHandle handle) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	[qw.window close];
}

void destroyWindow(QuartzWindowHandle handle) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	[qw release];
}

const char* getWindowTitle(QuartzWindowHandle handle) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	return strdup([qw.window.title UTF8String]);
}

void getWindowSize(QuartzWindowHandle handle, int* width, int* height) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	if (width) *width = qw.width;
	if (height) *height = qw.height;
}

void setWindowSize(QuartzWindowHandle handle, int width, int height) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	qw.width = width;
	qw.height = height;
	[qw.window setContentSize:NSMakeSize(width, height)];
	[qw.contentView setFrameSize:NSMakeSize(width, height)];
}

void setWindowTitle(QuartzWindowHandle handle, const char* title) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	qw.window.title = [NSString stringWithUTF8String:title];
}

void pushImage(QuartzWindowHandle handle, const struct PlushImage* image) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	[qw.contentView updateImage:image];
}

void updateWindow(QuartzWindowHandle handle) {
	NSEvent* event;
	while ((event = [NSApp nextEventMatchingMask:NSAnyEventMask
									  untilDate:[NSDate distantPast]
										 inMode:NSDefaultRunLoopMode
										dequeue:YES])) {
		[NSApp sendEvent:event];
	}
}

bool windowShouldClose(QuartzWindowHandle handle) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	return qw.shouldClose;
}

void clearWindow(QuartzWindowHandle handle, unsigned char r, unsigned char g, unsigned char b) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	[qw.contentView setClearColorRed:r green:g blue:b];
}

struct PlushImage* captureWindow(QuartzWindowHandle handle) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	NSView* view = qw.window.contentView;
	
	[view lockFocus];
	NSBitmapImageRep* rep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[view bounds]] autorelease];
	[view unlockFocus];
	
	if (!rep) return NULL;
	
	int width = [rep pixelsWide];
	int height = [rep pixelsHigh];
	int bytesPerRow = width * 4;
	unsigned char* pixels = (unsigned char*)malloc(bytesPerRow * height);
	
	if (!pixels) return NULL;
	
	for (int y = 0; y < height; y++) {
		unsigned char* row = [rep bitmapData] + [rep bytesPerRow] * y;
		memcpy(pixels + y * bytesPerRow, row, bytesPerRow);
	}
	
	struct PlushImage* image = (struct PlushImage*)malloc(sizeof(struct PlushImage));
	if (!image) {
		free(pixels);
		return NULL;
	}
	
	image->width = width;
	image->height = height;
	image->pixels = pixels;
	
	return image;
}

void getMousePosition(QuartzWindowHandle handle, int* x, int* y) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	if (x) *x = qw.contentView.mouseX;
	if (y) *y = qw.contentView.mouseY;
}

bool getMouseButtonState(QuartzWindowHandle handle, int button) {
	QuartzWindow* qw = (QuartzWindow*)handle;
	switch (button) {
		case 0: return qw.contentView.mouseButtonLeft;
		case 1: return qw.contentView.mouseButtonRight;
		case 2: return qw.contentView.mouseButtonMiddle;
		default: return false;
	}
}