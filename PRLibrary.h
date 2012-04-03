#import <Cocoa/Cocoa.h>
#import "PRDb.h"
@class PRDb;


typedef NSNumber PRItem;

typedef NSString PRItemAttr;
extern PRItemAttr * const PRItemAttrPath;
extern PRItemAttr * const PRItemAttrSize;
extern PRItemAttr * const PRItemAttrKind;
extern PRItemAttr * const PRItemAttrTime;
extern PRItemAttr * const PRItemAttrBitrate;
extern PRItemAttr * const PRItemAttrChannels;
extern PRItemAttr * const PRItemAttrSampleRate;
extern PRItemAttr * const PRItemAttrCheckSum;
extern PRItemAttr * const PRItemAttrLastModified;
extern PRItemAttr * const PRItemAttrTitle;
extern PRItemAttr * const PRItemAttrArtist;
extern PRItemAttr * const PRItemAttrAlbum;
extern PRItemAttr * const PRItemAttrBPM;
extern PRItemAttr * const PRItemAttrYear;
extern PRItemAttr * const PRItemAttrTrackNumber;
extern PRItemAttr * const PRItemAttrTrackCount;
extern PRItemAttr * const PRItemAttrComposer;
extern PRItemAttr * const PRItemAttrDiscNumber;
extern PRItemAttr * const PRItemAttrDiscCount;
extern PRItemAttr * const PRItemAttrComments;
extern PRItemAttr * const PRItemAttrAlbumArtist;
extern PRItemAttr * const PRItemAttrGenre;
extern PRItemAttr * const PRItemAttrCompilation;
extern PRItemAttr * const PRItemAttrLyrics;
extern PRItemAttr * const PRItemAttrArtwork;
extern PRItemAttr * const PRItemAttrArtistAlbumArtist;
extern PRItemAttr * const PRItemAttrDateAdded;
extern PRItemAttr * const PRItemAttrLastPlayed;
extern PRItemAttr * const PRItemAttrPlayCount;
extern PRItemAttr * const PRItemAttrRating;


@interface PRLibrary : NSObject {
	PRDb *db;
}
// Initialization
- (id)initWithDb:(PRDb *)db_;
- (void)create;
- (BOOL)initialize;

// Update
- (BOOL)propagateItemDelete;

// Accessors
- (BOOL)containsItem:(PRItem *)item;
- (PRItem *)addItemWithAttrs:(NSDictionary *)attrs;
- (void)removeItems:(NSArray *)items;
- (id)valueForItem:(PRItem *)item attr:(PRItemAttr *)attr;
- (void)setValue:(id)value forItem:(PRItem *)item attr:(PRItemAttr *)attr;
- (NSDictionary *)attrsForItem:(PRItem *)item;
- (void)setAttrs:(NSDictionary *)attrs forItem:(PRItem *)item;

- (NSString *)artistValueForItem:(PRItem *)item;
- (NSURL *)URLForItem:(PRItem *)item;
- (NSArray *)itemsWithSimilarURL:(NSURL *)URL;
- (NSArray *)itemsWithValue:(id)value forAttr:(PRItemAttr *)attr;

// Misc
+ (NSArray *)itemAttrProperties;
+ (NSArray *)itemAttrs;
+ (NSString *)columnNameForItemAttr:(PRItemAttr *)attr;
+ (PRCol *)columnTypeForItemAttr:(PRItemAttr *)attr;
+ (NSString *)titleForItemAttr:(PRItemAttr *)attr;
+ (NSNumber *)internalForItemAttr:(PRItemAttr *)attr;
+ (PRItemAttr *)itemAttrForInternal:(NSNumber *)internal;
@end
