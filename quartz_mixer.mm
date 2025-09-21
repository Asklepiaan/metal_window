#include "mixer.hpp"
#import <QuickTime/QuickTime.h>
#import <Cocoa/Cocoa.h>
#include <unordered_map>
#include <mutex>

@interface AudioPlayer : NSObject
{
	Movie movie;
	TimeValue duration;
	BOOL isPlaying;
	uint64_t lastStopOffset;
	BOOL shouldLoop;
}

- (instancetype)initWithMovie:(Movie)theMovie duration:(TimeValue)theDuration;
- (void)playAtOffset:(uint64_t)offsetInMilliseconds loop:(BOOL)loop;
- (void)stop;
- (uint64_t)currentOffset;
@end

@implementation AudioPlayer

- (instancetype)initWithMovie:(Movie)theMovie duration:(TimeValue)theDuration {
	if (self = [super init]) {
		movie = theMovie;
		duration = theDuration;
		isPlaying = NO;
		lastStopOffset = 0;
		shouldLoop = NO;
	}
	return self;
}

- (void)playAtOffset:(uint64_t)offsetInMilliseconds loop:(BOOL)loop {
	TimeValue timeValue = (TimeValue)((offsetInMilliseconds * GetMovieTimeScale(movie)) / 1000);
	SetMovieTimeValue(movie, timeValue);
	shouldLoop = loop;
	
	SetMoviePlayHints(movie, loop ? hintsLoop : 0, hintsLoop);
	
	StartMovie(movie);
	isPlaying = YES;
}

- (void)stop {
	if (isPlaying) {
		StopMovie(movie);
		lastStopOffset = [self currentOffset];
		isPlaying = NO;
	}
}

- (uint64_t)currentOffset {
	if (isPlaying) {
		TimeValue currentTime = GetMovieTime(movie, NULL);
		return (uint64_t)((currentTime * 1000) / GetMovieTimeScale(movie));
	} else {
		return lastStopOffset;
	}
}

- (void)dealloc {
	if (movie) {
		DisposeMovie(movie);
	}
	[super dealloc];
}

@end

static std::unordered_map<void*, AudioPlayer*> players;
static std::mutex playerMutex;

void* OpenMP3File(const char* filePath) {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	OSErr err = noErr;
	Movie movie = NULL;
	TimeValue duration = 0;
	
	NSString* path = [NSString stringWithUTF8String:filePath];
	if (!path) {
		[pool release];
		return nullptr;
	}
	
	FSRef fsRef;
	FSSpec fsSpec;
	
	if (FSPathMakeRef((const UInt8*)[path fileSystemRepresentation], &fsRef, NULL) == noErr) {
		if (FSGetCatalogInfo(&fsRef, kFSCatInfoNone, NULL, NULL, &fsSpec, NULL) == noErr) {
			short movieResRef = 0;
			
			err = OpenMovieFile(&fsSpec, &movieResRef, fsRdPerm);
			if (err == noErr) {
				err = NewMovieFromFile(&movie, movieResRef, NULL, NULL, newMovieActive, NULL);
				CloseMovieFile(movieResRef);
				
				if (err == noErr) {
					duration = GetMovieDuration(movie);
					SetMovieAudioMute(movie, false, 0);
					GoToBeginningOfMovie(movie);
					PrerollMovie(movie, GetMovieTime(movie, NULL), NULL);
				}
			}
		}
	}
	
	if (err != noErr || !movie) {
		[pool release];
		return nullptr;
	}
	
	AudioPlayer* player = [[AudioPlayer alloc] initWithMovie:movie duration:duration];
	void* handle = player;
	
	std::lock_guard<std::mutex> lock(playerMutex);
	players[handle] = player;
	
	[pool release];
	return handle;
}

bool Play(void* handle, uint64_t offsetInMilliseconds, bool loop) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	if (it == players.end()) return false;
	
	AudioPlayer* player = it->second;
	[player playAtOffset:offsetInMilliseconds loop:loop];
	return true;
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
	
	AudioPlayer* player = it->second;
	uint64_t offset = [player currentOffset];
	[player stop];
	return offset;
}

void Close(void* handle) {
	std::lock_guard<std::mutex> lock(playerMutex);
	auto it = players.find(handle);
	if (it != players.end()) {
		AudioPlayer* player = it->second;
		[player stop];
		players.erase(it);
		[player release];
	}
}