#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct PlushImage;

typedef void* QuartzWindowHandle;

QuartzWindowHandle createWindow(const char* title, int width, int height);
void closeWindow(QuartzWindowHandle window);
void destroyWindow(QuartzWindowHandle window);
const char* getWindowTitle(QuartzWindowHandle window);
void getWindowSize(QuartzWindowHandle window, int* width, int* height);
void setWindowSize(QuartzWindowHandle window, int width, int height);
void setWindowTitle(QuartzWindowHandle window, const char* title);
void pushImage(QuartzWindowHandle window, const struct PlushImage* image);
void updateWindow(QuartzWindowHandle window);
bool windowShouldClose(QuartzWindowHandle window);
void clearWindow(QuartzWindowHandle window, unsigned char r, unsigned char g, unsigned char b);
struct PlushImage* captureWindow(QuartzWindowHandle window);
void getMousePosition(QuartzWindowHandle window, int* x, int* y);
bool getMouseButtonState(QuartzWindowHandle window, int button);

#ifdef __cplusplus
}
#endif