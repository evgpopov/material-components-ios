// Copyright 2016-present the Material Components for iOS authors. All Rights Reserved.
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

#import <UIKit/UIKit.h>

#import "MaterialButtons.h"
#import "MaterialElevation.h"
#import "MaterialShadowElevations.h"

/**
 Class which provides the default implementation of a Snackbar.
 */
@interface MDCSnackbarMessageView : UIView <MDCElevatable, MDCElevationOverriding>

/**
 The color for the background of the Snackbar message view.

 The default color is a dark gray color.
 */
@property(nonatomic, strong, nullable)
    UIColor *snackbarMessageViewBackgroundColor UI_APPEARANCE_SELECTOR;

/**
 The color for the shadow color for the Snackbar message view.

 The default color is @c blackColor.
 */
@property(nonatomic, strong, nullable)
    UIColor *snackbarMessageViewShadowColor UI_APPEARANCE_SELECTOR;

/**
 The color for the message text in the Snackbar message view.

 The default color is @c whiteColor.
 */
@property(nonatomic, strong, nullable) UIColor *messageTextColor UI_APPEARANCE_SELECTOR;

/**
 The font for the message text in the Snackbar message view.
 */
@property(nonatomic, strong, nullable) UIFont *messageFont UI_APPEARANCE_SELECTOR;

/**
 The font for the button text in the Snackbar message view.
 */
@property(nonatomic, strong, nullable) UIFont *buttonFont UI_APPEARANCE_SELECTOR;

/**
 The action button for the snackbar, if `message.action` is set.
 */
@property(nonatomic, strong, nullable) MDCButton *actionButton;

/**
 Deprecated. Please use `actionButton` instead. Returns an array with `actionButton` if
 `actionButton` is not nil, otherewise returns an empty array.
 */
@property(nonatomic, strong, nullable, readonly)
    NSArray<MDCButton *> *actionButtons __deprecated_msg("Please use `actionButton` instead`.");

/**
 The elevation of the snackbar view.
 */
@property(nonatomic, assign) MDCShadowElevation elevation;

/**
 The @c accessibilityLabel to apply to the message of the Snackbar.
 */
@property(nullable, nonatomic, copy) NSString *accessibilityLabel;

/**
 The @c accessibilityHint to apply to the message of the Snackbar.
 */
@property(nullable, nonatomic, copy) NSString *accessibilityHint;

/**
 The @c minimumLayoutHeight to use when laying out the Snackbar such that there
 will be enough space to layout text at the current text size.
 */
@property(nonatomic, readonly) CGFloat minimumLayoutHeight;

/**
 Enable a hidden touch affordance (button) for users to dismiss under VoiceOver.

 It allows users to dismiss the snackbar in an explicit way. When it is enabled,
 tapping on the message label won't dismiss the snackbar.

 Defaults to @c NO.
 */
@property(nonatomic, assign) BOOL enableDismissalAccessibilityAffordance;

/**
 Returns the button title color for a particular control state.

 Default for UIControlStateNormal is MDCRGBAColor(0xFF, 0xFF, 0xFF, (CGFloat)0.6).
 Default for UIControlStatehighlighted is white.

 @param state The control state.
 @return The button title color for the requested state.
 */
- (nullable UIColor *)buttonTitleColorForState:(UIControlState)state UI_APPEARANCE_SELECTOR;

/**
 Sets the button title color for a particular control state.

 @param titleColor The title color.
 @param state The control state.
 */
- (void)setButtonTitleColor:(nullable UIColor *)titleColor
                   forState:(UIControlState)state UI_APPEARANCE_SELECTOR;

/**
 A block that is invoked when the MDCSnackbarMessageView receives a call to @c
 traitCollectionDidChange:. The block is called after the call to the superclass.
 */
@property(nonatomic, copy, nullable) void (^traitCollectionDidChangeBlock)
    (MDCSnackbarMessageView *_Nonnull messageView,
     UITraitCollection *_Nullable previousTraitCollection);

@end
