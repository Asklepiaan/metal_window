# Basic Metal bindings for cpp
* This project is made to simpilify working with metal from cpp on older os versions in the WinterMoon game engine. It is extremely barebones as it only needs to push pixels to the screen.

## Include in my project
* Copy both files into your project root
* Add `#include "metal_window.h"` to the top of your project
* Add `struct PlushImage {int width, height; unsigned char* pixels; };` to your project

## Build my project
* Customise these commands to your needs:
* A/M series macOS: `clang++ -std=c++11 -mmacosx-version-min=11.00 -mcpu=apple-a12 main.cpp metal_window.mm -o [your programme]-a12 -fobjc-arc [includes, libs, frameworks] -framework Metal -framework MetalKit`
* Intel macOS: `clang++ -std=c++11 -mmacosx-version-min=11.00 -target x86_64-apple-macos11 main.cpp metal_window.mm -o [your programme]-x64 -fobjc-arc [includes, libs, frameworks] -framework Metal -framework MetalKit`
* Universial binary: `lipo -create -output [your programme] [your programme]-a12 [your programme]-x64`

## Feed an image
* PlushImage struct is identical to GLFWimage struct, if you can load a GLFWimage then find and replace `GLFWimage` with `PlushImage`

## Exit
* Press esc to exit
* Press red dot to exit
* Press quit in dock to exit