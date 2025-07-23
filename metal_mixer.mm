#include "metal_mixer.hpp"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#include <unordered_map>
#include <mutex>

@interface AudioPlayer : NSObject <AVAudioPlayerDelegate>
@property (strong) AVAudioPlayer* player;
@property BOOL isPlaying;
@property uint64_t lastStopOffset;
@end

@implementation AudioPlayer
- (instancetype)initWithURL:(NSURL*)url {
	if (self = [super init]) {
		NSError* error = nil;
		_player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
		if (!_player) {
			NSLog(@"Error creating player: %@", error.localizedDescription);
			return nil;
		}
		_player.delegate = self;
		[_player prepareToPlay];
		_isPlaying = NO;
		_lastStopOffset = 0;
	}
	return self;
}

- (void)playAtOffset:(NSTimeInterval)offset loop:(BOOL)loop {
	_player.currentTime = offset;
	_player.numberOfLoops = loop ? -1 : 0;
	_isPlaying = [_player play];
}

- (void)stop {
	if (_isPlaying) {
		[_player stop];
		_lastStopOffset = (uint64_t)(_player.currentTime * 1000);
		_isPlaying = NO;
	}
}

- (uint64_t)currentOffset {
	return _isPlaying ? (uint64_t)(_player.currentTime * 1000) : _lastStopOffset;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag {
	_isPlaying = NO;
	_lastStopOffset = 0;
}
@end

static std::unordered_map<void*, AudioPlayer*> players;
static std::mutex playerMutex;

void* OpenMP3File(const char* filePath) {
	NSString* path = [NSString stringWithUTF8String:filePath];
	NSURL* url = [NSURL fileURLWithPath:path];
	if (!url) return nullptr;
	
	AudioPlayer* player = [[AudioPlayer alloc] initWithURL:url];
	if (!player) return nullptr;
	
	void* handle = (__bridge_retained void*)player;
	std::lock_guard<std::mutex> lock(playerMutex);
	players[handle] = player;
	return handle;
}

bool Play(void* handle, uint64_t offsetInMilliseconds, bool loop) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	if (it == players.end()) return false;
	
	AudioPlayer* player = it->second;
	[player playAtOffset:offsetInMilliseconds / 1000.0 loop:loop];
	return player.isPlaying;
}

uint64_t GetCurrentOffset(void* handle) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	return it != players.end() ? [it->second currentOffset] : 0;
}

void StopAll() {
	std::lock_guard<std::mutex> lock(playerMutex);
	for (auto& pair : players) {
		[pair.second stop];
	}
}

uint64_t Stop(void* handle) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	if (it == players.end()) return 0;
	
	uint64_t offset = [it->second currentOffset];
	[it->second stop];
	return offset;
}

void Close(void* handle) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	if (it != players.end()) {
		[it->second stop];
		players.erase(it);
		CFRelease(handle);
	}
}