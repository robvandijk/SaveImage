#import "SaveImage.h"
#import <Cordova/CDV.h>
#import <Photos/Photos.h>

@implementation SaveImage
@synthesize callbackId;

- (void)saveImageToGallery:(CDVInvokedUrlCommand*)command {
	[self.commandDelegate runInBackground:^{
	    self.callbackId = command.callbackId;

		NSString *imagePath = [command.arguments objectAtIndex:0];
		NSString *album = [command.arguments objectAtIndex:1];

        NSLog(@"saveImageToGallery name: %@ to album: %@", imagePath, album);

        [self insertImage:imagePath intoAlbumNamed: album];
	}];
}

- (void)returnSuccess:(NSString *)imagePath {
    NSString *fullImagePath = [@"file://" stringByAppendingPathComponent : imagePath];
    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString : fullImagePath];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult : pluginResult callbackId : callbackId];
}

- (void)returnError:(NSString *)imagePath {
    imagePath = [imagePath stringByAppendingString : @" - error writing image to documents folder"];
    CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus : CDVCommandStatus_ERROR messageAsString : imagePath];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult : pluginResult callbackId : callbackId];
}

- (void)insertImage:(NSString *)imagePath intoAlbumNamed:(NSString *)albumName {
    //Fetch a collection in the photos library that has the title "albumNmame"
    PHAssetCollection *collection = [self fetchAssetCollectionWithAlbumName: albumName];

    if (collection == nil) {
        //If we were unable to find a collection named "albumName" we'll create it before inserting the image
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle: albumName];
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (error != nil) {
                NSLog(@"Error inserting image into album: %@", error.localizedDescription);
            }

            if (success) {
                //Fetch the newly created collection (which we *assume* exists here)
                PHAssetCollection *newCollection = [self fetchAssetCollectionWithAlbumName:albumName];
                [self insertImage:imagePath intoAssetCollection: newCollection];
            } else {
                [self returnError:imagePath];
            }
        }];
    } else {
        //If we found the existing AssetCollection with the title "albumName", insert into it
        [self insertImage:imagePath intoAssetCollection: collection];
    }
}

- (PHAssetCollection *)fetchAssetCollectionWithAlbumName:(NSString *)albumName {
    PHFetchOptions *fetchOptions = [PHFetchOptions new];
    //Provide the predicate to match the title of the album.
    fetchOptions.predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"title == '%@'", albumName]];

    //Fetch the album using the fetch option
    PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:fetchOptions];

    //Assuming the album exists and no album shares it's name, it should be the only result fetched
    return fetchResult.firstObject;
}

- (void)insertImage:(NSString *)imagePath intoAssetCollection:(PHAssetCollection *)collection {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{

        //This will request a PHAsset be created for the image
        NSURL *fileURL = [NSURL fileURLWithPath:imagePath];
        PHAssetCreationRequest *creationRequest = [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:fileURL];

        //Create a change request to insert the new PHAsset in the collection
        PHAssetCollectionChangeRequest *request = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection];

        //Add the PHAsset placeholder into the creation request.
        //The placeholder is used because the actual PHAsset hasn't been created yet
        if (request != nil && creationRequest.placeholderForCreatedAsset != nil) {
            [request addAssets: @[creationRequest.placeholderForCreatedAsset]];
        }
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"saveImageToGallery finished");
        if (error != nil) {
            NSLog(@"Error inserting image into asset collection: %@", error.localizedDescription);
            [self returnError:imagePath];
        } else {
            [self returnSuccess:imagePath];
        }
    }];
}

- (void)dealloc {
	[callbackId release];
    [super dealloc];
}

@end
