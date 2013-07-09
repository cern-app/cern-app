//Author: Timur Pocheptsov.
//Developed for CERN app.

//This is a code for a table view controller, which shows author, title, short content, date for
//an every news item.
//It can be used ONLY for iPhone/iPod touch device, for iPad we'll have different approach.

#import <UIKit/UIKit.h>

@class MWFeedItem;

@interface NewsTableViewCell : UITableViewCell

+ (CGRect)     defaultCellFrame;
+ (CGFloat)    inset;
+ (CGSize)     bigImageSize;
+ (CGSize)     defaultImageSize;
+ (NSString *) cellReuseIdentifier;

+ (NSString *) authorLabelFontName;
+ (NSString *) titleLabelFontName;
+ (NSString *) textLabelFontName;
+ (NSString *) dateLabelFontName;

+ (CGFloat) calculateCellHeightForData : (MWFeedItem *) data imageOnTheRight : (BOOL) right;
+ (CGFloat) calculateCellHeightForText : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right;
+ (CGFloat) calculateCellHeightWithText : (NSString *) cellText image : (UIImage *) image;


- (void) setCellData : (MWFeedItem *) data imageOnTheRight : (BOOL) right;
- (void) setCellData : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right;
- (void) setCellData : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right date : (NSDate *) date;
//For the bulletin table.
- (void) setTitle : (NSString *) cellText image : (UIImage *) image;

@property (nonatomic, retain) UILabel *author;
@property (nonatomic, retain) UILabel *date;
@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain) UILabel *text;

@property (nonatomic, retain) UIImageView *imageView;
@property (nonatomic, assign) CGFloat      desiredHeight;

@end
