//
//  DecoderViewController.m
//  ZXing
//
//  Created by Christian Brunschen on 22/05/2008.
/*
 * Copyright 2008 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "DecoderViewController.h"
#import "Decoder.h"
#import "NSString+HTML.h"
#import "ResultParser.h"
#import "ParsedResult.h"
#import "ResultAction.h"

#import "Database.h"
#import "ArchiveController.h"
#import "Scan.h"
#import "TwoDDecoderResult.h"


@implementation DecoderViewController

@synthesize cameraBarItem;
@synthesize libraryBarItem;
@synthesize savedPhotosBarItem;
@synthesize archiveBarItem;
@synthesize actionBarItem;

@synthesize messageView;
@synthesize imageView;
@synthesize toolbar;

@synthesize decoder;
@synthesize result;
@synthesize actions;

@synthesize resultPointViews;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		// Initialization code
    self.title = @"ZXing";
    
    Decoder *d = [[Decoder alloc] init];
    self.decoder = d;
    d.delegate = self;
    [d release];
    resultPointViews = [[NSMutableArray alloc] init];
	}
	return self;
}

#define FONT_NAME @"TimesNewRomanPSMT"
#define FONT_SIZE 16.0

// Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView {
  [super loadView];
  
  CGRect messageViewFrame = imageView.frame;
  UITextView *mView = [[UITextView alloc] initWithFrame:messageViewFrame];
  mView.backgroundColor = [UIColor darkGrayColor];
  mView.alpha = 0.9;
  mView.editable = false;
  mView.scrollEnabled = true;
  mView.font = [UIFont fontWithName:FONT_NAME size:FONT_SIZE];
  mView.autoresizingMask = UIViewAutoresizingFlexibleHeight | 
                           UIViewAutoresizingFlexibleWidth |
                           UIViewAutoresizingFlexibleTopMargin;
  mView.textColor = [UIColor whiteColor];
  mView.textAlignment = UITextAlignmentLeft;
  self.messageView = mView;
  [mView release];
  
  [self.view addSubview:self.messageView];
  [self updateToolbar];
  [self showMessage:NSLocalizedString(@"Please take or choose a picture containing a barcode", @"")];
}

- (void) updateToolbar {
  self.cameraBarItem.enabled = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
  self.savedPhotosBarItem.enabled = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
  self.libraryBarItem.enabled = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
  self.archiveBarItem.enabled = true;
  self.actionBarItem.enabled = (self.result != nil) && ([self.result actions] != nil) && ([self.result actions].count > 0);
}


// If you need to do additional setup after loading the view, override viewDidLoad.
- (void)viewDidLoad {
  [super viewDidLoad];
}


- (void)clearImageView {
  imageView.image = nil;
  for (UIView *view in resultPointViews) {
    [view removeFromSuperview];
  }
  [resultPointViews removeAllObjects];
}

- (void)pickAndDecodeFromSource:(UIImagePickerControllerSourceType) sourceType {
  self.result = nil;
  [self clearImageView];
  // Create the Image Picker
  if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
    UIImagePickerController* picker = [[UIImagePickerController alloc] init];
    picker.sourceType = sourceType;
    picker.delegate = self;
    picker.allowsImageEditing = YES; // [[NSUserDefaults standardUserDefaults] boolForKey:@"allowEditing"];
    
    // Picker is displayed asynchronously.
    [self presentModalViewController:picker animated:YES];
  } else {
    NSLog(@"Attempted to pick an image with illegal source type '%d'", sourceType);
  }
}

- (IBAction)pickAndDecode:(id) sender {
  UIImagePickerControllerSourceType sourceType;
  int i = [sender tag];
  
  switch (i) {
    case 0: sourceType = UIImagePickerControllerSourceTypeCamera; break;
    case 1: sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum; break;
    case 2: sourceType = UIImagePickerControllerSourceTypePhotoLibrary; break;
    default: sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
  }
  [self pickAndDecodeFromSource:sourceType];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

- (void)dealloc {
  [decoder release];
  [self clearImageView];
  [imageView release];
  [actionBarItem release];
  [cameraBarItem release];
  [libraryBarItem release];
  [savedPhotosBarItem release];
  [archiveBarItem release];
  [toolbar release];
  [actions dealloc];
  [resultPointViews dealloc];
  
	[super dealloc];
}

- (void)showMessage:(NSString *)message {
#ifdef DEBUG
  NSLog(@"Showing message '%@'", message);
#endif
  
  CGSize maxSize = imageView.bounds.size;
  CGSize size = [message sizeWithFont:messageView.font constrainedToSize:maxSize lineBreakMode:UILineBreakModeWordWrap];
  float height = 20.0 + fmin(100.0, size.height);

  CGRect messageFrame = imageView.bounds;
  messageFrame.origin.y = CGRectGetMaxY(messageFrame) - height;
  messageFrame.size.height = height;
  self.messageView.text = message;
  [self.messageView setFrame:messageFrame];
}

// DecoderDelegate methods

- (void)decoder:(Decoder *)decoder willDecodeImage:(UIImage *)image {
  [self clearImageView];
  [self.imageView setImage:image];
  [self showMessage:[NSString stringWithFormat:NSLocalizedString(@"Decoding image (%.0fx%.0f) ...", @"shown while image is decoding"), image.size.width, image.size.height]];
}

- (void)decoder:(Decoder *)decoder 
  decodingImage:(UIImage *)image 
    usingSubset:(UIImage *)subset
       progress:(NSString *)message {
  [self clearImageView];
  [self.imageView setImage:subset];
  [self showMessage:message];
}

- (void)presentResultForString:(NSString *)resultString {
  self.result = [ResultParser parsedResultForString:resultString];
  [self showMessage:[self.result stringForDisplay]];
  self.actions = self.result.actions;
#ifdef DEBUG
  NSLog(@"result has %d actions", actions ? 0 : actions.count);
#endif
  [self updateToolbar];
} 

- (void)presentResultPoints:(NSArray *)resultPoints 
                   forImage:(UIImage *)image
                usingSubset:(UIImage *)subset {
  // simply add the points to the image view
  imageView.image = subset;
  for (NSValue *pointValue in resultPoints) {
    [imageView addResultPoint:[pointValue CGPointValue]];
  }
}

- (void)decoder:(Decoder *)decoder didDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset withResult:(TwoDDecoderResult *)twoDResult {
  [self presentResultForString:twoDResult.text];
  
  [self presentResultPoints:twoDResult.points forImage:image usingSubset:subset];
  
  // save the scan to the shared database
  [[Database sharedDatabase] addScanWithText:twoDResult.text];
  
  [self performResultAction:self];
}

- (void)decoder:(Decoder *)decoder failedToDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset reason:(NSString *)reason {
  [self showMessage:reason];
  [self updateToolbar];
}


- (void)willAnimateFirstHalfOfRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  [super willAnimateFirstHalfOfRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
  
  if (imageView.image) {
    /*
    CGRect viewBounds = imageView.bounds;
    CGSize imageSize = imageView.image.size;
    float scale = fmin(viewBounds.size.width / imageSize.width,
                       viewBounds.size.height / imageSize.height);
    float xOffset = (viewBounds.size.width - scale * imageSize.width) / 2.0;
    float yOffset = (viewBounds.size.height - scale * imageSize.height) / 2.0;
     */
    
    for (UIView *view in resultPointViews) {
      view.alpha = 0.0;
    }
  }  
}

- (void)willAnimateSecondHalfOfRotationFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation duration:(NSTimeInterval)duration {
  [super willAnimateSecondHalfOfRotationFromInterfaceOrientation:fromInterfaceOrientation duration:duration];

  if (imageView.image) {
    /*
    CGRect viewBounds = imageView.bounds;
    CGSize imageSize = imageView.image.size;
    float scale = fmin(viewBounds.size.width / imageSize.width,
                       viewBounds.size.height / imageSize.height);
    float xOffset = (viewBounds.size.width - scale * imageSize.width) / 2.0;
    float yOffset = (viewBounds.size.height - scale * imageSize.height) / 2.0;
     */
    
    for (UIView *view in resultPointViews) {
      view.alpha = 1.0;
    }
  }  
}

// UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingImage:(UIImage *)image
                  editingInfo:(NSDictionary *)editingInfo
{
  UIImage *imageToDecode = image;
#ifdef DEBUG
  NSLog(@"picked image size = (%f, %f)", image.size.width, image.size.height);
#endif
  if (editingInfo) {
    UIImage *originalImage = [editingInfo objectForKey:UIImagePickerControllerOriginalImage];
    if (originalImage) {
#ifdef DEBUG
      NSLog(@"original image size = (%f, %f)", originalImage.size.width, originalImage.size.height);
#endif
      NSValue *cropRectValue = [editingInfo objectForKey:UIImagePickerControllerCropRect];
      if (cropRectValue) {
        CGRect cropRect = [cropRectValue CGRectValue];
#ifdef DEBUG
        NSLog(@"crop rect = (%f, %f) x (%f, %f)", CGRectGetMinX(cropRect), CGRectGetMinY(cropRect), CGRectGetWidth(cropRect), CGRectGetHeight(cropRect));
#endif
        UIGraphicsBeginImageContext(cropRect.size);
        
        [originalImage drawAtPoint:CGPointMake(-CGRectGetMinX(cropRect),
                                               -CGRectGetMinY(cropRect))];
        
        imageToDecode = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
      }
    }
  }
  
  [[picker parentViewController] dismissModalViewControllerAnimated:YES];
  [imageToDecode retain];
  [picker release];
  [self.decoder decodeImage:imageToDecode];
  [imageToDecode release];
  [self updateToolbar];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
  [picker dismissModalViewControllerAnimated:YES];
  [picker release];
  [self updateToolbar];
}

- (void)navigationController:(UINavigationController *)navigationController 
       didShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
  // no-op
}

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController 
                    animated:(BOOL)animated {
  // no-op
}

- (void)performAction:(ResultAction *)action {
  [action performActionWithController:self shouldConfirm:NO];
}

- (void)confirmAndPerformAction:(ResultAction *)action {
  [action performActionWithController:self shouldConfirm:YES];
}


- (IBAction)performResultAction:(id)sender {
  if (self.result == nil) {
    NSLog(@"no result to perform an action on!");
    return;
  }
  
  if (self.actions == nil || self.actions.count == 0) {
    NSLog(@"result has no actions to perform!");
    return;
  }
  
  if (self.actions.count == 1) {
    ResultAction *action = [self.actions lastObject];
#ifdef DEBUG
    NSLog(@"Result has the single action, (%@)  '%@', performing it",
          NSStringFromClass([action class]), [action title]);
#endif
    [self performSelector:@selector(confirmAndPerformAction:) 
                 withObject:action 
                 afterDelay:0.0];
  } else {
#ifdef DEBUG
    NSLog(@"Result has multiple actions, popping up an action sheet");
#endif
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithFrame:self.view.bounds];
        
    for (ResultAction *action in self.actions) {
      [actionSheet addButtonWithTitle:[action title]];
    }
    
    int cancelIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
    actionSheet.cancelButtonIndex = cancelIndex;
    
    actionSheet.delegate = self;
    
    [actionSheet showFromToolbar:self.toolbar];
  }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex < self.actions.count) {
    int actionIndex = buttonIndex;
    ResultAction *action = [self.actions objectAtIndex:actionIndex];
    [self performSelector:@selector(performAction:) 
                 withObject:action 
                 afterDelay:0.0];
  }
}

- (IBAction)showArchive:(id)sender {
  ArchiveController *archiveController = [[ArchiveController alloc] initWithDecoderViewController:self];
  [[self navigationController] pushViewController:archiveController animated:true];
  [archiveController release];
}

- (void)showScan:(Scan *)scan {
  [self clearImageView];
  [self presentResultForString:scan.text];
  [[self navigationController] popToViewController:self animated:YES];
}

@end