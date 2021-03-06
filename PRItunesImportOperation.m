#import "PRItunesImportOperation.h"
#import "PRList.h"
#import "NSNotificationCenter+Extensions.h"
#import "PRPlaylists.h"
#import "PRDb.h"
#import "PRLibrary.h"
#import "PRPlaylists.h"
#import "PRAlbumArtController.h"
#import "PRProgressManager.h"
#import "PROperationProgress.h"
#import "PRCore.h"
#import "NSEnumerator+Extensions.h"
#import "NSFileManager+Extensions.h"
#import "PRTagger.h"
#import "PRFileInfo.h"
#import "NSOperationQueue+Extensions.h"

@interface NSDictionary (trackSort)
- (int)trackSort:(NSDictionary *)dictionary;
@end
@implementation NSDictionary (trackSort)
- (int)trackSort:(NSDictionary *)dictionary {return [(NSString *)[self objectForKey:@"Location"] compare:[dictionary objectForKey:@"Location"]]; }
@end


@implementation PRItunesImportOperation

- (id)initWithURL:(NSURL *)URL_ core:(PRCore *)core {
    if (!(self = [super init])) {return nil;}
    _core = core;
    _db = [core db];
    _tempFileCount = 0;
    _fileTrackIdDictionary = [[NSMutableDictionary alloc] init];
    iTunesURL = URL_;
    return self;
}

+ (id)operationWithURL:(NSURL *)URL core:(PRCore *)core {
    return [[PRItunesImportOperation alloc] initWithURL:URL core:core];
}


- (void)main {
    NSLog(@"begin itunesimport");
    @autoreleasepool {
        PROperationProgress *task = [PROperationProgress task];
        [task setTitle:@"Importing iTunes..."];
        [[_core taskManager] addTask:task];
        
        // Get tracks
        NSString *errorDescription;
        NSUInteger format;
        NSData *plistXML = [[[NSFileManager alloc] init] contentsAtPath:[iTunesURL path]];
        NSDictionary *plist = (NSDictionary *)[NSPropertyListSerialization propertyListFromData:plistXML
                                                                               mutabilityOption:NSPropertyListImmutable
                                                                                         format:&format
                                                                               errorDescription:&errorDescription];
        NSMutableArray *tracks = [NSMutableArray arrayWithArray:[[plist objectForKey:@"Tracks"] allValues]];
        // Sort and remove invalid tracks
        NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
        for (int i = 0; i < [tracks count]; i++) {
            NSDictionary *track = [tracks objectAtIndex:i];
            if ([[track objectForKey:@"Movie"] boolValue] ||
                [[track objectForKey:@"Podcast"] boolValue] ||
                [[track objectForKey:@"iTunesU"] boolValue] ||
                [[track objectForKey:@"Books"] boolValue] ||
                [[track objectForKey:@"Audiobooks"] boolValue] ||
                [[track objectForKey:@"TV Shows"] boolValue] ||
                ![track objectForKey:@"Location"] ||
                ![track objectForKey:@"Track ID"] ||
                ![NSURL URLWithString:[track objectForKey:@"Location"]]) {
                [indexesToRemove addIndex:i];
            }
        }
        [tracks removeObjectsAtIndexes:indexesToRemove];
        [tracks sortUsingSelector:@selector(trackSort:)];
        
        // Add tracks
        int index = 0; 
        NSEnumerator *enumerator = [tracks objectEnumerator];
        NSArray *nextTracks = nil;
        while ((nextTracks = [enumerator nextXObjects:300])) {
            index += 300;
            [task setPercent:(int)(((float)index/(float)[tracks count]) * 90)];
            [self addTracks:nextTracks];
            if ([task shouldCancel]) {goto end;}
        }
        
        // Add playlists
        index = 0;
        for (NSDictionary *i in [plist objectForKey:@"Playlists"]) {
            index += 1;
            [task setPercent:((float)index/(float)[[plist objectForKey:@"Playlists"] count]) * 9 + 90];
            [self addPlaylist:i];
            if ([task shouldCancel]) {goto end;}
        }
end:;
        [[_core taskManager] removeTask:task];
    }
    NSLog(@"end itunesimport");
}

- (void)addTracks:(NSArray *)tracks {
    @autoreleasepool {
    // Filter out existing files
        NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
        void (^blk)(void) = ^{
            for (int i = 0; i < [tracks count]; i++) {
                NSURL *u = [NSURL URLWithString:[[tracks objectAtIndex:i] objectForKey:@"Location"]];
                NSArray *similar = [[_db library] itemsWithSimilarURL:u]; 
                for (NSNumber *j in similar) {
                    // If similar file is equivalent to current URL, set them to be merged
                    NSString *uStr = [[_db library] valueForItem:j attr:PRItemAttrPath];
                    if ([uStr isEqualToString:[u absoluteString]] || [[NSFileManager defaultManager] itemAtURL:u equalsItemAtURL:[NSURL URLWithString:uStr]]) {
                        [_fileTrackIdDictionary setValue:j forKey:[[tracks objectAtIndex:i] objectForKey:@"Track ID"]];
                        [toRemove addIndex:i];
                        break;
                    }
                }
            }
        };
        [[NSOperationQueue mainQueue] addBlockAndWait:blk];
        // Filter out duplicate files
        NSMutableArray *URLs = [NSMutableArray array];
        for (int i = 0; i < [tracks count]; i++) {
            NSURL *u = [NSURL URLWithString:[[tracks objectAtIndex:i] objectForKey:@"Location"]];
            NSString *name = nil;
            BOOL err = [u getResourceValue:&name forKey:NSURLNameKey error:nil];
            if (!err || !name || [URLs containsObject:name]) {
                [toRemove addIndex:i];
                continue;
            }
            [URLs addObject:name];
        }
        // Get info
        [[_db albumArtController] clearTempArtwork];
        NSMutableArray *infoArray = [NSMutableArray array];
        for (int i = 0; i < [tracks count]; i++) {
            @autoreleasepool {
                if ([toRemove containsIndex:i]) {
                    continue;
                }
                NSDictionary *track = [tracks objectAtIndex:i];
                NSURL *URL = [NSURL URLWithString:[track objectForKey:@"Location"]];
                PRFileInfo *info = [PRTagger infoForURL:URL];
                if (!info) {
                    continue;
                }
                if ([track objectForKey:@"Play Date UTC"]) {
                    [[info attributes] setObject:[[track objectForKey:@"Play Date UTC"] description] forKey:PRItemAttrLastPlayed];
                }
                if ([track objectForKey:@"Play Count"]) {
                    [[info attributes] setObject:[track objectForKey:@"Play Count"] forKey:PRItemAttrPlayCount];
                }
                if ([track objectForKey:@"Rating"]) {
                    [[info attributes] setObject:[track objectForKey:@"Rating"] forKey:PRItemAttrRating];
                }
                if ([track objectForKey:@"Date Added"]) {
                    [[info attributes] setObject:[[track objectForKey:@"Date Added"] description] forKey:PRItemAttrDateAdded];
                } else {
                    [[info attributes] setObject:[[NSDate date] description] forKey:PRItemAttrDateAdded];
                }
                [info setTrackid:[[track objectForKey:@"Track ID"] intValue]];
                // Artwork
                if ([info art]) {
                    [info setTempArt:[[_db albumArtController] saveTempArtwork:[info art]]];
                    [info setArt:nil];
                }
                [infoArray addObject:info];
            }
        }
        // Add files
        blk = ^{
            [_db begin];
            for (PRFileInfo *i in infoArray) {
            PRItemID *item = [[_db library] addItemWithAttrs:[i attributes]];
                [i setItem:item];
                NSNumber *trackId = [NSNumber numberWithInt:[i trackid]];
                [_fileTrackIdDictionary setObject:item forKey:trackId];
            }
            [_db commit];
            [[NSNotificationCenter defaultCenter] postLibraryChanged];
        };
        [[NSOperationQueue mainQueue] addBlockAndWait:blk];
        // Artwork
        for (PRFileInfo *i in infoArray) {
            if (![i tempArt]) {continue;}
        [[_db albumArtController] setTempArtwork:[i tempArt] forItem:[i item]];
        }
    }
}

- (void)addPlaylist:(NSDictionary *)playlist {
    // filter out invalid playlists
    if ([[playlist objectForKey:@"Master"] boolValue] || 
        [playlist objectForKey:@"Distinguished Kind"] ||
        [[playlist objectForKey:@"Folder"] boolValue] ||
        [playlist objectForKey:@"Smart Info"]) {return;}
    // Get playlist items
    NSArray *playlistItems = [playlist objectForKey:@"Playlist Items"];
    if (!playlistItems) {
        playlistItems = @[];
    }
    // Add playlist items
    void (^blk)(void) = ^{
        [_db begin];
        PRList *list = nil;
        [[_db playlists] zAddStaticList:&list];
        if ([playlist objectForKey:@"Name"]) {
            [[_db playlists] setValue:[playlist objectForKey:@"Name"] forList:[list listID] attr:PRListAttrTitle];
        }
        for (NSDictionary *i in playlistItems) {
            NSNumber *track = [i objectForKey:@"Track ID"];
            if (!track) {continue;}
            NSNumber *file = [_fileTrackIdDictionary objectForKey:track];
            if (!file || ![[_db library] containsItem:file]) {continue;}
            [[_db playlists] zAppendItem:file toList:[list listID]];
        }
        [_db commit];
        [[NSNotificationCenter defaultCenter] postListsDidChange];
    };
    [[NSOperationQueue mainQueue] addBlockAndWait:blk];
}

@end
