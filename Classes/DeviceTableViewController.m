// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "AppDelegate.h"
#import "DeviceTableViewController.h"
#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"

@implementation DeviceTableViewController {
  BOOL _isManualVolumeChange;
  UISlider *_volumeSlider;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // Return the number of sections - section 0 is main list, section 1 is version footer.
  return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) {
    return 1;
  }
  // Return the number of rows in the section.
  if ([ChromecastDeviceController sharedInstance].isConnected == NO) {
    self.title = @"Connect to";
    return [ChromecastDeviceController sharedInstance].deviceScanner.devices.count;
  } else {
    self.title =
        [NSString stringWithFormat:@"%@", [ChromecastDeviceController sharedInstance].deviceName];
    return 3;
  }
}

// Return a configured version table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
  versionCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForVersion = @"version";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForVersion
                                                          forIndexPath:indexPath];
  NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  [cell.textLabel setText:[NSString stringWithFormat:@"CastVideos-iOS version %@", ver]];
  return cell;
}

// Return a configured device table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
  deviceCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForDeviceName = @"deviceName";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForDeviceName
                                                          forIndexPath:indexPath];
  GCKDevice *device = [[ChromecastDeviceController sharedInstance].deviceScanner.devices
                          objectAtIndex:indexPath.row];
  cell.textLabel.text = device.friendlyName;
  cell.detailTextLabel.text = device.statusText ? device.statusText : device.modelName;
  return cell;
}

// Return a configured playing media table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
   mediaCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForPlayerController = @"playerController";
  ChromecastDeviceController *castControl = [ChromecastDeviceController sharedInstance];
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForPlayerController
                                                          forIndexPath:indexPath];
  cell.textLabel.text = [castControl.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  cell.detailTextLabel.text = [castControl.mediaInformation.metadata
                               stringForKey:kGCKMetadataKeySubtitle];

  // Accessory is the play/pause button.
  BOOL paused = castControl.playerState == GCKMediaPlayerStatePaused;
  UIImage *playImage = (paused ? [UIImage imageNamed:@"play_black.png"]
                        : [UIImage imageNamed:@"pause_black.png"]);
  CGRect frame = CGRectMake(0, 0, playImage.size.width, playImage.size.height);
  UIButton *button = [[UIButton alloc] initWithFrame:frame];
  [button setBackgroundImage:playImage forState:UIControlStateNormal];
  [button addTarget:self
             action:@selector(playPausePressed:)
   forControlEvents:UIControlEventTouchUpInside];
  cell.accessoryView = button;

  // Asynchronously load the table view image
  if (castControl.mediaInformation.metadata.images.count > 0) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    dispatch_async(queue, ^{
      GCKImage *mediaImage = [castControl.mediaInformation.metadata.images objectAtIndex:0];
      UIImage *image =
          [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:mediaImage.URL]];

      CGSize itemSize = CGSizeMake(40, 40);
      UIImage *thumbnailImage = [SimpleImageFetcher scaleImage:image toSize:itemSize];

      dispatch_sync(dispatch_get_main_queue(), ^{
        UIImageView *mediaThumb = cell.imageView;
        [mediaThumb setImage:thumbnailImage];
        [cell setNeedsLayout];
      });
    });
  }
  return cell;
}

// Return a configured volume control table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
    volumeCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForVolumeControl = @"volumeController";
  static int TagForVolumeSlider = 201;
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForVolumeControl
                                         forIndexPath:indexPath];

  _volumeSlider = (UISlider *)[cell.contentView viewWithTag:TagForVolumeSlider];
  _volumeSlider.minimumValue = 0;
  _volumeSlider.maximumValue = 1.0;
  _volumeSlider.value = [ChromecastDeviceController sharedInstance].deviceVolume;
  _volumeSlider.continuous = NO;
  [_volumeSlider addTarget:self
                    action:@selector(sliderValueChanged:)
          forControlEvents:UIControlEventValueChanged];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(receivedVolumeChangedNotification:)
                                               name:@"Volume changed"
                                             object:[ChromecastDeviceController sharedInstance]];
  return cell;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForReadyStatus = @"readyStatus";
  static NSString *CellIdForDisconnectButton = @"disconnectButton";

  UITableViewCell *cell;

  if (indexPath.section == 1) {
    // Version string.
    cell = [self tableView:tableView versionCellForRowAtIndexPath:indexPath];
  } else if ([ChromecastDeviceController sharedInstance].isConnected == NO) {
    // Device chooser.
    cell = [self tableView:tableView deviceCellForRowAtIndexPath:indexPath];
  } else {
    // Connection manager.
    if (indexPath.row == 0) {
      if ([ChromecastDeviceController sharedInstance].isPlayingMedia == NO) {
        // Display the ready status message.
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdForReadyStatus
                                               forIndexPath:indexPath];
      } else {
        // Display the view describing the playing media.
        cell = [self tableView:tableView mediaCellForRowAtIndexPath:indexPath];
      }
    } else if (indexPath.row == 1) {
      // Display the volume controller.
      cell = [self tableView:tableView volumeCellForRowAtIndexPath:indexPath];
    } else if (indexPath.row == 2) {
      // Display disconnect control as last cell.
      cell = [tableView dequeueReusableCellWithIdentifier:CellIdForDisconnectButton
                                             forIndexPath:indexPath];
    }
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  ChromecastDeviceController *castControl = [ChromecastDeviceController sharedInstance];
  if (castControl.isConnected == NO) {
    if (indexPath.row < castControl.deviceScanner.devices.count) {
      GCKDevice *device = [castControl.deviceScanner.devices objectAtIndex:indexPath.row];
      NSLog(@"Selecting device:%@", device.friendlyName);
      [castControl connectToDevice:device];
    }
  } else if (castControl.isPlayingMedia == YES && indexPath.row == 0) {
    if ([castControl.delegate respondsToSelector:@selector(shouldPresentPlaybackController)]) {
      [castControl.delegate shouldPresentPlaybackController];
    }
  }
  // Dismiss the view.
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  NSLog(@"Accesory button tapped");
}

- (IBAction)disconnectDevice:(id)sender {
  [[ChromecastDeviceController sharedInstance] disconnectFromDevice];

  // Dismiss the view.
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)dismissView:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playPausePressed:(id)sender {
  ChromecastDeviceController *castControl = [ChromecastDeviceController sharedInstance];
  BOOL paused = castControl.playerState == GCKMediaPlayerStatePaused;
  [castControl pauseCastMedia:!paused];

  // change the icon.
  UIButton *button = sender;
  UIImage *playImage =
      (paused ? [UIImage imageNamed:@"play_black.png"] : [UIImage imageNamed:@"pause_black.png"]);
  [button setBackgroundImage:playImage forState:UIControlStateNormal];
}

# pragma mark - volume

- (void)receivedVolumeChangedNotification:(NSNotification *) notification {
  if(!_isManualVolumeChange) {
    ChromecastDeviceController *deviceController = (ChromecastDeviceController *) notification.object;
    _volumeSlider.value = deviceController.deviceVolume;
  }
}

- (IBAction)sliderValueChanged:(id)sender {
  UISlider *slider = (UISlider *) sender;
  _isManualVolumeChange = YES;
  NSLog(@"Got new slider value: %.2f", slider.value);
  [ChromecastDeviceController sharedInstance].deviceVolume = slider.value;
  _isManualVolumeChange = NO;
}

@end