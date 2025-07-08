#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct PlushImage;

typedef void* MetalWindowHandle;

MetalWindowHandle createWindow(const char* title, int width, int height);

void closeWindow(MetalWindowHandle window);

void destroyWindow(MetalWindowHandle window);
const char* getWindowTitle(MetalWindowHandle window);

void getWindowSize(MetalWindowHandle window, int* width, int* height);

void setWindowSize(MetalWindowHandle window, int width, int height);

void setWindowTitle(MetalWindowHandle window, const char* title);

void pushImage(MetalWindowHandle window, const struct PlushImage* image);

void updateWindow(MetalWindowHandle window);

bool windowShouldClose(MetalWindowHandle window);

void clearWindow(MetalWindowHandle window, unsigned char r, unsigned char g, unsigned char b);

#ifdef __cplusplus
}
#endif