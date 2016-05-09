// Copyright 2013 Google Inc. All Rights Reserved.
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
#import "CastDeviceController.h"

#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];

  // Turn on the Cast logging for debug purposes.
  [[CastDeviceController sharedInstance] enableLogging];
  // Set the receiver application ID to initialise scanning.
  [CastDeviceController sharedInstance].applicationID = @"01CB9B68";
  // Replace the value above with your app id.

  // Set playback category mode to allow playing audio on the video files even when the ringer
  // mute switch is on.
  NSError *setCategoryError;
  BOOL success = [[AVAudioSession sharedInstance]
                  setCategory:AVAudioSessionCategoryPlayback
                        error: &setCategoryError];
  if (!success) {
    NSLog(@"Error setting audio category: %@", setCategoryError.localizedDescription);
  }

  return YES;
}

@end