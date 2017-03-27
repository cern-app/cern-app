#import <cassert>

#import "NSString+StringSizeWithFont.h"
#import "DeviceCheck.h"
#import "APNHintView.h"

@implementation APNHintView {
   NSString *text;
   UIFont *customFont;
}

@synthesize count, delegate;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      self.backgroundColor = [UIColor clearColor];
      customFont = [UIFont fontWithName : @"PTSans-Bold" size : 10.f];
      assert(customFont != nil && "initWithFrame:, failed to create a custom font");
      
      count = 0;
      text = @"!";
      
      UITapGestureRecognizer * const tapGesture = [[UITapGestureRecognizer alloc] initWithTarget : self action : @selector(hintTapped)];
      [self addGestureRecognizer : tapGesture];
   }

   return self;
}

//________________________________________________________________________________________
- (void) drawRect : (CGRect) rect
{
   //The 'rect' is expected to be a square :)
   
   UIBezierPath * const externalCircle = [UIBezierPath bezierPathWithOvalInRect : rect];
   [[UIColor whiteColor] setFill];
   [externalCircle fill];
   const CGRect innerBB = CGRectMake(2.f, 2.f, rect.size.width - 4.f, rect.size.height - 4.f);
   UIBezierPath * const internalCircle = [UIBezierPath bezierPathWithOvalInRect : innerBB];
   [[UIColor redColor] setFill];
   [internalCircle fill];

   const CGSize textSize = [text sizeWithFont7 : customFont];
   
   const CGFloat shift = CernAPP::SystemVersionGreaterThanOrEqualTo(@"7.0") ? 0. : [customFont descender] / 2;
   const CGRect textRect = CGRectMake(rect.size.width / 2 - textSize.width / 2,
                                      rect.size.height / 2 - textSize.height / 2 - shift,
                                      textSize.width, textSize.height);
   [[UIColor whiteColor] set];
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0
   [text drawInRect : textRect withAttributes: @{NSFontAttributeName: customFont}];
#else
   [text drawInRect : textRect withFont : customFont];
#endif
}

//________________________________________________________________________________________
- (void) setCount : (NSUInteger) aCount
{
   if (aCount == count)
      return;

   count = aCount;

   if (aCount < 99)
      //Do not draw a text, if number is too big - this view is just a small circle.
      text = [NSString stringWithFormat : @"%u", unsigned(aCount)];
   else
      text = @"!";
   
   [self setNeedsDisplay];
}

//________________________________________________________________________________________
- (void) hintTapped
{
   if (delegate && [delegate respondsToSelector : @selector(hintTapped)])
      [delegate performSelector : @selector(hintTapped)];
}

@end
