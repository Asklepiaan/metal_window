#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>
#import <CoreText/CoreText.h>
#include <Carbon/Carbon.h>
#include <string>
#include <vector>
#include <cmath>
#include <cstring>
#include "metal_window.h"

#if !__has_feature(objc_arc)
	#error This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

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

@interface MetalImageView : MTKView <MTKViewDelegate>
@property (strong) id<MTLTexture> texture;
@property (strong) id<MTLRenderPipelineState> pipeline;
@property (strong) id<MTLBuffer> vertexBuffer;
@property (strong) id<MTLCommandQueue> commandQueue;
@property (assign) BOOL needsRedraw;
@property (copy) void (^captureBlock)(id<MTLTexture>);
- (void)updateTextureWithImage:(const struct PlushImage*)image;
- (void)setClearColorRed:(float)r green:(float)g blue:(float)b;
@end

@interface MetalWindow : NSObject <NSWindowDelegate>
@property (strong) NSWindow* window;
@property (strong) MetalImageView* metalView;
@property (assign) int width;
@property (assign) int height;
@property (assign) bool shouldClose;
@property (strong) id eventMonitor;

@property (assign) int mouseX;
@property (assign) int mouseY;
@property (assign) BOOL mouseButtonLeft;
@property (assign) BOOL mouseButtonRight;
@property (assign) BOOL mouseButtonMiddle;

- (instancetype)initWithTitle:(NSString*)title width:(int)width height:(int)height;
@end

@implementation MetalImageView

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device {
	self = [super initWithFrame:frame device:device];
	if (self) {
		self.device = device;
		self.delegate = self;
		self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
		self.clearColor = MTLClearColorMake(0, 0, 0, 1);
		self.commandQueue = [device newCommandQueue];
		self.needsRedraw = YES;
		[self setupPipeline];
		[self setupVertices];
		[self setNeedsDisplay:YES];
	}
	return self;
}

- (void)setupPipeline {
	NSString* shaderSrc = 
	@"#include <metal_stdlib>\n"
	"using namespace metal;\n"
	"struct Vertex {\n"
	"	float4 position [[position]];\n"
	"	float2 texCoord;\n"
	"};\n"
	"vertex Vertex vertexShader(\n"
	"	uint vertexID [[vertex_id]],\n"
	"	constant float4 *vertices [[buffer(0)]]\n"
	") {\n"
	"	Vertex out;\n"
	"	out.position = float4(vertices[vertexID].xy, 0.0, 1.0);\n"
	"	out.texCoord = vertices[vertexID].zw;\n"
	"	return out;\n"
	"}\n"
	"fragment float4 fragmentShader(\n"
	"	Vertex in [[stage_in]],\n"
	"	texture2d<float> tex [[texture(0)]],\n"
	"	sampler smp [[sampler(0)]]\n"
	") {\n"
	"	return tex.sample(smp, in.texCoord);\n"
	"}";

	NSError* error = nil;
	id<MTLLibrary> library = [self.device newLibraryWithSource:shaderSrc options:nil error:&error];
	if (!library) {
		NSLog(@"Shader error: %@", error);
		return;
	}

	MTLRenderPipelineDescriptor* pipelineDesc = [MTLRenderPipelineDescriptor new];
	pipelineDesc.vertexFunction   = [library newFunctionWithName:@"vertexShader"];
	pipelineDesc.fragmentFunction = [library newFunctionWithName:@"fragmentShader"];
	pipelineDesc.colorAttachments[0].pixelFormat = self.colorPixelFormat;

	self.pipeline = [self.device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
	if (!self.pipeline) {
		NSLog(@"Pipeline error: %@", error);
	}
}

- (void)setupVertices {
	static const float vertices[] = {
		-1.0f,  1.0f,  0.0f, 0.0f,
		-1.0f, -1.0f,  0.0f, 1.0f,
		 1.0f, -1.0f,  1.0f, 1.0f,
		
		-1.0f,  1.0f,  0.0f, 0.0f,
		 1.0f, -1.0f,  1.0f, 1.0f,
		 1.0f,  1.0f,  1.0f, 0.0f
	};
	
	self.vertexBuffer = [self.device newBufferWithBytes:vertices
												 length:sizeof(vertices)
												options:MTLResourceStorageModeShared];
}

- (void)updateVerticesForImageSize:(CGSize)imageSize {
	float imageAspect = imageSize.width / imageSize.height;
	float viewAspect  = self.bounds.size.width / self.bounds.size.height;
	
	float scaleX = 1.0f;
	float scaleY = 1.0f;
	
	if (imageAspect > viewAspect) {
		scaleY = viewAspect / imageAspect;
	} else {
		scaleX = imageAspect / viewAspect;
	}
	
	float vertices[] = {
		-scaleX,  scaleY, 0.0f, 0.0f,
		-scaleX, -scaleY, 0.0f, 1.0f,
		 scaleX, -scaleY, 1.0f, 1.0f,
		
		-scaleX,  scaleY, 0.0f, 0.0f,
		 scaleX, -scaleY, 1.0f, 1.0f,
		 scaleX,  scaleY, 1.0f, 0.0f
	};
	
	self.vertexBuffer = [self.device newBufferWithBytes:vertices
												 length:sizeof(vertices)
												options:MTLResourceStorageModeShared];
}

- (void)updateTextureWithImage:(const struct PlushImage*)image {
	if (!image || !image->pixels || image->width <= 0 || image->height <= 0) {
		NSLog(@"Invalid image data");
		return;
	}

	MTLTextureDescriptor* textureDesc = [MTLTextureDescriptor
		texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
									 width:image->width
									height:image->height
								 mipmapped:NO];
	textureDesc.usage = MTLTextureUsageShaderRead;
	
	id<MTLTexture> texture = [self.device newTextureWithDescriptor:textureDesc];
	if (!texture) {
		NSLog(@"Failed to create texture");
		return;
	}

	[texture replaceRegion:MTLRegionMake2D(0, 0, image->width, image->height)
			   mipmapLevel:0
				 withBytes:image->pixels
			   bytesPerRow:4 * image->width];

	self.texture = texture;
	[self updateVerticesForImageSize:CGSizeMake(image->width, image->height)];
	self.needsRedraw = YES;
	[self setNeedsDisplay:YES];
}

- (void)setClearColorRed:(float)r green:(float)g blue:(float)b {
	self.clearColor = MTLClearColorMake(r, g, b, 1.0);
	self.needsRedraw = YES;
	[self setNeedsDisplay:YES];
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
}

- (void)drawInMTKView:(nonnull MTKView *)view {
	if (!self.needsRedraw) return;
	
	@autoreleasepool {
		id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
		MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
		
		if (renderPassDescriptor) {
			renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
			renderPassDescriptor.colorAttachments[0].clearColor = self.clearColor;
			
			id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
			
			if (self.texture) {
				[renderEncoder setRenderPipelineState:self.pipeline];
				[renderEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:0];
				[renderEncoder setFragmentTexture:self.texture atIndex:0];
				[renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
			}
			
			[renderEncoder endEncoding];
			
			if (view.currentDrawable) {
				[commandBuffer presentDrawable:view.currentDrawable];
			}
		}
		
		[commandBuffer commit];
		self.needsRedraw = NO;

		if (self.captureBlock) {
			void (^block)(id<MTLTexture>) = self.captureBlock;
			self.captureBlock = nil;
			block(view.currentDrawable.texture);
		}
	}
}

@end

@implementation MetalWindow {
	id _eventMonitor;
	id _mouseEventMonitor;
}

- (instancetype)initWithTitle:(NSString*)title width:(int)width height:(int)height {
	self = [super init];
	if (self) {
		_width = width;
		_height = height;
		_shouldClose = NO;

		_mouseX = 0;
		_mouseY = 0;
		_mouseButtonLeft = NO;
		_mouseButtonRight = NO;
		_mouseButtonMiddle = NO;
		
		NSRect rect = NSMakeRect(0, 0, width, height);
		_window = [[NSWindow alloc] initWithContentRect:rect
											  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
												backing:NSBackingStoreBuffered
												  defer:NO];
		[_window setTitle:title];
		[_window setDelegate:self];
		[_window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenNone];
		[_window setLevel:NSNormalWindowLevel];
		[_window setContentMinSize:rect.size];
		[_window setContentMaxSize:rect.size];
		[_window setAcceptsMouseMovedEvents:YES];
		
		id<MTLDevice> device = MTLCreateSystemDefaultDevice();
		_metalView = [[MetalImageView alloc] initWithFrame:rect device:device];
		[_window setContentView:_metalView];
		
		[_window center];
		[_window makeKeyAndOrderFront:nil];
		[NSApp activateIgnoringOtherApps:YES];
		
		__weak __typeof(self) weakSelf = self;
		_eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent*(NSEvent* event) {
			if (event.keyCode == 53) {
				[weakSelf.window performClose:nil];
				return nil;
			}
			return nil;
		}];

		_mouseEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:
			NSEventMaskLeftMouseDown | NSEventMaskLeftMouseUp |
			NSEventMaskRightMouseDown | NSEventMaskRightMouseUp |
			NSEventMaskOtherMouseDown | NSEventMaskOtherMouseUp |
			NSEventMaskMouseMoved |
			NSEventMaskLeftMouseDragged | NSEventMaskRightMouseDragged | NSEventMaskOtherMouseDragged
			handler:^NSEvent*(NSEvent* event) {
				MetalWindow* self = weakSelf;
				if (!self) return event;
				
				if (event.window == self.window) {
					NSPoint location = [event locationInWindow];
					NSView* contentView = self.window.contentView;

					self.mouseX = (int)location.x;
					self.mouseY = (int)(contentView.bounds.size.height - location.y);
					
					switch (event.type) {
						case NSEventTypeLeftMouseDown:
							self.mouseButtonLeft = YES;
							break;
						case NSEventTypeLeftMouseUp:
							self.mouseButtonLeft = NO;
							break;
						case NSEventTypeRightMouseDown:
							self.mouseButtonRight = YES;
							break;
						case NSEventTypeRightMouseUp:
							self.mouseButtonRight = NO;
							break;
						case NSEventTypeOtherMouseDown:
							if (event.buttonNumber == 2) {
								self.mouseButtonMiddle = YES;
							}
							break;
						case NSEventTypeOtherMouseUp:
							if (event.buttonNumber == 2) {
								self.mouseButtonMiddle = NO;
							}
							break;
						default:
							break;
					}
				}
				return event;
			}];
	}
	return self;
}

- (BOOL)windowShouldClose:(NSWindow*)sender {
	self.shouldClose = YES;
	return YES;
}

- (void)dealloc {
	if (_eventMonitor) {
		[NSEvent removeMonitor:_eventMonitor];
	}
	if (_mouseEventMonitor) {
		[NSEvent removeMonitor:_mouseEventMonitor];
	}
}

@end

static void ensureApplication() {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
		[NSApp activateIgnoringOtherApps:YES];
		[NSApp finishLaunching];
	});
}

MetalWindowHandle createWindow(const char* title, int width, int height) {
	ensureApplication();
	NSString* nsTitle = [NSString stringWithUTF8String:title];
	MetalWindow* mw = [[MetalWindow alloc] initWithTitle:nsTitle width:width height:height];
	return (__bridge_retained void*)mw;
}

void closeWindow(MetalWindowHandle handle) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	[mw.window close];
}

void destroyWindow(MetalWindowHandle handle) {
	MetalWindow* mw = (__bridge_transfer MetalWindow*)handle;
	[mw.window close];
}

const char* getWindowTitle(MetalWindowHandle handle) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	return strdup([mw.window.title UTF8String]);
}

void getWindowSize(MetalWindowHandle handle, int* width, int* height) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	*width = mw.width;
	*height = mw.height;
}

void setWindowSize(MetalWindowHandle handle, int width, int height) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	mw.width = width;
	mw.height = height;
	[mw.window setContentSize:NSMakeSize(width, height)];
}

void setWindowTitle(MetalWindowHandle handle, const char* title) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	mw.window.title = [NSString stringWithUTF8String:title];
}

void clearWindow(MetalWindowHandle handle, unsigned char r, unsigned char g, unsigned char b) {
	@autoreleasepool {
		MetalWindow* mw = (__bridge MetalWindow*)handle;
		[mw.metalView setClearColorRed:r/255.0f green:g/255.0f blue:b/255.0f];
	}
}

void pushImage(MetalWindowHandle handle, const struct PlushImage* image) {
	@autoreleasepool {
		MetalWindow* mw = (__bridge MetalWindow*)handle;
		[mw.metalView updateTextureWithImage:image];
	}
}

void updateWindow(MetalWindowHandle handle) {
	@autoreleasepool {
		NSEvent* event;
		while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
										   untilDate:[NSDate distantPast]
											  inMode:NSDefaultRunLoopMode
											 dequeue:YES])) {
			[NSApp sendEvent:event];
		}
	}
}

bool windowShouldClose(MetalWindowHandle handle) {
	MetalWindow* mw = (__bridge MetalWindow*)handle;
	return mw.shouldClose;
}

struct PlushImage* captureWindow(MetalWindowHandle handle) {
	@autoreleasepool {
		MetalWindow* mw = (__bridge MetalWindow*)handle;
		MetalImageView* metalView = mw.metalView;
		
		if (!metalView) return NULL;

		metalView.captureBlock = nil;
		
		__block struct PlushImage* capturedImage = NULL;
		__block BOOL done = NO;

		__weak MetalImageView *weakMetalView = metalView;
		metalView.captureBlock = ^(id<MTLTexture> texture) {
			MetalImageView *metalView = weakMetalView;
			if (!metalView) {
				done = YES;
				return;
			}
			if (!texture) {
				done = YES;
				return;
			}
			
			int width = (int)texture.width;
			int height = (int)texture.height;
			int bytesPerRow = 4 * width;
			int totalBytes = bytesPerRow * height;
			
			id<MTLDevice> device = metalView.device;
			id<MTLBuffer> buffer = [device newBufferWithLength:totalBytes
													   options:MTLResourceStorageModeShared];
			if (!buffer) {
				done = YES;
				return;
			}
			
			id<MTLCommandQueue> commandQueue = metalView.commandQueue;
			id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
			id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
			
			[blitEncoder copyFromTexture:texture
							 sourceSlice:0
							 sourceLevel:0
							sourceOrigin:MTLOriginMake(0, 0, 0)
							  sourceSize:MTLSizeMake(width, height, 1)
								toBuffer:buffer
					   destinationOffset:0
				  destinationBytesPerRow:bytesPerRow
				destinationBytesPerImage:totalBytes];
			
			[blitEncoder endEncoding];
			[commandBuffer commit];
			[commandBuffer waitUntilCompleted];
			
			unsigned char* bgraData = (unsigned char*)[buffer contents];
			unsigned char* rgbaData = (unsigned char*)malloc(totalBytes);
			if (!rgbaData) {
				done = YES;
				return;
			}

			for (int i = 0; i < totalBytes; i += 4) {
				rgbaData[i]   = bgraData[i+2];
				rgbaData[i+1] = bgraData[i+1];
				rgbaData[i+2] = bgraData[i];
				rgbaData[i+3] = bgraData[i+3];
			}
			
			capturedImage = (struct PlushImage*)malloc(sizeof(struct PlushImage));
			if (!capturedImage) {
				free(rgbaData);
				done = YES;
				return;
			}
			
			capturedImage->width = width;
			capturedImage->height = height;
			capturedImage->pixels = rgbaData;
			done = YES;
		};

		[metalView setNeedsDisplay:YES];
		[metalView display];

		NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
		NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
		while (!done && [runLoop runMode:NSDefaultRunLoopMode beforeDate:deadline]) {
			deadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
		}

		if (!done) {
			metalView.captureBlock = nil;
		}
		
		return capturedImage;
	}
}

void getMousePosition(MetalWindowHandle handle, int* x, int* y) {
	@autoreleasepool {
		MetalWindow* mw = (__bridge MetalWindow*)handle;
		if (x) *x = mw.mouseX;
		if (y) *y = mw.mouseY;
	}
}

bool getMouseButtonState(MetalWindowHandle handle, int button) {
	@autoreleasepool {
		MetalWindow* mw = (__bridge MetalWindow*)handle;
		switch (button) {
			case 0: return mw.mouseButtonLeft;
			case 1: return mw.mouseButtonRight;
			case 2: return mw.mouseButtonMiddle;
			default: return false;
		}
	}
}

bool macos_save_png(const char* path, const unsigned char* rgbaPixels, int width, int height) {
	if (!path || !rgbaPixels || width <= 0 || height <= 0) return false;

	CGColorSpaceRef colourSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	if (!colourSpace) return false;

	CGContextRef context = CGBitmapContextCreate(
		(void*)rgbaPixels,
		(size_t)width,
		(size_t)height,
		8,
		(size_t)width * 4,
		colourSpace,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
	);
	CGColorSpaceRelease(colourSpace);
	if (!context) return false;

	CGImageRef cgImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	if (!cgImage) return false;

	CFURLRef url = CFURLCreateFromFileSystemRepresentation(
		kCFAllocatorDefault,
		(const UInt8*)path,
		(CFIndex)strlen(path),
		false
	);
	if (!url) {
		CGImageRelease(cgImage);
		return false;
	}

	CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
	CFRelease(url);
	if (!destination) {
		CGImageRelease(cgImage);
		return false;
	}

	CGImageDestinationAddImage(destination, cgImage, NULL);
	bool ok = (bool)CGImageDestinationFinalize(destination);
	CFRelease(destination);
	CGImageRelease(cgImage);
	return ok;
}

unsigned char* macos_load_png(const char* path, int* outWidth, int* outHeight) {
	if (outWidth) *outWidth = 0;
	if (outHeight) *outHeight = 0;
	if (!path) return nullptr;

	CFURLRef url = CFURLCreateFromFileSystemRepresentation(
		kCFAllocatorDefault,
		(const UInt8*)path,
		(CFIndex)strlen(path),
		false
	);
	if (!url) return nullptr;

	CGImageSourceRef source = CGImageSourceCreateWithURL(url, NULL);
	CFRelease(url);
	if (!source) return nullptr;

	CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, NULL);
	CFRelease(source);
	if (!cgImage) return nullptr;

	size_t width = CGImageGetWidth(cgImage);
	size_t height = CGImageGetHeight(cgImage);
	size_t bytesPerRow = width * 4;
	unsigned char* imageData = new unsigned char[bytesPerRow * height];

	CGColorSpaceRef colourSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(
		imageData,
		width,
		height,
		8,
		bytesPerRow,
		colourSpace,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
	);
	if (!context) {
		CGImageRelease(cgImage);
		CGColorSpaceRelease(colourSpace);
		delete[] imageData;
		return nullptr;
	}

	CGContextSetBlendMode(context, kCGBlendModeCopy);
	CGContextSetRGBFillColor(context, 0, 0, 0, 0);
	CGContextFillRect(context, CGRectMake(0, 0, width, height));
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);

	CGContextRelease(context);
	CGImageRelease(cgImage);
	CGColorSpaceRelease(colourSpace);

	// Ensure fully transparent pixels have RGB=0.
	for (size_t i = 0; i < width * height * 4; i += 4) {
		if (imageData[i + 3] == 0) {
			imageData[i] = 0;
			imageData[i + 1] = 0;
			imageData[i + 2] = 0;
		}
	}

	if (outWidth) *outWidth = (int)width;
	if (outHeight) *outHeight = (int)height;
	return imageData;
}

class WMCoreTextFont {
public:
	CTFontRef fontRef;
	WMCoreTextFont(CTFontRef f) : fontRef(f) {}
	~WMCoreTextFont() { if (fontRef) CFRelease(fontRef); }
	WMCoreTextFont(const WMCoreTextFont&) = delete;
	WMCoreTextFont& operator=(const WMCoreTextFont&) = delete;
};

struct WMTextLineLayout {
	CTLineRef line;
	CGFloat ascent;
	CGFloat descent;
	CGFloat leading;
	CGFloat advance;
};

void* macos_font_load(const char* fontPath, float fontSize) {
	if (!fontPath) return nullptr;
	std::string path(fontPath);
	CFURLRef fontURL = CFURLCreateFromFileSystemRepresentation(
		kCFAllocatorDefault,
		(const UInt8*)path.c_str(),
		(CFIndex)path.length(),
		false
	);
	if (!fontURL) return nullptr;

	CGDataProviderRef dataProvider = CGDataProviderCreateWithURL(fontURL);
	CFRelease(fontURL);
	if (!dataProvider) return nullptr;

	CGFontRef cgFont = CGFontCreateWithDataProvider(dataProvider);
	CGDataProviderRelease(dataProvider);
	if (!cgFont) return nullptr;

	CTFontRef font = CTFontCreateWithGraphicsFont(cgFont, fontSize, NULL, NULL);
	CGFontRelease(cgFont);
	if (!font) return nullptr;

	return (void*)new WMCoreTextFont(font);
}

void macos_font_resize(void* fontHandle, float newSize) {
	WMCoreTextFont* font = (WMCoreTextFont*)fontHandle;
	if (!font || !font->fontRef) return;

	CTFontDescriptorRef descriptor = CTFontCopyFontDescriptor(font->fontRef);
	CGAffineTransform transform = CTFontGetMatrix(font->fontRef);
	CTFontRef newFont = CTFontCreateWithFontDescriptor(descriptor, newSize, &transform);
	if (descriptor) CFRelease(descriptor);

	if (newFont) {
		CFRelease(font->fontRef);
		font->fontRef = newFont;
	}
}

static PlushImage make_empty_image() {
	PlushImage img;
	img.width = 0;
	img.height = 0;
	img.pixels = NULL;
	img.reflectivityWidth = 0;
	img.reflectivityHeight = 0;
	img.reflectivity = NULL;
	return img;
}

struct PlushImage* macos_font_render(void* fontHandle, const char* utf8Text, int colourR, int colourG, int colourB, double colourA) {
	WMCoreTextFont* font = (WMCoreTextFont*)fontHandle;
	if (!font || !font->fontRef || !utf8Text) return nullptr;

	std::string text(utf8Text);
	if (text.empty()) {
		PlushImage* out = new PlushImage(make_empty_image());
		return out;
	}

	CFDictionaryRef attributes = NULL;
	CFMutableDictionaryRef attr = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
		&kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	if (!attr) return nullptr;
	CFDictionarySetValue(attr, kCTFontAttributeName, font->fontRef);

	CGFloat components[4] = { (CGFloat)colourR/255.0f, (CGFloat)colourG/255.0f, (CGFloat)colourB/255.0f, (CGFloat)colourA/255.0f };
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGColorRef fg = CGColorCreate(cs, components);
	CGColorSpaceRelease(cs);
	if (fg) CFDictionarySetValue(attr, kCTForegroundColorAttributeName, fg);
	attributes = attr;

	std::vector<std::string> lines;
	size_t start = 0;
	while (start <= text.size()) {
		size_t nl = text.find('\n', start);
		std::string lineText = (nl == std::string::npos) ? text.substr(start) : text.substr(start, nl - start);
		if (!lineText.empty() && lineText.back() == '\r') {
			lineText.pop_back();
		}
		lines.push_back(lineText);
		if (nl == std::string::npos) break;
		start = nl + 1;
	}
	if (lines.empty()) {
		lines.push_back("");
	}

	std::vector<WMTextLineLayout> layout;
	layout.reserve(lines.size());
	CGFloat maxAdvance = 0;
	CGFloat totalHeight = 0;
	CGFloat fallbackLineHeight = std::max((CGFloat)1.0, ceil(CTFontGetSize(font->fontRef) * 1.2));

	for (const std::string& lineText : lines) {
		CFStringRef cfLine = CFStringCreateWithCString(kCFAllocatorDefault, lineText.c_str(), kCFStringEncodingUTF8);
		if (!cfLine) {
			for (const auto& item : layout) {
				CFRelease(item.line);
			}
			if (fg) CGColorRelease(fg);
			CFRelease(attr);
			return nullptr;
		}

		CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, cfLine, attributes);
		CFRelease(cfLine);
		if (!attributedString) {
			for (const auto& item : layout) {
				CFRelease(item.line);
			}
			if (fg) CGColorRelease(fg);
			CFRelease(attr);
			return nullptr;
		}

		CTLineRef line = CTLineCreateWithAttributedString(attributedString);
		CFRelease(attributedString);
		if (!line) {
			for (const auto& item : layout) {
				CFRelease(item.line);
			}
			if (fg) CGColorRelease(fg);
			CFRelease(attr);
			return nullptr;
		}

		CGFloat ascent = 0;
		CGFloat descent = 0;
		CGFloat leading = 0;
		CGFloat advance = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
		CGFloat lineHeight = ascent + descent + leading;
		if (lineHeight <= 0) {
			lineHeight = fallbackLineHeight;
		}

		if (advance > maxAdvance) {
			maxAdvance = advance;
		}
		totalHeight += lineHeight;
		layout.push_back({line, ascent, descent, leading, advance});
	}

	if (fg) CGColorRelease(fg);
	CFRelease(attr);

	int width = (int)ceil(maxAdvance);
	int height = (int)ceil(totalHeight);
	if (width <= 0) width = 1;
	if (height <= 0) height = 1;

	size_t bytesPerRow = (size_t)width * 4;
	unsigned char* pixels = new unsigned char[bytesPerRow * (size_t)height];
	memset(pixels, 0, bytesPerRow * (size_t)height);

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(
		pixels,
		(size_t)width,
		(size_t)height,
		8,
		bytesPerRow,
		colorSpace,
		kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
	);
	CGColorSpaceRelease(colorSpace);

	if (!context) {
		delete[] pixels;
		for (const auto& item : layout) {
			CFRelease(item.line);
		}
		return nullptr;
	}

	CGContextSetRGBFillColor(context, 1, 1, 1, 0);
	CGContextFillRect(context, CGRectMake(0, 0, width, height));
	CGContextSetTextMatrix(context, CGAffineTransformIdentity);

	CGFloat cursorY = (CGFloat)height;
	for (const auto& item : layout) {
		CGFloat lineHeight = item.ascent + item.descent + item.leading;
		if (lineHeight <= 0) {
			lineHeight = fallbackLineHeight;
		}
		cursorY -= item.ascent;
		CGContextSetTextPosition(context, 0, cursorY);
		CTLineDraw(item.line, context);
		cursorY -= (item.descent + item.leading);
	}

	CGContextRelease(context);
	for (const auto& item : layout) {
		CFRelease(item.line);
	}

	PlushImage out = make_empty_image();
	out.width = width;
	out.height = height;
	out.pixels = pixels;
	PlushImage* outPtr = new PlushImage(out);
	return outPtr;
}

void macos_font_free(void* fontHandle) {
	WMCoreTextFont* font = (WMCoreTextFont*)fontHandle;
	delete font;
}
