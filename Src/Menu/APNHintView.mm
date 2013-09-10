#import <cassert>

#import "APNHintView.h"

@implementation APNHintView {
   NSString *text;
   UIFont *customFont;
}

@synthesize count;

//________________________________________________________________________________________
- (id) initWithFrame : (CGRect) frame
{
   if (self = [super initWithFrame : frame]) {
      self.backgroundColor = [UIColor clearColor];
      self.opaque = NO;
      
      customFont = [UIFont fontWithName : @"PTSans-Bold" size : 10.f];
      assert(customFont != nil && "initWithFrame:, failed to create a custom font");
      
      count = 0;
      text = @"!";
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
   [[UIColor yellowColor] setFill];
   [internalCircle fill];

   const CGSize textSize = [text sizeWithFont : customFont];
   const CGRect textRect = CGRectMake(rect.size.width / 2 - textSize.width / 2,
                                      rect.size.height / 2 - textSize.height / 2 - [customFont descender] / 2,
                                      textSize.width, textSize.height);
   [[UIColor blackColor] set];
   [text drawInRect : textRect withFont : customFont];
}

//________________________________________________________________________________________
- (void) setCount : (NSUInteger) aCount
{
   count = aCount;

   if (aCount < 99)
      //Do not draw a text, if number is too big - this view is just a small circle.
      text = [NSString stringWithFormat : @"%u", unsigned(aCount)];
   else
      text = @"!";
}

@end
