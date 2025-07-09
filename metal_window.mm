#import <AppKit/AppKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "metal_window.h"

struct PlushImage {
	int width, height;
	unsigned char* pixels;
};

#if !__has_feature(objc_arc)
	#error This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

@interface MetalImageView : MTKView <MTKViewDelegate>
@property (strong) id<MTLTexture> texture;
@property (strong) id<MTLRenderPipelineState> pipeline;
@property (strong) id<MTLBuffer> vertexBuffer;
@property (strong) id<MTLCommandQueue> commandQueue;
@property (assign) BOOL needsRedraw;
@property (assign) MTLClearColor clearColor;
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
	"    float4 position [[position]];\n"
	"    float2 texCoord;\n"
	"};\n"
	"vertex Vertex vertexShader(\n"
	"    uint vertexID [[vertex_id]],\n"
	"    constant float4 *vertices [[buffer(0)]]\n"
	") {\n"
	"    Vertex out;\n"
	"    out.position = float4(vertices[vertexID].xy, 0.0, 1.0);\n"
	"    out.texCoord = vertices[vertexID].zw;\n"
	"    return out;\n"
	"}\n"
	"fragment float4 fragmentShader(\n"
	"    Vertex in [[stage_in]],\n"
	"    texture2d<float> tex [[texture(0)]],\n"
	"    sampler smp [[sampler(0)]]\n"
	") {\n"
	"    return tex.sample(smp, in.texCoord);\n"
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

		metalView.captureBlock = ^(id<MTLTexture> texture) {
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