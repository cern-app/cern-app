//Author: Timur Pocheptsov.
//Developed for CERN app.

#import "NSString+StringSizeWithFont.h"
#import "NewsTableViewCell.h"
#import "NSString+HTML.h"
#import "MWFeedItem.h"

//This is a code for a table view controller, which shows author, title, short content, date for
//an every news item.
//It can be used ONLY for iPhone/iPod touch device, for iPad we'll have different approach.

namespace {

//Some hardcoded constants.
const CGFloat cellInset = 10.f;
const CGFloat bigImageSize = 130.f;
const CGFloat defaultImageSize = 80.f;
const CGFloat defaultHeightNoImage = 60.f;
const CGFloat sourceLabelWidthRatio = 0.85;
const CGFloat dateLabelWidthRatio = 0.75;
const CGFloat bulletinCellHeight = cellInset * 2 + defaultImageSize;
const CGFloat bulletinTextHeight = 40.f;

const CGFloat minImageSize = 10.f;//??

//This is for "Author" and "Date" labels.
const CGFloat fixedLabelSize = 15.f;

//________________________________________________________________________________________
CGFloat HeihgtForLinesWithFont(UIFont *font, unsigned nLines)
{
   //This code does some primitive and rough estimation,
   //how many space (vertically) will occupy 'nLines' of text with
   //font 'font'.
   assert(font != nil && "HeightForLineWithFont, font parameter is nil");
   assert(nLines >= 1 && "HeightForLineWithFont, nLines must be >= 1");

   //I can never have such real sizes, 2000 is a really huge width/height.
   const CGFloat hugeW = 2000.f;
   const CGFloat hugeH = 2000.f;

   //Estimate one line height first.
   const CGSize fontSizes = [@"ABCDEFGHIGKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" sizeWithFont7 : font constrainedToSize:CGSizeMake(hugeW, hugeH)];
   
   //Create a test string;
   NSMutableString * const testString = [[NSMutableString alloc] init];
   for (unsigned i = 0; i < nLines; ++i)
      [testString appendString : @"Ambiguity  "];
   
   //Now, size for one line.
   //hugeW and 4 are some hardcoded constants which should definitely work always :)
   const CGSize oneLineSize = [testString sizeWithFont7 : font constrainedToSize:CGSizeMake(hugeW, fontSizes.height + 4)];
   //Now, that I have oneLineSize.width, I can use it again in a constraint:
   const CGSize twoLineSize = [testString sizeWithFont7 : font constrainedToSize: CGSizeMake(oneLineSize.width / nLines, hugeH) lineBreakMode : NSLineBreakByWordWrapping];

   return twoLineSize.height;
}

struct TextGeometry {
   TextGeometry()
      : nLines(1), fontSize(14.f), height(20.f)//Some "default" values.
   {
   }
   TextGeometry(unsigned n, CGFloat f, CGFloat h)
      : nLines(n), fontSize(f), height(h)
   {
   }
   
   unsigned nLines;
   CGFloat fontSize;
   CGFloat height;
};

//________________________________________________________________________________________
TextGeometry PlaceText(NSString *text, CGFloat fixedWidth, NSString *fontName)
{
   //Try to place text as one line with font 14, as two lines with font 14,
   //as two lines with font 12, finally, if it does not fit as two 12, force
   //it into two 12 (cut the remaining part).

   assert(text != nil && "PlaceText, text parameter is nil");
   assert(fixedWidth > 0.f && "PlaceText, fixedWidth parameter must be positive");
   assert(fontName != nil && "PlaceText, fontName parameter is nil");

   //I'll never have such real sizes, so it's really huge.
   const CGFloat hugeH = 2000.f;
   
   UIFont * const font14 = [UIFont fontWithName : fontName size : 14.f];
   assert(font14 != nil && "PlaceText, font initializationi failed");

   const CGFloat twoLineHeight14 = HeihgtForLinesWithFont(font14, 2);  
   const CGSize estimateSize14 = [text sizeWithFont7 : font14 constrainedToSize : CGSizeMake(fixedWidth, hugeH) lineBreakMode : NSLineBreakByWordWrapping];
   
   //Text fits one or two lines?
   if (estimateSize14.height < twoLineHeight14 * 0.75)
      return TextGeometry(1, 14.f, estimateSize14.height);
   if (estimateSize14.height < twoLineHeight14 * 1.25)
      return TextGeometry(2, 14.f, estimateSize14.height);
   
   //Try with font 12.
   UIFont * const font12 = [UIFont fontWithName : fontName size : 12.f];
   const CGFloat twoLineHeight12 = HeihgtForLinesWithFont(font12, 2);
   
   const CGSize estimateSize12 = [text sizeWithFont7 : font12 constrainedToSize : CGSizeMake(fixedWidth, hugeH) lineBreakMode : NSLineBreakByWordWrapping];
   
   //We force text into two lines maximum.
   if (estimateSize12.height < twoLineHeight12 * 0.75)
      return TextGeometry(1, 12.f, estimateSize12.height);

   //Text either fit into 2 lines with font size 12, or we
   //cut it.
   return TextGeometry(2, 12.f, twoLineHeight12);
}

}

@implementation NewsTableViewCell

@synthesize author, date, text, title, imageView, desiredHeight;

//________________________________________________________________________________________
+ (CGRect) defaultCellFrame
{
   return CGRectMake(0., 0., 300., 125.);
}

//________________________________________________________________________________________
+ (CGFloat) inset
{
   return cellInset;
}

//________________________________________________________________________________________
+ (CGSize) bigImageSize
{
   return CGSizeMake(bigImageSize, bigImageSize);
}

//________________________________________________________________________________________
+ (CGSize) defaultImageSize
{
   return CGSizeMake(defaultImageSize, defaultImageSize);
}

//________________________________________________________________________________________
+ (NSString *) authorLabelFontName
{
   return @"Helvetica-Bold";
}

//________________________________________________________________________________________
+ (NSString *) titleLabelFontName
{
//   return @"HelveticaNeue-Bold";
   return @"PT Sans";
}

//________________________________________________________________________________________
+ (NSString *) textLabelFontName
{
   return @"HelveticaNeue-Medium";
}

//________________________________________________________________________________________
+ (NSString *) dateLabelFontName
{
   return @"Helvetica-Bold";
}

//________________________________________________________________________________________
+ (NSString *) cellReuseIdentifier
{
   return @"NewsTableViewCell";
}

//________________________________________________________________________________________
- (void) setImageView
{
   if (!imageView) {
      imageView = [[UIImageView alloc] initWithFrame : CGRectMake(0, 0, defaultImageSize, defaultImageSize)];
      imageView.contentMode = UIViewContentModeScaleAspectFill;
      imageView.clipsToBounds = YES;
      imageView.image = nil;//??
      [self addSubview : imageView];
   }
}

//________________________________________________________________________________________
- (void) setTextLabels
{
   if (!author) {
      author = [[UILabel alloc] initWithFrame : CGRectMake(0., 0., 100., 20.) ];
      author.textColor = [UIColor brownColor];
      author.font = [UIFont fontWithName : [NewsTableViewCell authorLabelFontName] size : 9.f];
      author.backgroundColor = [UIColor clearColor];
      author.clipsToBounds = YES;
      [self addSubview : author];
   }
   
   if (!title) {
      title = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., 100., 20.)];
      title.textColor = [UIColor blackColor];
      title.font = [UIFont fontWithName : [NewsTableViewCell titleLabelFontName] size : 14.f];
      title.backgroundColor = [UIColor clearColor];
      title.clipsToBounds = YES;
      [self addSubview : title];
   }
   
   if (!text) {
      text = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., 100., 20.)];
      text.textColor = [UIColor grayColor];
      text.backgroundColor = [UIColor clearColor];
      text.font = [UIFont fontWithName : [NewsTableViewCell textLabelFontName] size:13.f];
      text.clipsToBounds = YES;
      [self addSubview : text];
   }
   
   if (!date) {
      date = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., 100., 20.)];
      date.backgroundColor = [UIColor clearColor];
      date.textColor = [[UIColor blueColor] colorWithAlphaComponent:0.5];
      date.font = [UIFont fontWithName : [NewsTableViewCell dateLabelFontName] size : 9.f];
      date.clipsToBounds = YES;
      [self addSubview : date];
   }
}

//________________________________________________________________________________________
- (void) awakeFromNib
{
   [super awakeFromNib];

   [self setImageView];
   [self setTextLabels];
   self.selectionStyle = UITableViewCellSelectionStyleGray;
}

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect)frame
{
   if (self = [super initWithFrame : frame]) {
      [self setImageView];
      [self setTextLabels];
      self.selectionStyle = UITableViewCellSelectionStyleGray;
   }
   
   return self;
}

//________________________________________________________________________________________
- (id) initWithStyle : (UITableViewCellStyle) style reuseIdentifier : (NSString *) reuseIdentifier
{
   if (self = [super initWithStyle : style reuseIdentifier : reuseIdentifier]) {
      [self setImageView];
      [self setTextLabels];
      self.selectionStyle = UITableViewCellSelectionStyleGray;
   }
   
   return self;
}

//________________________________________________________________________________________
- (void) setSelected : (BOOL)selected animated : (BOOL)animated
{
   [super setSelected : selected animated : animated];
   // Configure the view for the selected state
}

//________________________________________________________________________________________
- (CGFloat) layoutText : (CGRect) rect
{
   //This function estimates the height.
   
   //Cell has "fixed" parts: two labels - for an author and for a date.
   //Author can be empty, date can be empty, but we always "allocate" space for them.
   //Dynamic part is built from title and text (whatever string is not empty).

   //Now, layout labels, which have non-nil text (dynamic part).
   //Hehe, __weak is just for fun :) Or ...
   __weak UILabel *labelsToLayout[2] = {};
   NSString *fontNames[2] = {};
   TextGeometry geom[2];
   unsigned nLabelsToLayout = 0;

   if (title.text) {
      labelsToLayout[0] = title;
      geom[0] = PlaceText(title.text, rect.size.width, [NewsTableViewCell titleLabelFontName]);
      fontNames[0] = [NewsTableViewCell titleLabelFontName];
      nLabelsToLayout = 1;
   }
   
   if (text.text) {
      labelsToLayout[nLabelsToLayout] = text;
      geom[nLabelsToLayout] = PlaceText(text.text, rect.size.width, [NewsTableViewCell textLabelFontName]);
      fontNames[nLabelsToLayout] = [NewsTableViewCell textLabelFontName];
      ++nLabelsToLayout;
   }

   CGFloat dynamicHeight = 0.f;

   if (nLabelsToLayout) {
      CGFloat currY = cellInset;

      for (unsigned i = 0; i < nLabelsToLayout; ++i)
         dynamicHeight += geom[i].height;
      
      //if dynamicHeight is less then rect.size.height - 2 * cellInset - 2 * fixedLabelSize,
      //I layout these two labels in this area. Otherwise, I simply add dynamicHeiht to the totalHeight.
      if (dynamicHeight < rect.size.height - 2 * cellInset - 2 * fixedLabelSize)
         //Default rect size is enough to place text.
         currY += (rect.size.height - 2 * cellInset - 2 * fixedLabelSize)  / 2  - dynamicHeight / 2;

      for (unsigned i = 0; i < nLabelsToLayout; ++i) {
         UILabel *label = labelsToLayout[i];
         label.numberOfLines = geom[i].nLines;
         label.frame = CGRectMake(rect.origin.x, currY, rect.size.width, geom[i].height);
         label.font = [UIFont fontWithName: fontNames[i] size : geom[i].fontSize];
         currY += geom[i].height;
      }

      if (dynamicHeight < rect.size.height - 2 * cellInset - 2 * fixedLabelSize)
         currY = rect.size.height - cellInset - 2 * fixedLabelSize;//inset and size of "Date" label.

      //Date label here. It's always just 1 line of text and not wider than 3/4 of rect.size.width.
      author.frame = CGRectMake(rect.origin.x, currY, rect.size.width * sourceLabelWidthRatio, fixedLabelSize);
      author.numberOfLines = 1;
      
      currY += fixedLabelSize;
      
      date.frame = CGRectMake(rect.origin.x, currY, rect.size.width * dateLabelWidthRatio, fixedLabelSize);
      date.numberOfLines = 1;
   } else {
      //Date label here. It's always just 1 line of text and not wider than 3/4 of rect.size.width.
      author.frame = CGRectMake(rect.origin.x, rect.size.height - 2 * fixedLabelSize - cellInset, rect.size.width * sourceLabelWidthRatio, fixedLabelSize);
      author.numberOfLines = 1;

      date.frame = CGRectMake(rect.origin.x, rect.size.height - cellInset - fixedLabelSize, rect.size.width * dateLabelWidthRatio, fixedLabelSize);
      date.numberOfLines = 1;
   }

   if (dynamicHeight > rect.size.height - 2 * cellInset - 2 * fixedLabelSize)
      return dynamicHeight + 2 * cellInset + 2 * fixedLabelSize;

   return rect.size.height;
}

//________________________________________________________________________________________
- (void) setCellData : (MWFeedItem *) data imageOnTheRight : (BOOL) right
{
   assert(data && "setCellData:image:imageOnTheRight:, data parameter is nil");

   author.text = data.link && [data.link length] ? data.link : nil;
   title.text = [data.title stringByConvertingHTMLToPlainText];
   //Set summary.
   text.text = nil;//data.summary ? [data.summary stringByConvertingHTMLToPlainText] : nil;

   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat:@"d MMM. yyyy"];
   date.text = [dateFormatter stringFromDate : data.date ? data.date : [NSDate date]];

   UIImage * const image = data.image;
   if (image && image.size.width > minImageSize && image.size.height > minImageSize)
      imageView.image = image;
   else
      imageView.image = nil;

   CGRect cellFrame = self.frame;
   
   if (right && imageView.image) {
      CGRect textRect = CGRectMake(cellInset, 0, cellFrame.size.width - bigImageSize - 2 * cellInset, bigImageSize + 2 * cellInset);//130
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellFrame.size.width - bigImageSize - cellInset, cellFrame.size.height / 2 - bigImageSize / 2, bigImageSize, bigImageSize);
   } else if (imageView.image) {
      CGRect textRect = CGRectMake(defaultImageSize + 2 * cellInset, 0.f, cellFrame.size.width - defaultImageSize - 3 * cellInset, defaultImageSize + 2 * cellInset);
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellInset, cellFrame.size.height / 2 - defaultImageSize / 2, defaultImageSize, defaultImageSize);
   } else {
      CGRect textRect = CGRectMake(cellInset, 0.f, cellFrame.size.width - 2 * cellInset, defaultHeightNoImage);
      cellFrame.size.height = [self layoutText : textRect];
   }

   self.frame = cellFrame;
}

//________________________________________________________________________________________
- (void) setCellData : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right
{
   assert(cellText != nil && "setCellData:source:image:imageOnTheRight:, cellText parameter is nil");
   assert(source != nil && "setCellData:source:image:imageOnTheRight:, source parameter is nil");

   title.text = cellText;
   author.text = source;
 
   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat:@"d MMM. yyyy"];
   date.text = [dateFormatter stringFromDate : [NSDate date]];

   if (image && image.size.width > minImageSize && image.size.height > minImageSize)
      imageView.image = image;
   else
      imageView.image = nil;

   CGRect cellFrame = self.frame;
   
   if (right && imageView.image) {
      CGRect textRect = CGRectMake(cellInset, 0, cellFrame.size.width - bigImageSize - 2 * cellInset, bigImageSize + 2 * cellInset);//130
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellFrame.size.width - bigImageSize - cellInset, cellFrame.size.height / 2 - bigImageSize / 2, bigImageSize, bigImageSize);
   } else if (imageView.image) {
      CGRect textRect = CGRectMake(defaultImageSize + 2 * cellInset, 0.f, cellFrame.size.width - defaultImageSize - 3 * cellInset, defaultImageSize + 2 * cellInset);
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellInset, cellFrame.size.height / 2 - defaultImageSize / 2, defaultImageSize, defaultImageSize);
   } else {
      CGRect textRect = CGRectMake(cellInset, 0.f, cellFrame.size.width - 2 * cellInset, defaultHeightNoImage);
      cellFrame.size.height = [self layoutText : textRect];
   }

   self.frame = cellFrame;
   
   [self setCellData : cellText source : source image : image imageOnTheRight : right date : nil];
}

//________________________________________________________________________________________
- (void) setCellData : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right date : (NSDate *) aDate
{
   assert(cellText != nil && "setCellData:source:image:imageOnTheRight:, cellText parameter is nil");
   assert(source != nil && "setCellData:source:image:imageOnTheRight:, source parameter is nil");

   title.text = cellText;
   author.text = source;
 
   NSDateFormatter * const dateFormatter = [[NSDateFormatter alloc] init];
   [dateFormatter setDateFormat:@"d MMM. yyyy"];
   date.text = [dateFormatter stringFromDate : aDate ? aDate : [NSDate date]];

   if (image && image.size.width > minImageSize && image.size.height > minImageSize)
      imageView.image = image;
   else
      imageView.image = nil;

   CGRect cellFrame = self.frame;
   
   if (right && imageView.image) {
      CGRect textRect = CGRectMake(cellInset, 0, cellFrame.size.width - bigImageSize - 2 * cellInset, bigImageSize + 2 * cellInset);//130
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellFrame.size.width - bigImageSize - cellInset, cellFrame.size.height / 2 - bigImageSize / 2, bigImageSize, bigImageSize);
   } else if (imageView.image) {
      CGRect textRect = CGRectMake(defaultImageSize + 2 * cellInset, 0.f, cellFrame.size.width - defaultImageSize - 3 * cellInset, defaultImageSize + 2 * cellInset);
      cellFrame.size.height = [self layoutText : textRect];
      imageView.frame = CGRectMake(cellInset, cellFrame.size.height / 2 - defaultImageSize / 2, defaultImageSize, defaultImageSize);
   } else {
      CGRect textRect = CGRectMake(cellInset, 0.f, cellFrame.size.width - 2 * cellInset, defaultHeightNoImage);
      cellFrame.size.height = [self layoutText : textRect];
   }

   self.frame = cellFrame;
}

//________________________________________________________________________________________
- (void) setTitle : (NSString *)cellText image : (UIImage *) image
{
   assert(cellText != nil && "setBulletinTitle:, parameter 'cellText' is nil");
   //image can be nil.
   
   if (!title.text.length) {
      UIFont * const font = [UIFont fontWithName : [NewsTableViewCell authorLabelFontName] size : 20.f];
      assert(font != nil && "setTitle:image:, font not found");
      title.font = font;
      title.textAlignment = NSTextAlignmentCenter;
   }
   
   title.text = cellText;
   CGRect cellFrame = self.frame;
   
   if (image && image.size.width > minImageSize && image.size.height > minImageSize)
      imageView.image = image;
   else
      imageView.image = nil;
   
   if (imageView.image) {
      const CGRect textRect = CGRectMake(defaultImageSize + 2 * cellInset,
                                         bulletinCellHeight / 2 - bulletinTextHeight / 2,
                                         cellFrame.size.width - defaultImageSize - 3 * cellInset,
                                         bulletinTextHeight);
      title.frame = textRect;
      imageView.frame = CGRectMake(cellInset,
                                   bulletinCellHeight / 2 - defaultImageSize / 2,
                                   defaultImageSize, defaultImageSize);
   } else {
      const CGRect textRect = CGRectMake(cellInset, bulletinCellHeight / 2 - bulletinTextHeight / 2,
                                         cellFrame.size.width - 2 * cellInset, bulletinTextHeight);
      title.frame = textRect;
   }
}

//________________________________________________________________________________________
+ (CGFloat) calculateCellHeightForData : (MWFeedItem *) data imageOnTheRight : (BOOL) right
{
   assert(data != nil && "calculateCellHeightForData:imageOnTheRight:, data parameter is nil");

   static NewsTableViewCell * const cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];
   [cell setCellData : data imageOnTheRight : right];

   return cell.frame.size.height;
}

//________________________________________________________________________________________
+ (CGFloat) calculateCellHeightForText : (NSString *) cellText source : (NSString *) source image : (UIImage *) image imageOnTheRight : (BOOL) right
{
   assert(cellText != nil && "calculateCellHeightForText:source:image:imageOnTheRight:, cellText parameter is nil");
   assert(source != nil && "calculateCellHeightForText:source:image:imageOnTheRight:, source parameter is nil");
   
   static NewsTableViewCell * const cell = [[NewsTableViewCell alloc] initWithFrame : [NewsTableViewCell defaultCellFrame]];
   [cell setCellData : cellText source : source image : image imageOnTheRight : right];
   
   return cell.frame.size.height;
}

//________________________________________________________________________________________
+ (CGFloat) calculateCellHeightWithText : (NSString *) cellText image : (UIImage *) image
{
#pragma unused(cellText, image)
   return bulletinCellHeight;
}

@end
