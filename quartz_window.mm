#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include "quartz_window.h"
#include <string.h>

struct PlushImage {
	int width, height;
	unsigned char* pixels;
	int reflectivityWidth, reflectivityHeight;
	unsigned char* reflectivity;
};

bool keyreturn = false;
bool keyup = false;
bool keydown = false;
bool keyleft = false;
bool keyright = false;
bool keya = false;
bool keyb = false;
bool keyc = false;
bool keyd = false;
bool keye = false;
bool keyf = false;
bool keyg = false;
bool keyh = false;
bool keyi = false;
bool keyj = false;
bool keyk = false;
bool keyl = false;
bool keym = false;
bool keyn = false;
bool keyo = false;
bool keyp = false;
bool keyq = false;
bool keyr = false;
bool keys = false;
bool keyt = false;
bool keyu = false;
bool keyv = false;
bool keyw = false;
bool keyx = false;
bool keyy = false;
bool keyz = false;
bool key1 = false;
bool key2 = false;
bool key3 = false;
bool key4 = false;
bool key5 = false;
bool key6 = false;
bool key7 = false;
bool key8 = false;
bool key9 = false;
bool key0 = false;
bool keyminus = false;
bool keyback = false;
bool keydelete = false;
bool keyspace = false;

void updateKeyboardState() {
	KeyMap keyState;
	GetKeys(keyState);
	
	const UInt8* bytes = reinterpret_cast<const UInt8*>(keyState);

	auto isKeyDown = [bytes](unsigned short keyCode) -> bool {
		const size_t byteIndex = keyCode / 8;
		const UInt8 bitMask = 1 << (keyCode % 8);
		return (bytes[byteIndex] & bitMask) != 0;
	};

	keyreturn = isKeyDown(kVK_Return);
	keyup     = isKeyDown(kVK_UpArrow);
	keydown   = isKeyDown(kVK_DownArrow);
	keyleft   = isKeyDown(kVK_LeftArrow);
	keyright  = isKeyDown(kVK_RightArrow);
	keya = isKeyDown(kVK_ANSI_A);
	keyb = isKeyDown(kVK_ANSI_B);
	keyc = isKeyDown(kVK_ANSI_C);
	keyd = isKeyDown(kVK_ANSI_D);
	keye = isKeyDown(kVK_ANSI_E);
	keyf = isKeyDown(kVK_ANSI_F);
	keyg = isKeyDown(kVK_ANSI_G);
	keyh = isKeyDown(kVK_ANSI_H);
	keyi = isKeyDown(kVK_ANSI_I);
	keyj = isKeyDown(kVK_ANSI_J);
	keyk = isKeyDown(kVK_ANSI_K);
	keyl = isKeyDown(kVK_ANSI_L);
	keym = isKeyDown(kVK_ANSI_M);
	keyn = isKeyDown(kVK_ANSI_N);
	keyo = isKeyDown(kVK_ANSI_O);
	keyp = isKeyDown(kVK_ANSI_P);
	keyq = isKeyDown(kVK_ANSI_Q);
	keyr = isKeyDown(kVK_ANSI_R);
	keys = isKeyDown(kVK_ANSI_S);
	keyt = isKeyDown(kVK_ANSI_T);
	keyu = isKeyDown(kVK_ANSI_U);
	keyv = isKeyDown(kVK_ANSI_V);
	keyw = isKeyDown(kVK_ANSI_W);
	keyx = isKeyDown(kVK_ANSI_X);
	keyy = isKeyDown(kVK_ANSI_Y);
	keyz = isKeyDown(kVK_ANSI_Z);
	key1 = isKeyDown(kVK_ANSI_1);
	key2 = isKeyDown(kVK_ANSI_2);
	key3 = isKeyDown(kVK_ANSI_3);
	key4 = isKeyDown(kVK_ANSI_4);
	key5 = isKeyDown(kVK_ANSI_5);
	key6 = isKeyDown(kVK_ANSI_6);
	key7 = isKeyDown(kVK_ANSI_7);
	key8 = isKeyDown(kVK_ANSI_8);
	key9 = isKeyDown(kVK_ANSI_9);
	key0 = isKeyDown(kVK_ANSI_0);
	keyminus  = isKeyDown(kVK_ANSI_Minus);
	keyback   = isKeyDown(kVK_Delete);
	keydelete = isKeyDown(kVK_ForwardDelete);
	keyspace  = isKeyDown(kVK_Space);
}

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