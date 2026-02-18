#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct PlushImage;

typedef void* QuartzWindowHandle;
extern bool keyreturn;
extern bool keyup;
extern bool keydown;
extern bool keyleft;
extern bool keyright;
extern bool keya;
extern bool keyb;
extern bool keyc;
extern bool keyd;
extern bool keye;
extern bool keyf;
extern bool keyg;
extern bool keyh;
extern bool keyi;
extern bool keyj;
extern bool keyk;
extern bool keyl;
extern bool keym;
extern bool keyn;
extern bool keyo;
extern bool keyp;
extern bool keyq;
extern bool keyr;
extern bool keys;
extern bool keyt;
extern bool keyu;
extern bool keyv;
extern bool keyw;
extern bool keyx;
extern bool keyy;
extern bool keyz;
extern bool key1;
extern bool key2;
extern bool key3;
extern bool key4;
extern bool key5;
extern bool key6;
extern bool key7;
extern bool key8;
extern bool key9;
extern bool key0;
extern bool keyminus;
extern bool keyback;
extern bool keydelete;
extern bool keyspace;

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
void updateKeyboardState();

bool macos_save_png(const char* path, const unsigned char* rgbaPixels, int width, int height);
unsigned char* macos_load_png(const char* path, int* outWidth, int* outHeight);

void* macos_font_load(const char* fontPath, float fontSize);
void macos_font_resize(void* fontHandle, float newSize);
struct PlushImage* macos_font_render(void* fontHandle, const char* utf8Text, int r, int g, int b, double a);
void macos_font_free(void* fontHandle);

#ifdef __cplusplus
}
#endif