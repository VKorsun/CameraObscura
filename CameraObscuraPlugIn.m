//
//  CameraObscuraPlugIn.m
//  CameraObscura
//
//  Created by jpld on 07 Sept 2009.
//  Copyright (c) 2009 __MyCompanyName__. All rights reserved.
//

#import "CameraObscuraPlugIn.h"
#import "CameraObscuraPlugInViewController.h"


#define COLocalizedString(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:(nil)]

static NSString* _COExecutionEnabledObservationContext = @"_COExecutionEnabledObservationContext";
static NSString* _COCameraObservationContext = @"_COCameraObservationContext";


// WORKAROUND - naming violation for cocoa memory management
@interface QCPlugIn(CameraObscuraAdditions)
- (QCPlugInViewController*)createViewController NS_RETURNS_RETAINED;
@end

@interface ICDevice(CameraObscuraAdditions)
- (BOOL)canTakePictures;
- (BOOL)canDeleteOneFile;
@end
@implementation ICDevice(CameraObscuraAdditions)
- (BOOL)canTakePictures {
    return [self.capabilities containsObject:ICCameraDeviceCanTakePicture];
}
- (BOOL)canDeleteOneFile {
    return [self.capabilities containsObject:ICCameraDeviceCanDeleteOneFile];
}
@end


@interface CameraObscuraPlugIn()
@property (nonatomic, getter=isExecutionEnabled) BOOL executionEnabled;
@property (nonatomic, readwrite, assign) ICDeviceBrowser* deviceBrowser;
- (void)_setupObservation;
- (void)_invalidateObservation;
- (void)_cleanUpDeviceBrowser;
- (void)_cleanUpCamera;
- (void)_didDownloadFile:(ICCameraFile*)file error:(NSError*)error options:(NSDictionary*)options contextInfo:(void*)contextInfo;
- (void)_didReadData:(NSData*)data fromFile:(ICCameraFile*)file error:(NSError*)error contextInfo:(void*)contextInfo;
@end

@implementation CameraObscuraPlugIn

@dynamic inputCaptureSignal, outputImage, outputDoneSignal;
@synthesize executionEnabled = _isExecutionEnabled, deviceBrowser = _deviceBrowser, camera = _camera;

+ (NSDictionary*)attributes {
	return [NSDictionary dictionaryWithObjectsAndKeys:COLocalizedString(@"kQCPlugIn_Name", NULL), QCPlugInAttributeNameKey, COLocalizedString(@"kQCPlugIn_Description", NULL), QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*)attributesForPropertyPortWithKey:(NSString*)key {
    // TODO - localize?
    if ([key isEqualToString:@"inputCaptureSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Capture Signal", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputDoneSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Done Signal", QCPortAttributeNameKey, nil];
	return nil;
}

+ (QCPlugInExecutionMode)executionMode {
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode)timeMode {
	return kQCPlugInTimeModeNone;
}

+ (NSArray*)plugInKeys {
    return [NSArray arrayWithObjects:nil];
}

#pragma mark -

- (id)init {
    self = [super init];
	if (self) {
        [self _setupObservation];

        self.deviceBrowser = [[ICDeviceBrowser alloc] init];
        self.deviceBrowser.delegate = self;
        self.deviceBrowser.browsedDeviceTypeMask = ICDeviceLocationTypeMaskLocal | ICDeviceTypeMaskCamera;
        [self.deviceBrowser start];
    }
	return self;
}

- (void)finalize {
    [self _invalidateObservation];

    [self _cleanUpDeviceBrowser];
    [self _cleanUpCamera];

	[super finalize];
}

- (void)dealloc {
    [self _invalidateObservation];

    [self _cleanUpDeviceBrowser];
    [self _cleanUpCamera];

	[super dealloc];
}

#pragma mark -

- (id)serializedValueForKey:(NSString*)key {
	/*
	Provide custom serialization for the plug-in internal settings that are not values complying to the <NSCoding> protocol.
	The return object must be nil or a PList compatible i.e. NSString, NSNumber, NSDate, NSData, NSArray or NSDictionary.
	*/

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - camera

	return [super serializedValueForKey:key];
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString*)key {
	/*
	Provide deserialization for the plug-in internal settings that were custom serialized in -serializedValueForKey.
	Deserialize the value, then call [self setValue:value forKey:key] to set the corresponding internal setting of the plug-in instance to that deserialized value.
	*/

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - camera

	[super setSerializedValue:serializedValue forKey:key];
}

- (QCPlugInViewController*)createViewController {
	return [[CameraObscuraPlugInViewController alloc] initWithPlugIn:self viewNibName:@"Settings"];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if (context == _COExecutionEnabledObservationContext) {
        if (self.isExecutionEnabled && self.camera && !self.camera.hasOpenSession) {
            NSLog(@"opening %@", self.camera.name);
            [self.camera requestOpenSession];
        } else if (!self.isExecutionEnabled && self.camera && self.camera.hasOpenSession) {
            NSLog(@"closing %@", self.camera.name);
            [self.camera requestCloseSession];
        }
    } else if (context == _COCameraObservationContext) {
        if (!self.camera)
            return;
        if ([(NSNumber*)[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
            if (self.camera.hasOpenSession) {
                NSLog(@"closing %@", self.camera.name);
                [self.camera requestCloseSession];                
            }
            self.camera.delegate = nil;                
        } else {
            self.camera.delegate = self;
            if (self.isExecutionEnabled) {
                NSLog(@"opening %@", self.camera.name);
                [self.camera requestOpenSession];
            }            
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark EXECUTION

- (BOOL)startExecution:(id<QCPlugInContext>)context {
    /*
    Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
    Return NO in case of fatal failure (this will prevent rendering of the composition to start).
    */

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - start device browser?

    return YES;
}

- (void)enableExecution:(id<QCPlugInContext>)context {
    /*
    Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
    */

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    self.executionEnabled = YES;
}

- (BOOL)execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments {
    // assign outputs
    if (_captureDoneChanged) {
        self.outputDoneSignal = _isCaptureDone;
        _captureDoneChanged = _isCaptureDone;
        _isCaptureDone = NO;
    }
    // TODO - assign self.outputImage if downloaded image is available

    // only process input on the rising edge
    if (!([self didValueForInputKeyChange:@"inputCaptureSignal"] && self.inputCaptureSignal))
        return YES;

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (!self.camera || !self.camera.hasOpenSession)
        return YES;

    // TODO - could offer a blocking synchronous execution mode

    // TODO - need to make sure the device is ready first?
    NSLog(@"taking picture on %@", self.camera.name);
    [self.camera requestTakePicture];

    return YES;
}

- (void)disableExecution:(id<QCPlugInContext>)context {
    /*
    Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
    */

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    self.executionEnabled = NO;
}

- (void)stopExecution:(id<QCPlugInContext>)context {
    /*
    Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
    */

    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - stop device browser?
}

#pragma mark -
#pragma mark DEVICE BROWSER DELEGATE

- (void)deviceBrowser:(ICDeviceBrowser*)browser didAddDevice:(ICDevice*)device moreComing:(BOOL)moreComing {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (self.camera)
        return;
    if (![device canTakePictures]) {
        // TODO - change message to include PTP / PC Connection info and link?
        NSLog(@"%@ NOT CAPABLE OF TETHERED SHOOTING", device.name);
        return;
    }

    // TODO - later, selection should be driven by the ui
    NSLog(@"%@", device);
    self.camera = (ICCameraDevice*)device;
}

- (void)deviceBrowser:(ICDeviceBrowser*)browser didRemoveDevice:(ICDevice*)device moreGoing:(BOOL)moreGoing {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (device != self.camera)
        return;

    [self didRemoveDevice:device];
}

- (void)deviceBrowser:(ICDeviceBrowser*)browser deviceDidChangeName:(ICDevice*)device {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - update display name in popup if visible
}

- (void)deviceBrowserDidEnumerateLocalDevices:(ICDeviceBrowser*)browser {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

#pragma mark -
#pragma mark DEVICE BROWSER DELEGATE

- (void)didRemoveDevice:(ICDevice*)device {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (device != self.camera)
        return;

    NSLog(@"removed %@", self.camera.name);

    [self _cleanUpCamera];
    // TODO - grab another camera?
}

- (void)device:(ICDevice*)device didOpenSessionWithError:(NSError*)error {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (error == NULL || device != self.camera)
        return;

    NSLog(@"failed to open %@", self.camera.name);

    [self _cleanUpCamera];
    // TODO - go cry in the corner?
}

- (void)deviceDidBecomeReady:(ICDevice*)device {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (device != self.camera)
        return;

    NSLog(@"ready %@", self.camera.name);
}

- (void)device:(ICDevice*)device didCloseSessionWithError:(NSError*)error {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void)deviceDidChangeSharingState:(ICDevice*)device {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void)device:(ICDevice*)device didReceiveStatusInformation:(NSDictionary*)status {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void)device:(ICDevice*)device didEncounterError:(NSError*)error {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void)device:(ICDevice*)device didReceiveButtonPress:(NSString*)buttonType {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

#pragma mark -
#pragma mark DEVICE DELEGATE

- (void)cameraDevice:(ICCameraDevice*)camera didAddItem:(ICCameraItem*)item {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    if (!UTTypeConformsTo((CFStringRef)(item.UTI), kUTTypeImage))
        return;

    ICCameraFile* file = (ICCameraFile*)item;

    // TODO - compare performance / complexity of download vs in-memory read
#define DOWNLOAD_IAMGE 1
#if DOWNLOAD_IAMGE
    NSLog(@"downloading image from %@", self.camera.name);
    // TODO - use input to determine download location
    NSMutableDictionary* options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSURL fileURLWithPath:[@"~/Desktop/" stringByExpandingTildeInPath]], ICDownloadsDirectoryURL, nil];
    // TODO - use setting to determine if the image should be removed and plan according around !camera.canDeleteOneFile
    if (camera.canDeleteOneFile && YES)
        [options setObject:[NSNumber numberWithBool:YES] forKey:ICDeleteAfterSuccessfulDownload];
    [camera requestDownloadFile:file options:options downloadDelegate:self didDownloadSelector:@selector(_didDownloadFile:error:options:contextInfo:) contextInfo:NULL];
    [options release];
#else
    NSLog(@"reading image from %@", self.camera.name);
    [camera requestReadDataFromFile:file atOffset:0 length:file.fileSize readDelegate:self didReadDataSelector:@selector(_didReadData:fromFile:error:contextInfo:) contextInfo:NULL];
#endif
}

#pragma mark -
#pragma mark PRIVATE

- (void)_setupObservation {
    [self addObserver:self forKeyPath:@"executionEnabled" options:0 context:_COExecutionEnabledObservationContext];
    [self addObserver:self forKeyPath:@"camera" options:NSKeyValueObservingOptionPrior context:_COCameraObservationContext];
}

- (void)_invalidateObservation {
    [self removeObserver:self forKeyPath:@"executionEnabled"];
    [self removeObserver:self forKeyPath:@"camera"];
}

- (void)_cleanUpDeviceBrowser {
    [self.deviceBrowser stop];
    self.deviceBrowser.delegate = nil;
    [_deviceBrowser release];
    _deviceBrowser = nil;
}

- (void)_cleanUpCamera {
    if (self.camera.hasOpenSession) {
        NSLog(@"closing %@", self.camera.name);
        [self.camera requestCloseSession];
    }
    self.camera.delegate = nil;
    self.camera = nil;
}

- (void)_didDownloadFile:(ICCameraFile*)file error:(NSError*)error options:(NSDictionary*)options contextInfo:(void*)contextInfo {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - handle !self.executionEnabled

    if (error != NULL) {
        NSLog(@"FAILED TO DOWNLOAD IMAGE - %@", error);
        return;
    }

    _isCaptureDone = YES;
    _captureDoneChanged = YES;

    NSLog(@"download of '%@' complete", [options objectForKey:ICSavedFilename]);
}

- (void)_didReadData:(NSData*)data fromFile:(ICCameraFile*)file error:(NSError*)error contextInfo:(void*)contextInfo {
    NSLog(@"-[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));

    // TODO - handle !self.executionEnabled

    if (error != NULL) {
        NSLog(@"FAILED TO READ IMAGE - %@", error);
        return;
    }

    _isCaptureDone = YES;
    _captureDoneChanged = YES;

    NSLog(@"read of '%@' complete", file.name);

    // TODO - do something with file.orientation
    // TODO - do something with returned data!
    // CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    // CGImageRef image = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
    // CGDataProviderRelease(provider);
    // CGImageRelease(image);

    // TODO - likely delete original [file.device requestDeleteFiles:[NSArray arrayWithObjects:file, nil]];    
    // if (file.device.canDeleteOneFile && YES) {
    //     NSArray* files = [[NSArray alloc] initWithObjects:file];
    //     [file.device requestDeleteFiles:files];
    //     [files release];
    // }
}

@end
