//

//  RNAlbumsModule.m

//  RNAlbumsModule

//

//  Created by edison on 22/02/2017.

//  Copyright © 2017 edison. All rights reserved.

//



#import "RNAlbumsModule.h"

#import "RNAlbumOptions.h"

#import <Photos/Photos.h>

#import <React/RCTBridge.h>

#import <React/RCTUtils.h>



#pragma mark - declaration

static NSString *albumNameFromType(PHAssetCollectionSubtype type);

static BOOL isAlbumTypeSupported(PHAssetCollectionSubtype type);



@implementation RNAlbumsModule



RCT_EXPORT_MODULE();

NSArray<NSDictionary *> *arrAllAlbums;
NSArray<NSDictionary *> *arrVideosAlbums;
NSArray<NSDictionary *> *arrPhotosAlbums;

RCT_EXPORT_METHOD(getAlbumList:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{

  [RNAlbumsModule authorize:^(BOOL authorized) {

    if (authorized)
    {
        __block NSMutableArray<NSDictionary *> *result = [[NSMutableArray alloc] init];
        
        BOOL isAlbum = [[options valueForKey:@"isAlbum"] boolValue];
        NSString *mediaType = [options valueForKey:@"mediaType"];
        
        if (isAlbum)
        {
            if ([mediaType isEqual:@"all"] && [arrAllAlbums count] > 0) {
                resolve(arrAllAlbums);
                return;
            }
            
            if ([mediaType isEqual:@"photos"] && [arrPhotosAlbums count] > 0) {
                resolve(arrPhotosAlbums);
                return;
            }
            
            if ([mediaType isEqual:@"videos"] && [arrVideosAlbums count] > 0) {
                resolve(arrVideosAlbums);
                return;
            }
            
            NSArray *collectionsFetchResults;
            PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
            PHFetchResult *syncedAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumSyncedAlbum options:nil];
            PHFetchResult *userCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
            
            // Add each PHFetchResult to the array
            collectionsFetchResults = @[smartAlbums, userCollections, syncedAlbums];
            NSMutableArray *localizedTitles = [[NSMutableArray alloc] init];
            for (int i = 0; i < collectionsFetchResults.count; i ++)
            {
                PHFetchResult *fetchResult = collectionsFetchResults[i];
                for (int x = 0; x < fetchResult.count; x++)
                {
                    PHCollection *collection = fetchResult[x];
                    [localizedTitles addObject:collection];
                }
            }
            
            [localizedTitles enumerateObjectsUsingBlock:^(PHAssetCollection * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                PHAssetCollectionSubtype type = [obj assetCollectionSubtype];
                
                BOOL isAdd = true;
                if (type > 300)
                    isAdd=false;
                else {
                    if (@available(iOS 11.0, *)) {
                        if (type == PHAssetCollectionSubtypeSmartAlbumAnimated
                            || type == PHAssetCollectionSubtypeSmartAlbumLongExposures
                            || type == PHAssetCollectionSubtypeSmartAlbumLivePhotos
                            || type == PHAssetCollectionSubtypeSmartAlbumScreenshots) {
                            isAdd = false;
                        }
                    }
                    
                    if(type == PHAssetCollectionSubtypeSmartAlbumTimelapses
                       || type == PHAssetCollectionSubtypeSmartAlbumSlomoVideos
                       || type == PHAssetCollectionSubtypeSmartAlbumRecentlyAdded
                       || type == PHAssetCollectionSubtypeSmartAlbumAllHidden
                       || type == PHAssetCollectionSubtypeSmartAlbumPanoramas)
                        isAdd = false;
                }
                
                if (isAdd)
                {
                    PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
                    fetchOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
                    if ([mediaType caseInsensitiveCompare:@"all"] == NSOrderedSame)
                        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d || mediaType = %d", PHAssetMediaTypeImage, PHAssetMediaTypeVideo];
                    else if ([mediaType caseInsensitiveCompare:@"photos"] == NSOrderedSame)
                        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
                    else if ([mediaType caseInsensitiveCompare:@"videos"] == NSOrderedSame)
                        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
                    
                    PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:obj options:fetchOptions];
                    PHAsset *coverAsset = fetchResult.lastObject;
                    
                    if (coverAsset && fetchResult.count > 0)
                    {
                        NSDictionary *album = @{@"count": @(fetchResult.count),
                                                @"name": obj.localizedTitle,
                                                @"cover": [NSString stringWithFormat:@"ph://%@", coverAsset.localIdentifier] };
                        
                        [result addObject:album];
                    }
                }
                
            }];
            
            NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"count" ascending:NO];
            [result sortUsingDescriptors:@[sd]];
            
            if ([mediaType isEqual:@"all"])
                arrAllAlbums = result;
            else if ([mediaType isEqual:@"photos"])
                arrPhotosAlbums = result;
            else if ([mediaType isEqual:@"videos"])
                arrVideosAlbums = result;
            
            resolve(result);
        } else {
            NSDictionary *album = @{@"count": [NSNumber numberWithInt:0],
                                    @"name": mediaType,
                                    @"cover": @""};
            
            [result addObject:album];
            
            NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"count" ascending:NO];
            [result sortUsingDescriptors:@[sd]];
            
            resolve(result);
        }
    } else {
      NSString *errorMessage = @"Access Photos Permission Denied";
      NSError *error = RCTErrorWithMessage(errorMessage);
      reject(@(error.code), errorMessage, error);
    }
  }];

}



typedef void (^authorizeCompletion)(BOOL);



+ (void)authorize:(authorizeCompletion)completion {

  switch ([PHPhotoLibrary authorizationStatus]) {

    case PHAuthorizationStatusAuthorized: {

      // 已授权

      completion(YES);

      break;

    }

    case PHAuthorizationStatusNotDetermined: {

      // 没有申请过权限，开始申请权限

      [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {

        [RNAlbumsModule authorize:completion];

      }];

      break;

    }

    default: {

      // Restricted or Denied, 没有授权

      completion(NO);

      break;

    }

  }

}



@end



#pragma mark - 



static NSString *albumNameFromType(PHAssetCollectionSubtype type) {

  switch (type) {

    case PHAssetCollectionSubtypeSmartAlbumUserLibrary: return @"UserLibrary";

    case PHAssetCollectionSubtypeSmartAlbumSelfPortraits: return @"SelfPortraits";

    case PHAssetCollectionSubtypeSmartAlbumRecentlyAdded: return @"RecentlyAdded";

    case PHAssetCollectionSubtypeSmartAlbumTimelapses: return @"Timelapses";

    case PHAssetCollectionSubtypeSmartAlbumPanoramas: return @"Panoramas";

    case PHAssetCollectionSubtypeSmartAlbumFavorites: return @"Favorites";

    case PHAssetCollectionSubtypeSmartAlbumScreenshots: return @"Screenshots";

    case PHAssetCollectionSubtypeSmartAlbumBursts: return @"Bursts";

    case PHAssetCollectionSubtypeSmartAlbumVideos: return @"Videos";

    case PHAssetCollectionSubtypeSmartAlbumSlomoVideos: return @"SlomoVideos";

    case PHAssetCollectionSubtypeSmartAlbumDepthEffect: return @"DepthEffect";

    default: return @"null";

  }

}



static BOOL isAlbumTypeSupported(PHAssetCollectionSubtype type) {

  switch (type) {

    case PHAssetCollectionSubtypeSmartAlbumUserLibrary:

    case PHAssetCollectionSubtypeSmartAlbumSelfPortraits:

    case PHAssetCollectionSubtypeSmartAlbumRecentlyAdded:

    case PHAssetCollectionSubtypeSmartAlbumTimelapses:

    case PHAssetCollectionSubtypeSmartAlbumPanoramas:

    case PHAssetCollectionSubtypeSmartAlbumFavorites:

    case PHAssetCollectionSubtypeSmartAlbumScreenshots:

    case PHAssetCollectionSubtypeSmartAlbumBursts:

    case PHAssetCollectionSubtypeSmartAlbumDepthEffect:

    case PHAssetCollectionSubtypeSmartAlbumVideos:

    case PHAssetCollectionSubtypeSmartAlbumGeneric:

      return YES;

    default:

      return NO;

  }

}
