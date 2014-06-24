/**
 * Camera Roll PhoneGap Plugin. 
 *
 * Reads photos from the iOS Camera Roll.
 *
 * Copyright 2013 Drifty Co.
 * http://drifty.com/
 *
 * See LICENSE in this project for licensing info.
 */

#import "IonicCameraRoll.h"
#import <AssetsLibrary/ALAssetRepresentation.h>
#import <CoreLocation/CoreLocation.h>

#define CDV_PHOTO_PREFIX @"cdv_photo_"

@implementation IonicCameraRoll

  + (ALAssetsLibrary *)defaultAssetsLibrary {
    static dispatch_once_t pred = 0;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&pred, ^{
      library = [[ALAssetsLibrary alloc] init];
    });

    // TODO: Dealloc this later?
    return library;
  }
  
/**
 * Get all the photos in the library.
 *
 * TODO: This should support block-type reading with a set of images
 */
- (void)getPhotos:(CDVInvokedUrlCommand*)command
{
  
  // Grab the asset library
  ALAssetsLibrary *library = [IonicCameraRoll defaultAssetsLibrary];
  
  // Run a background job
  [self.commandDelegate runInBackground:^{
    
    //キュー
      NSOperationQueue *opQueue = [[NSOperationQueue alloc] init];
      [opQueue setMaxConcurrentOperationCount:4];
      
    // Enumerate all of the group saved photos, which is our Camera Roll on iOS
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
      
      // When there are no more images, the group will be nil
      if(group == nil) {
        // Send a null response to indicate the end of photostreaming
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:nil];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      
      } else {
        
        // Enumarate this group of images
        
        [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {

            
            CDVPluginResult *pluginResult = nil;
            
            if(result == nil){
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:nil];
                [pluginResult setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                return;
            }
            
            NSOperation *op = [NSBlockOperation blockOperationWithBlock:^{

                CDVPluginResult *pluginResult = nil;
                
                ALAssetRepresentation *rep = [result defaultRepresentation];
                
                NSURL *assetUrl = [result valueForProperty:ALAssetPropertyAssetURL];
                
                //UIImage *dispImg = [UIImage imageWithCGImage:[rep fullScreenImage]]; //heavy
                UIImage *thumbImg = [UIImage imageWithCGImage:[result thumbnail]];
                NSString *thumbDataUrl = [UIImageJPEGRepresentation(thumbImg, 0.8) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
                
                CGSize size = [rep dimensions];
                NSDate *date = [result valueForProperty:ALAssetPropertyDate];
                NSString *srcFilename = [rep filename];
                
                
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                NSString *dateStr = [df stringFromDate:date];
                NSString *widthStr = [NSString stringWithFormat:@"%g", size.width];
                NSString *heightStr = [NSString stringWithFormat:@"%g", size.height];
         
                NSDictionary * res = [NSDictionary dictionaryWithObjectsAndKeys:
                                      assetUrl.absoluteString, @"assetUrl",
                                      thumbDataUrl, @"thumbDataUrl",
                                      dateStr, @"date",
                                      srcFilename, @"filename",
                                      widthStr, @"width",
                                      heightStr, @"height",
                                      nil];
                
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:res];
                
                [pluginResult setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
            [opQueue addOperation:op];
            
        }];
      }
    } failureBlock:^(NSError *error) {
      // Ruh-roh, something bad happened.
      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
      
      [opQueue waitUntilAllOperationsAreFinished];
  }];

}

- (void)getFullScreenImage:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getFullScreenImage");
    NSURL* assetUrl = [NSURL URLWithString:[command.arguments objectAtIndex:0]];
    
    //NSLog(assetUrl.absoluteString);
    
    // Grab the asset library
    ALAssetsLibrary *library = [IonicCameraRoll defaultAssetsLibrary];
    
    
    [library assetForURL:assetUrl resultBlock:^(ALAsset *asset) {
        CDVPluginResult *pluginResult = nil;
        
        UIImage *dispImg = [UIImage imageWithCGImage:[[asset defaultRepresentation ] fullScreenImage]];
        
        //copy
        NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];
        NSFileManager* fileMgr = [[NSFileManager alloc] init];
        NSString *dispPath = nil;
        do {
            NSString *uuid = [[NSUUID UUID] UUIDString];
            
            dispPath = [NSString stringWithFormat:@"%@/%@disp_%@.%@", docsPath, CDV_PHOTO_PREFIX, uuid, @"jpg"];
        } while ([fileMgr fileExistsAtPath:dispPath]);
        
        //save disp
        NSError* err = nil;
        if(![UIImageJPEGRepresentation(dispImg, 0.8) writeToFile:dispPath options:NSAtomicWrite error:&err]){
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
        }
        
        NSURL *dispUrl = [NSURL fileURLWithPath:dispPath];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:dispUrl.absoluteString];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        
    } failureBlock:^(NSError *error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getOriginalImage:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getOriginalImage");
    NSURL* assetUrl = [NSURL URLWithString:[command.arguments objectAtIndex:0]];
    
    //NSLog(assetUrl.absoluteString);
    
    // Grab the asset library
    ALAssetsLibrary *library = [IonicCameraRoll defaultAssetsLibrary];
    
    
    [library assetForURL:assetUrl resultBlock:^(ALAsset *asset) {
        CDVPluginResult *pluginResult = nil;
        
        UIImage *orgImg = [UIImage imageWithCGImage:[[asset defaultRepresentation ] fullResolutionImage]];
        
        NSString *orgDataUrl = [UIImageJPEGRepresentation(orgImg, 0.9) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:orgDataUrl];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        
        
    } failureBlock:^(NSError *error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)cleanup:(CDVInvokedUrlCommand*)command
{
    // empty the tmp directory
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSError* err = nil;
    BOOL hasErrors = NO;
    
    // clear contents of NSTemporaryDirectory
    NSString* tempDirectoryPath = NSTemporaryDirectory();
    NSDirectoryEnumerator* directoryEnumerator = [fileMgr enumeratorAtPath:tempDirectoryPath];
    NSString* fileName = nil;
    BOOL result;
    
    while ((fileName = [directoryEnumerator nextObject])) {
        // only delete the files we created
        if (![fileName hasPrefix:CDV_PHOTO_PREFIX]) {
            continue;
        }
        NSString* filePath = [tempDirectoryPath stringByAppendingPathComponent:fileName];
        result = [fileMgr removeItemAtPath:filePath error:&err];
        if (!result && err) {
            NSLog(@"Failed to delete: %@ (error: %@)", filePath, err);
            hasErrors = YES;
        }
    }
    
    CDVPluginResult* pluginResult;
    if (hasErrors) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:@"One or more files failed to be deleted."];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

@end

