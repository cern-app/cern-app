#import <cassert>

#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "MWFeedItem.h"
#import "FeedCache.h"

namespace CernAPP {

//________________________________________________________________________________________
NSArray *ReadFeedCache(NSString *feedStoreID)
{
   assert(feedStoreID != nil && "ReadFeedCache, parameter 'feedStoreID' is nil");
 
   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
   
   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      NSEntityDescription * const entityDesc = [NSEntityDescription entityForName : @"FeedItem"
                                                           inManagedObjectContext : context];
      NSFetchRequest * const request = [[NSFetchRequest alloc] init];
      [request setEntity : entityDesc];
      
      NSPredicate * const pred = [NSPredicate predicateWithFormat : @"(feedName = %@)", feedStoreID];
      [request setPredicate : pred];

      NSError *error = nil;
      NSArray * const feedCache = [context executeFetchRequest : request error : &error];

      if (!error && feedCache.count)
         return feedCache;
   }

   return nil;
}

//________________________________________________________________________________________
NSMutableArray *ConvertFeedCache(NSArray *feedCache)
{
   assert(feedCache.count != 0 && "ConvertFeedCache, parameter 'feedCache' is either nil or an empty array");

   NSArray *sorted = [feedCache sortedArrayUsingComparator : ^ NSComparisonResult(id a, id b)
                                  {
                                     NSManagedObject * const left = (NSManagedObject *)a;
                                     NSManagedObject * const right = (NSManagedObject *)b;
                                     const NSComparisonResult cmp = [(NSDate *)[left valueForKey : @"itemDate"] compare : (NSDate *)[right valueForKey : @"itemDate"]];
                                     if (cmp == NSOrderedAscending)
                                        return NSOrderedDescending;
                                     else if (cmp == NSOrderedDescending)
                                        return NSOrderedAscending;
                                     return cmp;
                                  }
                     ];

   NSMutableArray * const articles = [[NSMutableArray alloc] init];
   
   for (NSManagedObject *cacheEntry in sorted) {
      MWFeedItem * const newItem = [[MWFeedItem alloc] init];
      newItem.title = (NSString *)[cacheEntry valueForKey : @"itemTitle"];
      newItem.link = (NSString *)[cacheEntry valueForKey : @"itemLink"]; 
      newItem.date = (NSDate *)[cacheEntry valueForKey : @"itemDate"];

      //I do not use the 'summary' on iPhone.
      if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
         newItem.summary = (NSString *)[cacheEntry valueForKey : @"itemSummary"];

      [articles addObject : newItem];
   }

   return articles;
}

//________________________________________________________________________________________
void WriteFeedCache(NSString *feedStoreID, NSArray *feedCache, NSArray *allArticles)
{
   assert(feedStoreID != nil && "WriteFeedCache, parameter 'feedStoreID' is nil");

   if (!allArticles)
      return;

   AppDelegate * const appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;

   if (NSManagedObjectContext * const context = appDelegate.managedObjectContext) {
      BOOL deleted = NO;
   
      if (feedCache && feedCache.count) {
         for (NSManagedObject *obj in feedCache) {
            deleted = YES;
            [context deleteObject : obj];
         }
      } else {
         //We still have to remove the old data for this feed!
         //We're here if controller does not use the cache at the moment,
         //but some data is in db.
         NSEntityDescription * const entityDesc = [NSEntityDescription entityForName : @"FeedItem"
                                                              inManagedObjectContext : context];
         NSFetchRequest * const request = [[NSFetchRequest alloc] init];
         [request setEntity : entityDesc];
      
         NSPredicate * const pred = [NSPredicate predicateWithFormat:@"(feedName = %@)", feedStoreID];
         [request setPredicate : pred];
         [request setIncludesPropertyValues : NO]; //only fetch the managedObjectID

         NSError * error = nil;
         NSArray * const feedItems = [context executeFetchRequest : request error : &error];
         if (!error) {
            for (NSManagedObject * obj in feedItems) {
               [context deleteObject : obj];
               deleted = YES;
            }
         }
      }

      if (deleted) {
         NSError *saveError = nil;
         [context save : &saveError];
         
         //TODO: handle the possible error somehow?
         if (saveError)//Actually, this is really bad :)
            return;
      }

      NSUInteger inserted = 0;
      for (MWFeedItem *feedItem in allArticles) {
         if (!feedItem.title || !feedItem.link)
            continue;
      
         NSManagedObject * const saveFeedItem = [NSEntityDescription insertNewObjectForEntityForName : @"FeedItem"
                                                                    inManagedObjectContext : context];
         if (saveFeedItem) {
            ++inserted;
            [saveFeedItem setValue : feedItem.title forKey : @"itemTitle"];
            [saveFeedItem setValue : feedItem.link forKey : @"itemLink"];
            [saveFeedItem setValue : feedStoreID forKey : @"feedName"];
            if (feedItem.date)
               [saveFeedItem setValue : feedItem.date forKey : @"itemDate"];
            else
               [saveFeedItem setValue : [NSDate date] forKey : @"itemDate"];
            
            NSString *summary = @"";
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && feedItem.summary)
               summary = feedItem.summary;

            [saveFeedItem setValue : summary forKey : @"itemSummary"];
         }
         
         if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && inserted == 40)
            break;
      }

      if (inserted) {
         NSError *error = nil;
         [context save : &error];
      }
   }
}

}
