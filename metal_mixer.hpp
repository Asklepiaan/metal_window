#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

void* OpenMP3File(const char* filePath);
bool Play(void* handle, uint64_t offsetInMilliseconds, bool loop);
uint64_t GetCurrentOffset(void* handle);
void StopAll();
uint64_t Stop(void* handle);
void Close(void* handle);

#ifdef __cplusplus
}
#endif