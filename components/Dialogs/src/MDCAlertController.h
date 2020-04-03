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

#import "MaterialButtons.h"
// TODO(b/151929968): Delete import of delegate headers when client code has been migrated to no
// longer import delegates as transitive dependencies.
#import "MDCAlertControllerDelegate.h"
#import "MaterialElevation.h"
#import "MaterialShadowElevations.h"

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

@class MDCAlertAction;
@class MDCAlertController;
@protocol MDCAlertControllerDelegate;

/**
 MDCAlertController displays an alert message to the user, similar to UIAlertController.

 https://material.io/go/design-dialogs

 MDCAlertController class is intended to be used as-is and does not support subclassing. The view
 hierarchy for this class is private and must not be modified.
 */
@interface MDCAlertController
    : UIViewController <MDCElevatable, MDCElevationOverriding, UIContentSizeCategoryAdjusting>

/**
 Convenience constructor to create and return a view controller for displaying an alert to the user.

 After creating the alert controller, add actions to the controller by calling -addAction.

 @note Most alerts don't need titles. Use only for high-risk situations.

 @param title The title of the alert.
 @param message Descriptive text that summarizes a decision in a sentence of two.
 @return An initialized MDCAlertController object.
 */
+ (nonnull instancetype)alertControllerWithTitle:(nullable NSString *)title
                                         message:(nullable NSString *)message;

/**
 Convenience constructor to create and return a view controller for displaying an alert to the user.

 After creating the alert controller, add actions to the controller by calling -addAction.

 @note Most alerts don't need titles. Use only for high-risk situations.

 @note This method receives an @c NSAttributedString for the display message. Use
       @c alertControllerWithTitle:message: for regular @c NSString support.

 @note Currently tappable embedded links within @c attributedMessage are not supported.

 @param alertTitle The title of the alert.
 @param attributedMessage Descriptive text that summarizes a decision in a sentence of two.
 @return An initialized MDCAlertController object.
 */
+ (nonnull instancetype)alertControllerWithTitle:(nullable NSString *)alertTitle
                               attributedMessage:(nullable NSAttributedString *)attributedMessage;

/** Alert controllers must be created with alertControllerWithTitle:message: */
- (nonnull instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                                 bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

/** Alert controllers must be created with alertControllerWithTitle:message: */
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder NS_UNAVAILABLE;

/**
 An object conforming to @c MDCAlertControllerDelegate. When non-nil, the @c MDCAlertController will
 call the appropriate @c MDCAlertControllerDelegate methods on this object.
 */
@property(nonatomic, weak, nullable) id<MDCAlertControllerDelegate> delegate;

/** The font applied to the title of Alert Controller.*/
@property(nonatomic, strong, nullable) UIFont *titleFont;

/** The color applied to the title of Alert Controller.*/
@property(nonatomic, strong, nullable) UIColor *titleColor;

/** The alignment applied to the title of the Alert. Defaults to NSTextAlignmentNatural. */
@property(nonatomic, assign) NSTextAlignment titleAlignment;

/** An optional icon appearing above the title of the Alert Controller.*/
@property(nonatomic, strong, nullable) UIImage *titleIcon;

/** The tint color applied to the titleIcon. Leave empty to preserve original image color(s).*/
@property(nonatomic, strong, nullable) UIColor *titleIconTintColor;

/**
 The alignment applied to the title icon.

 To preserve backward compatibility, the default alignment of the title icon matches the alignment
 of the title, set by @c titleAlignment. The @c titleIconAlignment value will automatically match
 @c titleAlignment until the value of @c titleIconAlignment is first set.
 */
@property(nonatomic, assign) NSTextAlignment titleIconAlignment;

/** The font applied to the message of Alert Controller.*/
@property(nonatomic, strong, nullable) UIFont *messageFont;

/** The color applied to the message of Alert Controller.*/
@property(nonatomic, strong, nullable) UIColor *messageColor;

/**
 The alignment applied to the message of Alert Controller. Defaults to NSTextAlignmentNatural.
 */
@property(nonatomic, assign) NSTextAlignment messageAlignment;

/**
 The font applied to the button of Alert Controller.

 @note This property is deprecated and will be removed in an upcoming release.
 */
@property(nonatomic, strong, nullable)
    UIFont *buttonFont __deprecated_msg("Please use buttonForAction: to set button properties.");

// b/117717380: Will be deprecated
/** The color applied to the button title text of Alert Controller.*/
@property(nonatomic, strong, nullable) UIColor *buttonTitleColor;

// b/117717380: Will be deprecated
/** The color applied to the button ink effect of Alert Controller.*/
@property(nonatomic, strong, nullable) UIColor *buttonInkColor;

/** The semi-transparent color which is applied to the overlay covering the content
     behind the Alert (the scrim) when presented by MDCDialogPresentationController.*/
@property(nonatomic, strong, nullable) UIColor *scrimColor;

/** The Alert background color.*/
@property(nonatomic, strong, nullable) UIColor *backgroundColor;

/** The corner radius applied to the Alert Controller view. Defaults to 0 (no round corners) */
@property(nonatomic, assign) CGFloat cornerRadius;

/** The elevation that will be applied to the Alert Controller view. Defaults to 24. */
@property(nonatomic, assign) MDCShadowElevation elevation;

/**
 The color of the shadow that will be applied to the @c MDCAlertController view. Defaults to black.
 */
@property(nonatomic, copy, nonnull) UIColor *shadowColor;

// TODO(iangordon): Add support for preferredAction to match UIAlertController.
// TODO(iangordon): Consider adding support for UITextFields to match UIAlertController.

/**
 High level description of the alert or decision being made.

 Use title only for high-risk situations, such as the potential loss of connectivity. If used,
 users should be able to understand the choices based on the title and button text alone.
 */
@property(nonatomic, nullable, copy) NSString *title;

/**
 A custom accessibility label for the title.

 When @c nil the title accessibilityLabel will be set to the value of the @c title.
 */
@property(nonatomic, nullable, copy) NSString *titleAccessibilityLabel;

/** Descriptive text that summarizes a decision in a sentence of two. */
@property(nonatomic, nullable, copy) NSString *message;

/**
 Descriptive attributed text that summarizes a decision in a sentence of two.

 If provided and non-empty, will be used instead of @c message property.

 @note Currently tappable embedded links within @c attributedMessage are not supported.
 */
@property(nonatomic, nullable, copy) NSAttributedString *attributedMessage;

/**
 A custom accessibility label for the message.

 When @c nil the message accessibilityLabel will be set to the value of the @c message.
 */
@property(nonatomic, nullable, copy) NSString *messageAccessibilityLabel;

/** A custom accessibility label for the title icon view. */
@property(nonatomic, nullable, copy) NSString *imageAccessibilityLabel;

/**
 Accessory view that contains custom UI.

 The size of the accessory view is determined through Auto Layout. If your view uses manual layout,
 you can either add a height constraint (e.g. `[view.heightAnchor constraintEqualToConstant:100]`),
 or you can override
 `-systemLayoutSizeFittingSize:withHorizontalFittingPriority:verticalFittingPriority:`.

 If the content of the view changes and the height needs to be recalculated, call
 `[alert setAccessoryViewNeedsLayout]`. Note that MDCAccessorizedAlertController will automatically
 recalculate the accessory view's size if the alert's width changes.
 */
@property(nonatomic, strong, nullable) UIView *accessoryView;

/**
 Notifies the alert controller that the size of the accessory view needs to be recalculated due to
 content changes. Note that MDCAccessorizedAlertController will automatically recalculate the
 accessory view's size if the alert's width changes.
 */
- (void)setAccessoryViewNeedsLayout;

/**
 Duration of the dialog fade-in or fade-out presentation animation.

 Defaults to 0.27 seconds.
 */
@property(nonatomic, assign) NSTimeInterval presentationOpacityAnimationDuration;

/**
 Duration of dialog scale-up or scale-down presentation animation.

 Defaults to 0 seconds (no animation is performed).
 */
@property(nonatomic, assign) NSTimeInterval presentationScaleAnimationDuration;

/**
 The starting scale factor of the dialog during the presentation animation, between 0 and 1. The
 "animate in" transition scales the dialog from this value to 1.0.

 Defaults to 1.0 (no scaling is performed).
 */
@property(nonatomic, assign) CGFloat presentationInitialScaleFactor;

/*
 Indicates whether the alert contents should automatically update their font when the device’s
 UIContentSizeCategory changes.

 This property is modeled after the adjustsFontForContentSizeCategory property in the
 UIContentSizeCategoryAdjusting protocol added by Apple in iOS 10.0.

 Defaults to NO.
 */
@property(nonatomic, readwrite, setter=mdc_setAdjustsFontForContentSizeCategory:)
    BOOL mdc_adjustsFontForContentSizeCategory;

/**
 By setting this property to @c YES, the Ripple component will be used instead of Ink
 to display visual feedback to the user.

 @note This property will eventually be enabled by default, deprecated, and then deleted as part
 of our migration to Ripple. Learn more at
 https://github.com/material-components/material-components-ios/tree/develop/components/Ink#migration-guide-ink-to-ripple

 Defaults to NO.
 */
@property(nonatomic, assign) BOOL enableRippleBehavior;

/**
 A block that is invoked when the MDCAlertController receives a call to @c
 traitCollectionDidChange:. The block is called after the call to the superclass.
 */
@property(nonatomic, copy, nullable) void (^traitCollectionDidChangeBlock)
    (MDCAlertController *_Nullable alertController,
     UITraitCollection *_Nullable previousTraitCollection);

/**
 Affects the fallback behavior for when a scaled font is not provided.

 If @c YES, the font size will adjust even if a scaled font has not been provided for
 a given @c UIFont property on this component.

 If @c NO, the font size will only be adjusted if a scaled font has been provided.

 Defaults to @c YES.
 */
@property(nonatomic, assign) BOOL adjustsFontForContentSizeCategoryWhenScaledFontIsUnavailable;

/** MDCAlertController handles its own transitioning delegate. */
- (void)setTransitioningDelegate:
    (_Nullable id<UIViewControllerTransitioningDelegate>)transitioningDelegate NS_UNAVAILABLE;

/** MDCAlertController.modalPresentationStyle is always UIModalPresentationCustom. */
- (void)setModalPresentationStyle:(UIModalPresentationStyle)modalPresentationStyle NS_UNAVAILABLE;

#pragma mark - Alert Actions

/**
 The actions that the user can take in response to the alert.

 The order of the actions in the array matches the order in which they were added to the alert.
 */
@property(nonatomic, nonnull, readonly) NSArray<MDCAlertAction *> *actions;

/**
 Adds an action to the alert dialog.

 Actions are the possible reactions of the user to the presented alert. Actions are added as a
 button at the bottom of the alert. Affirmative actions should be added before dismissive actions.
 Action buttons will be laid out from right to left if possible or top to bottom depending on space.

 Material spec recommends alerts should not have more than two actions.

 @param action Will be added to the end of MDCAlertController.actions.
 */
- (void)addAction:(nonnull MDCAlertAction *)action;

// TODO(https://github.com/material-components/material-components-ios/issues/9891): Replace
// MDCActionEmphasis with UIControlContentHorizontalAlignment after dropping support for iOS 10.
/** Content alignment for Alert actions. */
typedef NS_ENUM(NSInteger, MDCContentHorizontalAlignment) {
  /** Actions are centered. */
  MDCContentHorizontalAlignmentCenter = 0,
  /** Actions are left aligned in LTR and right aligned in RTL.  */
  MDCContentHorizontalAlignmentLeading = 1,
  /** Actions are right aligned in LTR and left aligned in RTL.  */
  MDCContentHorizontalAlignmentTrailing = 2,
  /**
   Actions fill the entire width of the alert (minus the insets). If more than one action is
   presented, equal width is applied to all actions so they fill the space evenly.
   */
  MDCContentHorizontalAlignmentJustified = 3
};

/**
 The alert actions alignment in horizontal layout.  This property controls both alignment and order
 of the actions in the horizontal layout.  Actions that are added first, are presented first based
 on the alignment: when alignment is trailing, the first action is presented on the trailing side
 (right in LTR). For all other alignments, the action added first is presented on the leading side
 (left in LTR).

 Default value is @c MDCContentHorizontalAlignmentTrailing.
 */
@property(nonatomic, assign) MDCContentHorizontalAlignment actionsHorizontalAlignment;

/**
 The horizontal alignment of the alert's actions when in vertical layout. When not enough horizontal
 space is available to present all actions, actions will layout vertically. That may happen in the
 portrait orientation on smaller devices. Actions may have centered, leading, trailing or filled
 alignment. In filled alignment, all actions will be as wide as the alert (minus insets).

 @note: Actions that are added first will be displayed on the bottom, unless overriden by
        orderVerticalActionsByEmphasis.

 Default value is @c MDCContentHorizontalAlignmentCenter.
 */
@property(nonatomic, assign)
    MDCContentHorizontalAlignment actionsHorizontalAlignmentInVerticalLayout;

/**
 Enables ordering actions by emphasis when they are vertically aligned. When set to @c YES,
 horizontally trailing actions, which typically have higher emphasis, will be displayed on top when
 presented vertically (for instance, in the portrait orientation on smaller devices). When set to @c
 NO, the higher emphasis actions will be displayed on the bottom.

 Defaults to @c NO.
*/
@property(nonatomic, assign) BOOL orderVerticalActionsByEmphasis;

@end

#pragma mark - MDCAlertAction

typedef NS_ENUM(NSInteger, MDCActionEmphasis) {
  /* Low emphasis attribute produces low emphasis appearance when attached to actions or buttons */
  MDCActionEmphasisLow = 0,
  /* a Medium emphasis attribute produces a medium emphasis appearance */
  MDCActionEmphasisMedium = 1,
  /* a High emphasis attribute produces a high emphasis appearance */
  MDCActionEmphasisHigh = 2,
};

/**
 MDCActionHandler is a block that will be invoked when the action is selected.
 */
typedef void (^MDCActionHandler)(MDCAlertAction *_Nonnull action);

/**
 MDCAlertAction is passed to an MDCAlertController to add a button to the alert dialog.
 */
@interface MDCAlertAction : NSObject <NSCopying, UIAccessibilityIdentification>

/**
 A convenience method for adding actions that will be rendered as low emphasis buttons at the
 bottom of an alert controller.

 @param title The title of the button shown on the alert dialog.
 @param handler A block to execute when the user selects the action.
 @return An initialized MDCActionAlert object.
 */
+ (nonnull instancetype)actionWithTitle:(nonnull NSString *)title
                                handler:(__nullable MDCActionHandler)handler;

/**
 An action that renders at the bottom of an alert controller as a button of the given emphasis.

 @param title The title of the button shown on the alert dialog.
 @param emphasis The emphasis of the button that will be rendered in the alert dialog.
        Unthemed actions will render all emphases as text. Apply themers to the alert
        to achieve different appearance for different emphases.
 @param handler A block to execute when the user selects the action.
 @return An initialized MDCActionAlert object.
 */
+ (nonnull instancetype)actionWithTitle:(nonnull NSString *)title
                               emphasis:(MDCActionEmphasis)emphasis
                                handler:(__nullable MDCActionHandler)handler;

/** Alert actions must be created with actionWithTitle:handler: */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
 Title of the button shown on the alert dialog.
 */
@property(nonatomic, nullable, readonly) NSString *title;

/**
 The MDCActionEmphasis emphasis of the button that will be rendered for the action.
 */
@property(nonatomic, readonly) MDCActionEmphasis emphasis;

// TODO(iangordon): Add support for enabled property to match UIAlertAction

/**
 The @c accessibilityIdentifier for the view associated with this action.
 */
@property(nonatomic, nullable, copy) NSString *accessibilityIdentifier;

@end
