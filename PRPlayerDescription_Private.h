#import "PRPlayerDescription.h"

@interface PRPlayerDescription ()
@property (readwrite) NSArray *invalidItems;
@property (readwrite) PRListID *currentList;
@property (readwrite) PRItemID *currentItem;
@property (readwrite) NSInteger currentIndex;
@property (readwrite) BOOL shuffle;
@property (readwrite) NSInteger repeat;
@end

@interface PRMovieDescription ()
@property (readwrite) BOOL isPlaying;
@property (readwrite) CGFloat volume;
@property (readwrite) long currentTime;
@property (readwrite) long duration;
@end
