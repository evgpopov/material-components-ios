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

#import "MDCButton.h"

#import <UIKit/UIKit.h>

#import "private/MDCButton+Subclassing.h"
#import "UIView+MaterialElevationResponding.h"
#import "MDCInkView.h"
#import "MDCRippleView.h"
#import "MDCStatefulRippleView.h"
#import "MDCShadowsCollection.h"
#import "MDCShadowElevations.h"
#import "MDCRoundedCornerTreatment.h"
#import "MDCRectangleShapeGenerator.h"
#import "MDCShapeMediator.h"
#import "MDCShapedShadowLayer.h"
#import "MDCFontTextStyle.h"
#import "MDCTypography.h"
#import "UIFont+MaterialScalable.h"
#import "UIFont+MaterialTypography.h"
#import "MDCMath.h"

// TODO(ajsecord): Animate title color when animating between enabled/disabled states.
// Non-trivial: http://corecocoa.wordpress.com/2011/10/04/animatable-text-color-of-uilabel/

static const CGFloat MDCButtonMinimumTouchTargetHeight = 44;
static const CGFloat MDCButtonMinimumTouchTargetWidth = 44;
static const CGFloat MDCButtonDefaultCornerRadius = 2.0;
static const CGFloat kDefaultRippleAlpha = (CGFloat)0.12;

static const NSTimeInterval MDCButtonAnimationDuration = 0.2;

// https://material.io/go/design-buttons#buttons-main-buttons
static const CGFloat MDCButtonDisabledAlpha = (CGFloat)0.12;

// Blue 500 from https://material.io/go/design-color-theming#color-color-palette .
static const uint32_t MDCButtonDefaultBackgroundColor = 0x191919;

// KVO contexts
static char *const kKVOContextCornerRadius = "kKVOContextCornerRadius";

// Creates a UIColor from a 24-bit RGB color encoded as an integer.
static inline UIColor *MDCColorFromRGB(uint32_t rgbValue) {
  return [UIColor colorWithRed:((CGFloat)((rgbValue & 0xFF0000) >> 16)) / 255
                         green:((CGFloat)((rgbValue & 0x00FF00) >> 8)) / 255
                          blue:((CGFloat)((rgbValue & 0x0000FF) >> 0)) / 255
                         alpha:1];
}

// Expands size by provided edge insets.
static inline CGSize CGSizeExpandWithInsets(CGSize size, UIEdgeInsets edgeInsets) {
  return CGSizeMake(size.width + edgeInsets.left + edgeInsets.right,
                    size.height + edgeInsets.top + edgeInsets.bottom);
}

// Shrinks size by provided edge insets, and also standardized.
static inline CGSize CGSizeShrinkWithInsets(CGSize size, UIEdgeInsets edgeInsets) {
  return CGSizeMake(MAX(0, size.width - (edgeInsets.left + edgeInsets.right)),
                    MAX(0, size.height - (edgeInsets.top + edgeInsets.bottom)));
}

static NSAttributedString *UppercaseAttributedString(NSAttributedString *string) {
  // Store the attributes.
  NSMutableArray<NSDictionary *> *attributes = [NSMutableArray array];
  [string enumerateAttributesInRange:NSMakeRange(0, [string length])
                             options:0
                          usingBlock:^(NSDictionary *attrs, NSRange range, __unused BOOL *stop) {
                            [attributes addObject:@{
                              @"attrs" : attrs,
                              @"range" : [NSValue valueWithRange:range]
                            }];
                          }];

  // Make the string uppercase.
  NSString *uppercaseString = [[string string] uppercaseStringWithLocale:[NSLocale currentLocale]];

  // Apply the text and attributes to a mutable copy of the title attributed string.
  NSMutableAttributedString *mutableString = [string mutableCopy];
  [mutableString replaceCharactersInRange:NSMakeRange(0, [string length])
                               withString:uppercaseString];
  for (NSDictionary *attribute in attributes) {
    [mutableString setAttributes:attribute[@"attrs"] range:[attribute[@"range"] rangeValue]];
  }

  return [mutableString copy];
}

@interface MDCButton () {
  // For each UIControlState.
  NSMutableDictionary<NSNumber *, NSNumber *> *_userElevations;
  NSMutableDictionary<NSNumber *, UIColor *> *_backgroundColors;
  NSMutableDictionary<NSNumber *, UIColor *> *_borderColors;
  NSMutableDictionary<NSNumber *, NSNumber *> *_borderWidths;
  NSMutableDictionary<NSNumber *, UIColor *> *_shadowColors;
  NSMutableDictionary<NSNumber *, UIColor *> *_imageTintColors;
  NSMutableDictionary<NSNumber *, UIFont *> *_fonts;

  CGFloat _enabledAlpha;
  BOOL _hasCustomDisabledTitleColor;
  BOOL _imageTintStatefulAPIEnabled;

  // Cached titles and accessibility labels.
  NSMutableDictionary<NSNumber *, id> *_nontransformedTitles;
  NSString *_accessibilityLabelExplicitValue;

  BOOL _mdc_adjustsFontForContentSizeCategory;
  BOOL _cornerRadiusObserverAdded;
  CGFloat _inkMaxRippleRadius;

  MDCShapeMediator *_shapedLayer;
  CGFloat _currentElevation;
}
@property(nonatomic, strong, readonly, nonnull) MDCStatefulRippleView *rippleView;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property(nonatomic, strong) MDCInkView *inkView;
#pragma clang diagnostic pop
@property(nonatomic, readonly, strong) MDCShapedShadowLayer *layer;
@property(nonatomic, assign) BOOL accessibilityTraitsIncludesButton;
@property(nonatomic, assign) BOOL enableTitleFontForState;
@property(nonatomic, assign) UIEdgeInsets visibleAreaInsets;
@property(nonatomic, strong) UIView *visibleAreaLayoutGuideView;
@property(nonatomic) UIEdgeInsets hitAreaInsets;
@property(nonatomic, assign) UIEdgeInsets currentVisibleAreaInsets;
@property(nonatomic, assign) CGSize lastRecordedIntrinsicContentSize;

// Used only when layoutTitleWithConstraints is enabled.
@property(nonatomic, strong) NSLayoutConstraint *titleTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *titleBottomConstraint;
@property(nonatomic, strong) NSLayoutConstraint *titleLeadingConstraint;
@property(nonatomic, strong) NSLayoutConstraint *titleTrailingConstraint;

@end

@implementation MDCButton

static BOOL gEnablePerformantShadow = NO;

@synthesize mdc_overrideBaseElevation = _mdc_overrideBaseElevation;
@synthesize mdc_elevationDidChangeBlock = _mdc_elevationDidChangeBlock;
@synthesize visibleAreaInsets = _visibleAreaInsets;
@synthesize visibleAreaLayoutGuide = _visibleAreaLayoutGuide;
@synthesize shadowsCollection = _shadowsCollection;
@dynamic layer;

+ (Class)layerClass {
  if (gEnablePerformantShadow) {
    return [super layerClass];
  } else {
    return [MDCShapedShadowLayer class];
  }
}

- (instancetype)init {
  return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // Set up title label attributes.
    // TODO(#2709): Have a single source of truth for fonts
    // Migrate to [UIFont standardFont] when possible
    self.titleLabel.font = [MDCTypography buttonFont];

    [self commonMDCButtonInit];
    [self updateBackgroundColor];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonMDCButtonInit];

    if (self.titleLabel.font) {
      _fonts = [@{} mutableCopy];
      _fonts[@(UIControlStateNormal)] = self.titleLabel.font;
    }

    // Storyboards will set the backgroundColor via the UIView backgroundColor setter, so we have
    // to write that in to our _backgroundColors dictionary.
    _backgroundColors[@(UIControlStateNormal)] = gEnablePerformantShadow
                                                     ? _shapedLayer.shapedBackgroundColor
                                                     : self.layer.shapedBackgroundColor;
    [self updateBackgroundColor];
  }
  return self;
}

- (void)commonMDCButtonInit {
  // TODO(b/142861610): Default to `NO`, then remove once all internal usage is migrated.
  _enableTitleFontForState = YES;
  if (gEnablePerformantShadow) {
    _shapedLayer = [[MDCShapeMediator alloc] initWithViewLayer:self.layer];
  }
  _disabledAlpha = MDCButtonDisabledAlpha;
  _enabledAlpha = self.alpha;
  _uppercaseTitle = YES;
  _userElevations = [NSMutableDictionary dictionary];
  _nontransformedTitles = [NSMutableDictionary dictionary];
  _borderColors = [NSMutableDictionary dictionary];
  _imageTintColors = [NSMutableDictionary dictionary];
  _borderWidths = [NSMutableDictionary dictionary];
  _fonts = [NSMutableDictionary dictionary];
  _accessibilityTraitsIncludesButton = YES;
  _mdc_overrideBaseElevation = -1;
  _currentElevation = 0;

  if (!_backgroundColors) {
    // _backgroundColors may have already been initialized by setting the backgroundColor setter.
    _backgroundColors = [NSMutableDictionary dictionary];
    _backgroundColors[@(UIControlStateNormal)] = MDCColorFromRGB(MDCButtonDefaultBackgroundColor);
  }

  // Disable default highlight state.
  self.adjustsImageWhenHighlighted = NO;

#if (!defined(TARGET_OS_TV) || TARGET_OS_TV == 0)
  self.showsTouchWhenHighlighted = NO;
#endif

  self.layer.cornerRadius = MDCButtonDefaultCornerRadius;
  if (gEnablePerformantShadow) {
    self.layer.shadowColor = MDCShadowColor().CGColor;
  } else {
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.elevation = [self elevationForState:self.state];
  }

  _shadowColors = [NSMutableDictionary dictionary];
  _shadowColors[@(UIControlStateNormal)] = [UIColor colorWithCGColor:self.layer.shadowColor];

  // Set up ink layer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  _inkView = [[MDCInkView alloc] initWithFrame:self.bounds];
#pragma clang diagnostic pop
  _inkView.usesLegacyInkRipple = NO;
  [self insertSubview:_inkView belowSubview:self.imageView];
  // UIButton has a drag enter/exit boundary that is outside of the frame of the button itself.
  // Because this is not exposed externally, we can't use -touchesMoved: to calculate when to
  // change ink state. So instead we fall back on adding target/actions for these specific events.
  [self addTarget:self
                action:@selector(touchDragEnter:forEvent:)
      forControlEvents:UIControlEventTouchDragEnter];
  [self addTarget:self
                action:@selector(touchDragExit:forEvent:)
      forControlEvents:UIControlEventTouchDragExit];

#if (!defined(TARGET_OS_TV) || TARGET_OS_TV == 0)
  // Block users from activating multiple buttons simultaneously by default.
  self.exclusiveTouch = YES;
#endif

  _inkView.inkColor = [UIColor colorWithWhite:1 alpha:(CGFloat)0.2];

  _rippleView = [[MDCStatefulRippleView alloc] initWithFrame:self.bounds];
  _rippleColor = [UIColor colorWithWhite:0 alpha:kDefaultRippleAlpha];
  _rippleView.rippleColor = [UIColor colorWithWhite:0 alpha:(CGFloat)0.12];

  // Default content insets
  // The default contentEdgeInsets are set here (instead of above, as they were previously) because
  // of a UIButton bug introduced in the iOS 13 betas that is unresolved as of Xcode 11 beta 4
  // (b/136088498) wherein setting self.contentEdgeInsets before accessing self.imageView causes the
  // imageView's bounds.origin to be set to { -(i.left + i.right), -(i.top + i.bottom) }
  // This causes images created by using imageWithHorizontallyFlippedOrientation to not display.
  // Images that have not been created this way seem to be fine.
  // This behavior can also be seen in vanilla UIButtons by setting contentEdgeInsets to non-zero
  // inset values and then setting an image created with imageWithHorizontallyFlippedOrientation.
  self.contentEdgeInsets = [self defaultContentEdgeInsets];
  _minimumSize = CGSizeZero;
  _maximumSize = CGSizeZero;

  // Uppercase all titles
  if (_uppercaseTitle) {
    [self updateTitleCase];
  }
}

- (void)dealloc {
  [self removeTarget:self action:NULL forControlEvents:UIControlEventAllEvents];

  if (_cornerRadiusObserverAdded) {
    [self.layer removeObserver:self
                    forKeyPath:NSStringFromSelector(@selector(cornerRadius))
                       context:kKVOContextCornerRadius];
  }
}

- (void)setUnderlyingColorHint:(UIColor *)underlyingColorHint {
  _underlyingColorHint = underlyingColorHint;
  [self updateAlphaAndBackgroundColorAnimated:NO];
}

- (void)setAlpha:(CGFloat)alpha {
  _enabledAlpha = alpha;
  [super setAlpha:alpha];
}

- (void)setDisabledAlpha:(CGFloat)disabledAlpha {
  _disabledAlpha = disabledAlpha;
  [self updateAlphaAndBackgroundColorAnimated:NO];
}

#pragma mark - UIView

- (void)layoutSubviews {
  [super layoutSubviews];

  [self updateShadowColor];
  [self updateBackgroundColor];
  [self updateBorderColor];

  if (self.centerVisibleArea) {
    UIEdgeInsets visibleAreaInsets = self.visibleAreaInsets;
    if (!UIEdgeInsetsEqualToEdgeInsets(visibleAreaInsets, self.currentVisibleAreaInsets)) {
      self.currentVisibleAreaInsets = visibleAreaInsets;
      MDCRectangleShapeGenerator *shapeGenerator =
          [self generateShapeWithCornerRadius:self.layer.cornerRadius
                            visibleAreaInsets:visibleAreaInsets];
      [self configureLayerWithShapeGenerator:shapeGenerator];
      if (self.visibleAreaLayoutGuideView) {
        self.visibleAreaLayoutGuideView.frame =
            UIEdgeInsetsInsetRect(self.bounds, visibleAreaInsets);
      }
    }
  }

  if (gEnablePerformantShadow) {
    if (_shapedLayer.shapeGenerator) {
      [_shapedLayer layoutShapedSublayers];
    }
    [self updateShadow];
  } else {
    if (!self.layer.shapeGenerator) {
      self.layer.shadowPath = [self boundingPath].CGPath;
    }
  }

  // Center unbounded ink view frame taking into account possible insets using contentRectForBounds.
  if (_inkView.inkStyle == MDCInkStyleUnbounded && _inkView.usesLegacyInkRipple) {
    CGRect contentRect = [self contentRectForBounds:self.bounds];
    CGPoint contentCenterPoint =
        CGPointMake(CGRectGetMidX(contentRect), CGRectGetMidY(contentRect));
    CGPoint boundsCenterPoint = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));

    CGFloat offsetX = contentCenterPoint.x - boundsCenterPoint.x + self.inkViewOffset.width;
    CGFloat offsetY = contentCenterPoint.y - boundsCenterPoint.y + self.inkViewOffset.height;
    _inkView.frame =
        CGRectMake(offsetX, offsetY, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
  } else {
    CGRect bounds = CGRectStandardize(self.bounds);
    bounds = CGRectOffset(bounds, self.inkViewOffset.width, self.inkViewOffset.height);
    bounds = UIEdgeInsetsInsetRect(bounds, self.rippleEdgeInsets);
    _inkView.frame = bounds;
    self.rippleView.frame = bounds;
  }
  self.titleLabel.frame = MDCRectAlignToScale(self.titleLabel.frame, [UIScreen mainScreen].scale);

  if ([self shouldInferMinimumAndMaximumSize]) {
    [self inferMinimumAndMaximumSize];
  }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  // If there are custom hitAreaInsets, use those
  if (!UIEdgeInsetsEqualToEdgeInsets(self.hitAreaInsets, UIEdgeInsetsZero)) {
    return CGRectContainsPoint(
        UIEdgeInsetsInsetRect(CGRectStandardize(self.bounds), self.hitAreaInsets), point);
  }

  // If the bounds are smaller than the minimum touch target, produce a warning once
  CGFloat width = CGRectGetWidth(self.bounds);
  CGFloat height = CGRectGetHeight(self.bounds);
  if (width < MDCButtonMinimumTouchTargetWidth || height < MDCButtonMinimumTouchTargetHeight) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      NSLog(
          @"Button touch target does not meet minimum size guidelines of (%0.f, %0.f). Button: %@, "
          @"Touch Target: %@",
          MDCButtonMinimumTouchTargetWidth, MDCButtonMinimumTouchTargetHeight, [self description],
          NSStringFromCGSize(CGSizeMake(width, height)));
    });
  }
  return [super pointInside:point withEvent:event];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
  [super willMoveToSuperview:newSuperview];
  [self.inkView cancelAllAnimationsAnimated:NO];
  [self.rippleView cancelAllRipplesAnimated:NO completion:nil];
}

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize givenSizeWithInsets = CGSizeShrinkWithInsets(size, _visibleAreaInsets);
  CGSize superSize = [super sizeThatFits:givenSizeWithInsets];

  // TODO(b/171816831): revisit this in a future iOS version to verify reproducibility.
  // Because of a UIKit bug in iOS 13 and 14 (current), buttons that have both an image and text
  // will not return an appropriately large size from [super sizeThatFits:]. In this case, we need
  // to expand the width. The number 1 was chosen somewhat arbitrarily, but based on some spot
  // testing, adding the smallest amount of extra width possible seems to fix the issue.
#if defined(__IPHONE_13_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0)
  if (@available(iOS 13.0, *)) {
    if (UIAccessibilityIsBoldTextEnabled() && [self imageForState:UIControlStateNormal] &&
        [self titleForState:UIControlStateNormal]) {
      superSize.width += 1;
    }
  }
#endif

  if (self.minimumSize.height > 0) {
    superSize.height = MAX(self.minimumSize.height, superSize.height);
  }
  if (self.maximumSize.height > 0) {
    superSize.height = MIN(self.maximumSize.height, superSize.height);
  }
  if (self.minimumSize.width > 0) {
    superSize.width = MAX(self.minimumSize.width, superSize.width);
  }
  if (self.maximumSize.width > 0) {
    superSize.width = MIN(self.maximumSize.width, superSize.width);
  }

  CGSize adjustedSize = CGSizeExpandWithInsets(superSize, _visibleAreaInsets);
  return adjustedSize;
}

- (CGSize)intrinsicContentSize {
  CGSize size = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
  self.lastRecordedIntrinsicContentSize = size;
  return size;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];

  if (self.traitCollectionDidChangeBlock) {
    self.traitCollectionDidChangeBlock(self, previousTraitCollection);
  }
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  if (self.enableRippleBehavior) {
    [self.rippleView touchesBegan:touches withEvent:event];
  }
  [super touchesBegan:touches withEvent:event];

  if (!self.enableRippleBehavior) {
    [self handleBeginTouches:touches];
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  if (self.enableRippleBehavior) {
    [self.rippleView touchesMoved:touches withEvent:event];
  }
  [super touchesMoved:touches withEvent:event];

  // Drag events handled by -touchDragExit:forEvent: and -touchDragEnter:forEvent:
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
  if (self.enableRippleBehavior) {
    [self.rippleView touchesEnded:touches withEvent:event];
  }
  [super touchesEnded:touches withEvent:event];

  if (!self.enableRippleBehavior) {
    CGPoint location = [self locationFromTouches:touches];
    [_inkView startTouchEndedAnimationAtPoint:location completion:nil];
  }
}

// Note - in some cases, event may be nil (e.g. view removed from window).
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  if (self.enableRippleBehavior) {
    [self.rippleView touchesCancelled:touches withEvent:event];
  }
  [super touchesCancelled:touches withEvent:event];

  if (!self.enableRippleBehavior) {
    [self evaporateInkToPoint:[self locationFromTouches:touches]];
  }
}

#pragma mark - UIControl methods

- (void)setEnabled:(BOOL)enabled {
  [self setEnabled:enabled animated:NO];
}

- (void)setEnabled:(BOOL)enabled animated:(BOOL)animated {
  [super setEnabled:enabled];

  [self updateAfterStateChange:animated];
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];

  self.rippleView.rippleHighlighted = highlighted;
  [self updateAfterStateChange:NO];
}

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];

  self.rippleView.selected = selected;
  [self updateAfterStateChange:NO];
}

- (void)updateAfterStateChange:(BOOL)animated {
  [self updateAlphaAndBackgroundColorAnimated:animated];
  [self animateButtonToHeightForState:self.state];
  [self updateBorderColor];
  [self updateBorderWidth];
  [self updateShadowColor];
  [self updateTitleFont];
  [self updateImageTintColor];
}

#pragma mark - Title Uppercasing

- (void)setUppercaseTitle:(BOOL)uppercaseTitle {
  _uppercaseTitle = uppercaseTitle;

  [self updateTitleCase];
}

- (void)updateTitleCase {
  // This calls setTitle or setAttributedTitle for every title value we have stored. In each
  // respective setter the title is upcased if _uppercaseTitle is YES.
  NSDictionary<NSNumber *, NSString *> *nontransformedTitles = [_nontransformedTitles copy];
  for (NSNumber *key in nontransformedTitles.keyEnumerator) {
    UIControlState state = key.unsignedIntegerValue;
    NSString *title = nontransformedTitles[key];
    if ([title isKindOfClass:[NSAttributedString class]]) {
      [self setAttributedTitle:(NSAttributedString *)title forState:state];
    } else if ([title isKindOfClass:[NSString class]]) {
      [self setTitle:title forState:state];
    }
  }
}

- (void)updateShadowColor {
  self.layer.shadowColor = [self shadowColorForState:self.state].CGColor;
}

- (void)setShadowColor:(UIColor *)shadowColor forState:(UIControlState)state {
  if (shadowColor) {
    _shadowColors[@(state)] = shadowColor;
  } else {
    [_shadowColors removeObjectForKey:@(state)];
  }

  if (state == self.state) {
    [self updateShadowColor];
  }
}

- (UIColor *)shadowColorForState:(UIControlState)state {
  UIColor *shadowColor = _shadowColors[@(state)];
  if (state != UIControlStateNormal && !shadowColor) {
    shadowColor = _shadowColors[@(UIControlStateNormal)];
  }
  return shadowColor;
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
  // Intercept any setting of the title and store a copy in case the accessibilityLabel
  // is requested and the original non-uppercased version needs to be returned.
  if ([title length]) {
    _nontransformedTitles[@(state)] = [title copy];
  } else {
    [_nontransformedTitles removeObjectForKey:@(state)];
  }

  if (_uppercaseTitle) {
    title = [title uppercaseStringWithLocale:[NSLocale currentLocale]];
  }
  [super setTitle:title forState:state];
}

- (void)setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
  // Intercept any setting of the title and store a copy in case the accessibilityLabel
  // is requested and the original non-uppercased version needs to be returned.
  if ([title length]) {
    _nontransformedTitles[@(state)] = [title copy];
  } else {
    [_nontransformedTitles removeObjectForKey:@(state)];
  }

  if (_uppercaseTitle) {
    title = UppercaseAttributedString(title);
  }
  [super setAttributedTitle:title forState:state];
}

#pragma mark - Accessibility

- (void)setAccessibilityLabel:(NSString *)accessibilityLabel {
  // Intercept any explicit setting of the accessibilityLabel so it can be returned
  // later before the accessibiilityLabel is inferred from the setTitle:forState:
  // argument values.
  _accessibilityLabelExplicitValue = [accessibilityLabel copy];
  [super setAccessibilityLabel:accessibilityLabel];
}

- (NSString *)accessibilityLabel {
  if (!_uppercaseTitle) {
    return [super accessibilityLabel];
  }

  if ([_accessibilityLabelExplicitValue length]) {
    return _accessibilityLabelExplicitValue;
  }

  NSString *titleLabel;
  id stateTitle = _nontransformedTitles[@(self.state)];
  if ([stateTitle isKindOfClass:[NSAttributedString class]]) {
    titleLabel = [(NSAttributedString *)stateTitle string];
  } else if ([stateTitle isKindOfClass:[NSString class]]) {
    titleLabel = stateTitle;
  }
  if ([titleLabel length]) {
    return titleLabel;
  }

  id normalTitle = _nontransformedTitles[@(UIControlStateNormal)];
  if ([normalTitle isKindOfClass:[NSAttributedString class]]) {
    titleLabel = [(NSAttributedString *)normalTitle string];
  } else if ([normalTitle isKindOfClass:[NSString class]]) {
    titleLabel = normalTitle;
  }
  if ([titleLabel length]) {
    return titleLabel;
  }

  NSString *label = [super accessibilityLabel];
  if ([label length]) {
    return label;
  }

  return nil;
}

- (UIAccessibilityTraits)accessibilityTraits {
  if (self.accessibilityTraitsIncludesButton) {
    return [super accessibilityTraits] | UIAccessibilityTraitButton;
  }
  return [super accessibilityTraits];
}

#pragma mark - Ink

- (MDCInkStyle)inkStyle {
  return _inkView.inkStyle;
}

- (void)setInkStyle:(MDCInkStyle)inkStyle {
  _inkView.inkStyle = inkStyle;
  self.rippleView.rippleStyle =
      (inkStyle == MDCInkStyleUnbounded) ? MDCRippleStyleUnbounded : MDCRippleStyleBounded;
}

- (void)setRippleStyle:(MDCRippleStyle)rippleStyle {
  _rippleStyle = rippleStyle;

  self.rippleView.rippleStyle = rippleStyle;
}

- (UIColor *)inkColor {
  return _inkView.inkColor;
}

- (void)setInkColor:(UIColor *)inkColor {
  _inkView.inkColor = inkColor;
  [self.rippleView setRippleColor:inkColor forState:MDCRippleStateHighlighted];
}

- (void)setRippleColor:(UIColor *)rippleColor {
  _rippleColor = rippleColor ?: [UIColor colorWithWhite:0 alpha:kDefaultRippleAlpha];
  [self.rippleView setRippleColor:_rippleColor forState:MDCRippleStateHighlighted];
}

- (CGFloat)inkMaxRippleRadius {
  return _inkMaxRippleRadius;
}

- (void)setInkMaxRippleRadius:(CGFloat)inkMaxRippleRadius {
  _inkMaxRippleRadius = inkMaxRippleRadius;
  _inkView.maxRippleRadius = inkMaxRippleRadius;
  self.rippleView.maximumRadius = inkMaxRippleRadius;
}

- (void)setRippleMaximumRadius:(CGFloat)rippleMaximumRadius {
  _rippleMaximumRadius = rippleMaximumRadius;

  self.rippleView.maximumRadius = rippleMaximumRadius;
}

- (void)setInkViewOffset:(CGSize)inkViewOffset {
  _inkViewOffset = inkViewOffset;
  [self setNeedsLayout];
}

- (void)setRippleEdgeInsets:(UIEdgeInsets)rippleEdgeInsets {
  _rippleEdgeInsets = rippleEdgeInsets;

  [self setNeedsLayout];
}

- (void)setEnableRippleBehavior:(BOOL)enableRippleBehavior {
  _enableRippleBehavior = enableRippleBehavior;

  if (enableRippleBehavior) {
    [self.inkView removeFromSuperview];
    [self insertSubview:self.rippleView belowSubview:self.imageView];
  } else {
    [self.rippleView removeFromSuperview];
    [self insertSubview:self.inkView belowSubview:self.imageView];
  }
}

#pragma mark - Shadows

- (void)animateButtonToHeightForState:(UIControlState)state {
  CGFloat newElevation = [self elevationForState:state];
  if (MDCCGFloatEqual(self.mdc_currentElevation, newElevation)) {
    return;
  }
  _currentElevation = newElevation;
  [CATransaction begin];
  [CATransaction setAnimationDuration:MDCButtonAnimationDuration];
  if (gEnablePerformantShadow) {
    [self updateShadow];
  } else {
    self.layer.elevation = newElevation;
  }
  [CATransaction commit];
  [self mdc_elevationDidChange];
}

#pragma mark - BackgroundColor

- (void)setBackgroundColor:(nullable UIColor *)backgroundColor {
  // Since setBackgroundColor can be called in the initializer we need to optionally build the dict.
  if (!_backgroundColors) {
    _backgroundColors = [NSMutableDictionary dictionary];
  }
  _backgroundColors[@(UIControlStateNormal)] = backgroundColor;
  [self updateBackgroundColor];
}

- (UIColor *)backgroundColor {
  return gEnablePerformantShadow ? _shapedLayer.shapedBackgroundColor
                                 : self.layer.shapedBackgroundColor;
}

- (UIColor *)backgroundColorForState:(UIControlState)state {
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    state = state & ~UIControlStateDisabled;
  }

  return _backgroundColors[@(state)] ?: _backgroundColors[@(UIControlStateNormal)];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor forState:(UIControlState)state {
  UIControlState storageState = state;
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    storageState = state & ~UIControlStateDisabled;
  }

  // Only update the backing dictionary if:
  // 1. The `state` argument is the same as the "storage" state, OR
  // 2. There is already a value in the "storage" state.
  if (storageState == state || _backgroundColors[@(storageState)] != nil) {
    _backgroundColors[@(storageState)] = backgroundColor;
    [self updateAlphaAndBackgroundColorAnimated:NO];
  }
}

#pragma mark - Image Tint Color

- (void)setTintColor:(UIColor *)tintColor {
  // Use of both tintColor and imageTintColor:forState: results in confusing results. We are using a
  // last call wins stratgy to allow for both to still be used.
  [_imageTintColors removeAllObjects];
  [self updateImageTintColor];
  _imageTintStatefulAPIEnabled = NO;
  [super setTintColor:tintColor];
}

- (nullable UIColor *)imageTintColorForState:(UIControlState)state {
  return _imageTintColors[@(state)] ?: _imageTintColors[@(UIControlStateNormal)];
}

- (void)setImageTintColor:(nullable UIColor *)imageTintColor forState:(UIControlState)state {
  _imageTintColors[@(state)] = imageTintColor;
  _imageTintStatefulAPIEnabled = YES;
  [self updateImageTintColor];
}

- (void)updateImageTintColor {
  if (!_imageTintStatefulAPIEnabled) {
    return;
  }
  self.imageView.tintColor = [self imageTintColorForState:self.state];
}

#pragma mark - Elevations

- (CGFloat)elevationForState:(UIControlState)state {
  NSNumber *elevation = _userElevations[@(state)];
  if (state != UIControlStateNormal && (elevation == nil)) {
    elevation = _userElevations[@(UIControlStateNormal)];
  }
  if (elevation != nil) {
    return (CGFloat)[elevation doubleValue];
  }
  return 0;
}

- (void)setElevation:(CGFloat)elevation forState:(UIControlState)state {
  _userElevations[@(state)] = @(elevation);
  MDCShadowElevation newElevation = [self elevationForState:self.state];
  // If no change to the current elevation, don't perform updates
  if (MDCCGFloatEqual(newElevation, self.mdc_currentElevation)) {
    return;
  }
  _currentElevation = newElevation;
  if (gEnablePerformantShadow) {
    [self updateShadow];
  } else {
    self.layer.elevation = newElevation;
  }
  [self mdc_elevationDidChange];

  // The elevation of the normal state controls whether this button is flat or not, and flat buttons
  // have different background color requirements than raised buttons.
  // TODO(ajsecord): Move to MDCFlatButton and update this comment.
  if (state == UIControlStateNormal) {
    [self updateAlphaAndBackgroundColorAnimated:NO];
  }
}

- (void)updateShadow {
  if (_shapedLayer.shapeGenerator == nil) {
    MDCConfigureShadowForView(self,
                              [self.shadowsCollection shadowForElevation:self.mdc_currentElevation],
                              [self shadowColorForState:self.state] ?: MDCShadowColor());
  } else {
    MDCConfigureShadowForViewWithPath(
        self, [self.shadowsCollection shadowForElevation:self.mdc_currentElevation],
        [self shadowColorForState:self.state] ?: MDCShadowColor(), self.layer.shadowPath);
  }
}

#pragma mark - Border Color

- (UIColor *)borderColorForState:(UIControlState)state {
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    state = state & ~UIControlStateDisabled;
  }
  return _borderColors[@(state)] ?: _borderColors[@(UIControlStateNormal)];
}

- (void)setBorderColor:(UIColor *)borderColor forState:(UIControlState)state {
  UIControlState storageState = state;
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    storageState = state & ~UIControlStateDisabled;
  }

  // Only update the backing dictionary if:
  // 1. The `state` argument is the same as the "storage" state, OR
  // 2. There is already a value in the "storage" state.
  if (storageState == state || _borderColors[@(storageState)] != nil) {
    _borderColors[@(storageState)] = borderColor;
    [self updateBorderColor];
  }
}

#pragma mark - Border Width

- (CGFloat)borderWidthForState:(UIControlState)state {
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    state = state & ~UIControlStateDisabled;
  }
  NSNumber *borderWidth = _borderWidths[@(state)];
  if (borderWidth != nil) {
    return (CGFloat)borderWidth.doubleValue;
  }
  return (CGFloat)[_borderWidths[@(UIControlStateNormal)] doubleValue];
}

- (void)setBorderWidth:(CGFloat)borderWidth forState:(UIControlState)state {
  UIControlState storageState = state;
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    storageState = state & ~UIControlStateDisabled;
  }
  // Only update the backing dictionary if:
  // 1. The `state` argument is the same as the "storage" state, OR
  // 2. There is already a value in the "storage" state.
  if (storageState == state || _backgroundColors[@(storageState)] != nil) {
    _borderWidths[@(state)] = @(borderWidth);
    [self updateBorderWidth];
  }
}

- (void)updateBorderWidth {
  NSNumber *width = _borderWidths[@(self.state)];
  if ((width == nil) && self.state != UIControlStateNormal) {
    // We fall back to UIControlStateNormal if there is no value for the current state.
    width = _borderWidths[@(UIControlStateNormal)];
  }
  if (gEnablePerformantShadow) {
    _shapedLayer.shapedBorderWidth = (width != nil) ? (CGFloat)width.doubleValue : 0;
  } else {
    self.layer.shapedBorderWidth = (width != nil) ? (CGFloat)width.doubleValue : 0;
  }
}

#pragma mark - Title Font

- (nonnull UIFont *)titleFontForState:(UIControlState)state {
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    state = state & ~UIControlStateDisabled;
  }
  UIFont *font = _fonts[@(state)] ?: _fonts[@(UIControlStateNormal)];

  if (!font) {
    // TODO(#2709): Have a single source of truth for fonts
    // Migrate to [UIFont standardFont] when possible
    font = [MDCTypography buttonFont];
  }

  if (_mdc_adjustsFontForContentSizeCategory) {
    // Dynamic type is enabled so apply scaling
    if (font.mdc_scalingCurve) {
      font = [font mdc_scaledFontForTraitEnvironment:self];
    } else {
      font = [font mdc_fontSizedForMaterialTextStyle:MDCFontTextStyleButton
                                scaledForDynamicType:YES];
    }
  }
  return font;
}

- (void)setTitleFont:(nullable UIFont *)font forState:(UIControlState)state {
  UIControlState storageState = state;
  // If the `.highlighted` flag is set, turn off the `.disabled` flag
  if ((state & UIControlStateHighlighted) == UIControlStateHighlighted) {
    storageState = state & ~UIControlStateDisabled;
  }

  // Only update the backing dictionary if:
  // 1. The `state` argument is the same as the "storage" state, OR
  // 2. There is already a value in the "storage" state.
  if (storageState == state || _fonts[@(storageState)] != nil) {
    _fonts[@(storageState)] = font;
    [self updateTitleFont];
  }
}

#pragma mark - MaterialElevation

- (CGFloat)mdc_currentElevation {
  return _currentElevation;
}

- (MDCShadowsCollection *)shadowsCollection {
  if (!_shadowsCollection) {
    _shadowsCollection = MDCShadowsCollectionDefault();
  }
  return _shadowsCollection;
}

#pragma mark - Private methods

/**
 The background color that a user would see for this button. If self.backgroundColor is not
 transparent, then returns that. Otherwise, returns self.underlyingColorHint.
 @note If self.underlyingColorHint is not set, then this method will return nil.
 */
- (UIColor *)effectiveBackgroundColor {
  UIColor *backgroundColor = [self backgroundColorForState:self.state];
  if (![self isTransparentColor:backgroundColor]) {
    return backgroundColor;
  } else {
    return self.underlyingColorHint;
  }
}

/** Returns YES if the color is not transparent and is a "dark" color. */
- (BOOL)isDarkColor:(UIColor *)color {
  // TODO: have a components/private/ColorCalculations/MDCColorCalculations.h|m
  //  return ![self isTransparentColor:color] && [QTMColorGroup luminanceOfColor:color] < 0.5;
  return ![self isTransparentColor:color];
}

/** Returns YES if the color is transparent (including a nil color). */
- (BOOL)isTransparentColor:(UIColor *)color {
  return !color || [color isEqual:[UIColor clearColor]] || CGColorGetAlpha(color.CGColor) == 0;
}

- (void)touchDragEnter:(__unused MDCButton *)button forEvent:(UIEvent *)event {
  [self handleBeginTouches:event.allTouches];
}

- (void)touchDragExit:(__unused MDCButton *)button forEvent:(UIEvent *)event {
  CGPoint location = [self locationFromTouches:event.allTouches];
  [self evaporateInkToPoint:location];
}

- (void)handleBeginTouches:(NSSet *)touches {
  [_inkView startTouchBeganAnimationAtPoint:[self locationFromTouches:touches] completion:nil];
}

- (CGPoint)locationFromTouches:(NSSet *)touches {
  UITouch *touch = [touches anyObject];
  return [touch locationInView:self];
}

- (void)evaporateInkToPoint:(CGPoint)toPoint {
  [_inkView startTouchEndedAnimationAtPoint:toPoint completion:nil];
}

- (UIBezierPath *)boundingPath {
  CGSize cornerRadii = CGSizeMake(self.layer.cornerRadius, self.layer.cornerRadius);
  return [UIBezierPath bezierPathWithRoundedRect:self.bounds
                               byRoundingCorners:(UIRectCorner)self.layer.maskedCorners
                                     cornerRadii:cornerRadii];
}

- (UIEdgeInsets)defaultContentEdgeInsets {
  return UIEdgeInsetsMake(8, 16, 8, 16);
}

- (BOOL)shouldHaveOpaqueBackground {
  BOOL isFlatButton = MDCCGFloatIsExactlyZero([self elevationForState:UIControlStateNormal]);
  return !isFlatButton;
}

- (void)updateAlphaAndBackgroundColorAnimated:(BOOL)animated {
  void (^animations)(void) = ^{
    // Set super to avoid overwriting _enabledAlpha
    super.alpha = self.enabled ? self->_enabledAlpha : self.disabledAlpha;
    [self updateBackgroundColor];
  };

  if (animated) {
    [UIView animateWithDuration:MDCButtonAnimationDuration animations:animations];
  } else {
    animations();
  }
}

- (void)updateBackgroundColor {
  // When shapeGenerator is unset then self.layer.shapedBackgroundColor sets the layer's
  // backgroundColor. Whereas when shapeGenerator is set the sublayer's fillColor is set.
  if (gEnablePerformantShadow) {
    _shapedLayer.shapedBackgroundColor = [self backgroundColorForState:self.state];
  } else {
    self.layer.shapedBackgroundColor = [self backgroundColorForState:self.state];
  }
  [self updateDisabledTitleColor];
}

- (void)updateDisabledTitleColor {
  // We only want to automatically set a disabled title color if the user hasn't already provided a
  // value.
  if (_hasCustomDisabledTitleColor) {
    return;
  }
  // Disabled buttons have very low opacity, so we full-opacity text color here to make the text
  // readable. Also, even for non-flat buttons with opaque backgrounds, the correct background color
  // to examine is the underlying color, since disabled buttons are so transparent.
  BOOL darkBackground = [self isDarkColor:[self underlyingColorHint]];
  // We call super here to distinguish between automatic title color assignments and that of users.
  [super setTitleColor:darkBackground ? [UIColor whiteColor] : [UIColor blackColor]
              forState:UIControlStateDisabled];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
  [super setTitleColor:color forState:state];
  if (state == UIControlStateDisabled) {
    _hasCustomDisabledTitleColor = color != nil;
    if (!_hasCustomDisabledTitleColor) {
      [self updateDisabledTitleColor];
    }
  }
}

- (void)updateBorderColor {
  UIColor *color = _borderColors[@(self.state)];
  if (!color && self.state != UIControlStateNormal) {
    // We fall back to UIControlStateNormal if there is no value for the current state.
    color = _borderColors[@(UIControlStateNormal)];
  }
  if (gEnablePerformantShadow) {
    _shapedLayer.shapedBorderColor = color ?: NULL;
  } else {
    self.layer.shapedBorderColor = color ?: NULL;
  }
}

- (void)updateTitleFont {
  if (!self.enableTitleFontForState) {
    return;
  }

  self.titleLabel.font = [self titleFontForState:self.state];

  [self setNeedsLayout];
}

- (void)setShapeGenerator:(id<MDCShapeGenerating>)shapeGenerator {
  if (!UIEdgeInsetsEqualToEdgeInsets(_visibleAreaInsets, UIEdgeInsetsZero) ||
      self.centerVisibleArea) {
    // When visibleAreaInsets or centerVisibleArea is set, custom shapeGenerater is not allow
    // to be set through setter.
    return;
  }

  [self configureLayerWithShapeGenerator:shapeGenerator];
}

- (void)configureLayerWithShapeGenerator:(id<MDCShapeGenerating>)shapeGenerator {
  if (shapeGenerator) {
    self.layer.shadowPath = nil;
  } else {
    if (gEnablePerformantShadow) {
      MDCConfigureShadowForView(
          self, [self.shadowsCollection shadowForElevation:self.mdc_currentElevation],
          [self shadowColorForState:self.state] ?: MDCShadowColor());
    } else {
      self.layer.shadowPath = [self boundingPath].CGPath;
    }
  }

  if (gEnablePerformantShadow) {
    _shapedLayer.shapeGenerator = shapeGenerator;
  } else {
    self.layer.shapeGenerator = shapeGenerator;
  }
  // The imageView is added very early in the lifecycle of a UIButton, therefore we need to move
  // the colorLayer behind the imageView otherwise the image will not show.
  // Because the inkView needs to go below the imageView, but above the colorLayer
  // we need to have the colorLayer be at the back
  if (gEnablePerformantShadow) {
    [_shapedLayer.colorLayer removeFromSuperlayer];
    if (self.enableRippleBehavior) {
      [self.layer insertSublayer:_shapedLayer.colorLayer below:self.rippleView.layer];
    } else {
      [self.layer insertSublayer:_shapedLayer.colorLayer below:self.inkView.layer];
    }
  } else {
    [self.layer.colorLayer removeFromSuperlayer];
    if (self.enableRippleBehavior) {
      [self.layer insertSublayer:self.layer.colorLayer below:self.rippleView.layer];
    } else {
      [self.layer insertSublayer:self.layer.colorLayer below:self.inkView.layer];
    }
  }
  [self updateBackgroundColor];
  [self updateInkForShape];
}

- (id<MDCShapeGenerating>)shapeGenerator {
  if (gEnablePerformantShadow) {
    return _shapedLayer.shapeGenerator;
  }
  return self.layer.shapeGenerator;
}

- (void)updateInkForShape {
  CGRect boundingBox = CGPathGetBoundingBox(gEnablePerformantShadow ? _shapedLayer.shapeLayer.path
                                                                    : self.layer.shapeLayer.path);
  self.inkView.maxRippleRadius =
      (CGFloat)(hypot(CGRectGetHeight(boundingBox), CGRectGetWidth(boundingBox)) / 2 + 10);
  self.inkView.layer.masksToBounds = NO;
  self.rippleView.layer.masksToBounds = NO;
}

#pragma mark - Dynamic Type

- (BOOL)mdc_adjustsFontForContentSizeCategory {
  return _mdc_adjustsFontForContentSizeCategory;
}

- (void)mdc_setAdjustsFontForContentSizeCategory:(BOOL)adjusts {
  _mdc_adjustsFontForContentSizeCategory = adjusts;
  if (_mdc_adjustsFontForContentSizeCategory) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
  } else {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIContentSizeCategoryDidChangeNotification
                                                  object:nil];
  }

  [self updateTitleFont];
}

- (void)contentSizeCategoryDidChange:(__unused NSNotification *)notification {
  [self updateTitleFont];

  [self sizeToFit];
}

#pragma mark - Deprecations

- (void)setUnderlyingColor:(UIColor *)underlyingColor {
  [self setUnderlyingColorHint:underlyingColor];
}

#pragma mark - Visible area

- (void)setCenterVisibleArea:(BOOL)centerVisibleArea {
  if (_centerVisibleArea == centerVisibleArea) {
    return;
  }

  _centerVisibleArea = centerVisibleArea;

  if (!centerVisibleArea && UIEdgeInsetsEqualToEdgeInsets(_visibleAreaInsets, UIEdgeInsetsZero)) {
    self.shapeGenerator = nil;

    if (_cornerRadiusObserverAdded) {
      [self.layer removeObserver:self
                      forKeyPath:NSStringFromSelector(@selector(cornerRadius))
                         context:kKVOContextCornerRadius];
      _cornerRadiusObserverAdded = NO;
    }
  } else {
    UIEdgeInsets visibleAreaInsets = self.visibleAreaInsets;
    MDCRectangleShapeGenerator *shapeGenerator =
        [self generateShapeWithCornerRadius:self.layer.cornerRadius
                          visibleAreaInsets:visibleAreaInsets];
    [self configureLayerWithShapeGenerator:shapeGenerator];

    if (!_cornerRadiusObserverAdded) {
      [self.layer addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(cornerRadius))
                      options:NSKeyValueObservingOptionNew
                      context:kKVOContextCornerRadius];
      _cornerRadiusObserverAdded = YES;
    }
  }
}

- (void)setVisibleAreaInsets:(UIEdgeInsets)visibleAreaInsets {
  if (UIEdgeInsetsEqualToEdgeInsets(visibleAreaInsets, _visibleAreaInsets)) {
    return;
  }

  _visibleAreaInsets = visibleAreaInsets;

  if (UIEdgeInsetsEqualToEdgeInsets(visibleAreaInsets, UIEdgeInsetsZero) &&
      !self.centerVisibleArea) {
    self.shapeGenerator = nil;

    if (_cornerRadiusObserverAdded) {
      [self.layer removeObserver:self
                      forKeyPath:NSStringFromSelector(@selector(cornerRadius))
                         context:kKVOContextCornerRadius];
      _cornerRadiusObserverAdded = NO;
    }
  } else {
    MDCRectangleShapeGenerator *shapeGenerator =
        [self generateShapeWithCornerRadius:self.layer.cornerRadius
                          visibleAreaInsets:visibleAreaInsets];
    [self configureLayerWithShapeGenerator:shapeGenerator];

    if (!_cornerRadiusObserverAdded) {
      [self.layer addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(cornerRadius))
                      options:NSKeyValueObservingOptionNew
                      context:kKVOContextCornerRadius];
      _cornerRadiusObserverAdded = YES;
    }
  }
}

- (UIEdgeInsets)visibleAreaInsets {
  if (!UIEdgeInsetsEqualToEdgeInsets(_visibleAreaInsets, UIEdgeInsetsZero)) {
    // Use custom visibleAreaInsets value when user sets it.
    return _visibleAreaInsets;
  }

  UIEdgeInsets visibleAreaInsets = UIEdgeInsetsZero;
  if (self.centerVisibleArea) {
    CGSize visibleAreaSize;
    if (self.layoutTitleWithConstraints) {
      visibleAreaSize =
          [self systemLayoutSizeFittingSize:CGSizeMake(self.bounds.size.width,
                                                       UILayoutFittingCompressedSize.height)];
    } else {
      visibleAreaSize = [self sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    }
    CGFloat additionalRequiredHeight =
        MAX(0, CGRectGetHeight(self.bounds) - visibleAreaSize.height);
    CGFloat additionalRequiredWidth = MAX(0, CGRectGetWidth(self.bounds) - visibleAreaSize.width);
    visibleAreaInsets.top = ceil(additionalRequiredHeight * 0.5f);
    visibleAreaInsets.bottom = additionalRequiredHeight - visibleAreaInsets.top;
    visibleAreaInsets.left = ceil(additionalRequiredWidth * 0.5f);
    visibleAreaInsets.right = additionalRequiredWidth - visibleAreaInsets.left;
  }

  return visibleAreaInsets;
}

- (UILayoutGuide *)visibleAreaLayoutGuide {
  if (!_visibleAreaLayoutGuide) {
    _visibleAreaLayoutGuide = [[UILayoutGuide alloc] init];
    [self addLayoutGuide:_visibleAreaLayoutGuide];
    _visibleAreaLayoutGuideView = [[UIView alloc] init];
    _visibleAreaLayoutGuideView.userInteractionEnabled = NO;
    [self insertSubview:_visibleAreaLayoutGuideView atIndex:0];
    self.visibleAreaLayoutGuideView.frame =
        UIEdgeInsetsInsetRect(self.bounds, self.visibleAreaInsets);

    [_visibleAreaLayoutGuide.leftAnchor
        constraintEqualToAnchor:_visibleAreaLayoutGuideView.leftAnchor]
        .active = YES;
    [_visibleAreaLayoutGuide.rightAnchor
        constraintEqualToAnchor:_visibleAreaLayoutGuideView.rightAnchor]
        .active = YES;
    [_visibleAreaLayoutGuide.topAnchor
        constraintEqualToAnchor:_visibleAreaLayoutGuideView.topAnchor]
        .active = YES;
    [_visibleAreaLayoutGuide.bottomAnchor
        constraintEqualToAnchor:_visibleAreaLayoutGuideView.bottomAnchor]
        .active = YES;
  }
  return _visibleAreaLayoutGuide;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == kKVOContextCornerRadius) {
    if ((!UIEdgeInsetsEqualToEdgeInsets(self.visibleAreaInsets, UIEdgeInsetsZero) ||
         self.centerVisibleArea) &&
        self.shapeGenerator) {
      MDCRectangleShapeGenerator *shapeGenerator =
          [self generateShapeWithCornerRadius:self.layer.cornerRadius
                            visibleAreaInsets:self.visibleAreaInsets];
      [self configureLayerWithShapeGenerator:shapeGenerator];
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (MDCRectangleShapeGenerator *)generateShapeWithCornerRadius:(CGFloat)cornerRadius
                                            visibleAreaInsets:(UIEdgeInsets)visibleAreaInsets {
  MDCRectangleShapeGenerator *shapeGenerator = [[MDCRectangleShapeGenerator alloc] init];
  MDCCornerTreatment *cornerTreatment =
      [[MDCRoundedCornerTreatment alloc] initWithRadius:cornerRadius];
  [shapeGenerator setCorners:cornerTreatment];
  shapeGenerator.topLeftCornerOffset = CGPointMake(visibleAreaInsets.left, visibleAreaInsets.top);
  shapeGenerator.topRightCornerOffset =
      CGPointMake(-visibleAreaInsets.right, visibleAreaInsets.top);
  shapeGenerator.bottomLeftCornerOffset =
      CGPointMake(visibleAreaInsets.left, -visibleAreaInsets.bottom);
  shapeGenerator.bottomRightCornerOffset =
      CGPointMake(-visibleAreaInsets.right, -visibleAreaInsets.bottom);
  return shapeGenerator;
}

#pragma mark Multi-line Minimum And Maximum Sizing Inference

- (BOOL)shouldInferMinimumAndMaximumSize {
  return (self.inferMinimumAndMaximumSizeWhenMultiline && self.titleLabel.numberOfLines != 1 &&
          self.titleLabel.text.length > 0);
}

- (void)setInferMinimumAndMaximumSizeWhenMultiline:(BOOL)inferMinimumAndMaximumSizeWhenMultiline {
  _inferMinimumAndMaximumSizeWhenMultiline = inferMinimumAndMaximumSizeWhenMultiline;
  if (!_inferMinimumAndMaximumSizeWhenMultiline) {
    self.minimumSize = CGSizeZero;
    self.maximumSize = CGSizeZero;
  }
  [self setNeedsLayout];
  // Call -layoutIfNeeded in addition to -setNeedsLayout. If in a Manual Layout environment, the
  // client will probably call -sizeToFit: after enabling this flag, like the docs suggest. We want
  // the pending layout pass to happen before they are able to do that, so minimumSize and
  // maximumSize are already set when it happens.
  [self layoutIfNeeded];
}

- (void)inferMinimumAndMaximumSize {
  CGSize buttonSize = self.bounds.size;
  CGSize sizeShrunkFromVisibleAreaInsets =
      CGSizeShrinkWithInsets(buttonSize, self.visibleAreaInsets);
  CGSize sizeShrunkFromContentEdgeInsets =
      CGSizeShrinkWithInsets(sizeShrunkFromVisibleAreaInsets, self.contentEdgeInsets);
  CGSize boundingSizeForLabel = sizeShrunkFromContentEdgeInsets;
  if ([self imageForState:self.state]) {
    boundingSizeForLabel.width -= CGRectGetWidth(self.imageView.frame);
  }
  boundingSizeForLabel.height = CGFLOAT_MAX;
  CGSize sizeThatFitsLabel = [self.titleLabel sizeThatFits:boundingSizeForLabel];
  CGSize sizeShrunkFromContentEdgeInsetsWithNewHeight =
      CGSizeMake(sizeShrunkFromContentEdgeInsets.width, sizeThatFitsLabel.height);
  CGSize sizeExpandedFromContentEdgeInsets =
      CGSizeExpandWithInsets(sizeShrunkFromContentEdgeInsetsWithNewHeight, self.contentEdgeInsets);
  CGSize sizeExpandedFromVisibleAreaInsets =
      CGSizeExpandWithInsets(sizeExpandedFromContentEdgeInsets, self.visibleAreaInsets);
  self.minimumSize = sizeExpandedFromVisibleAreaInsets;
  self.maximumSize = sizeExpandedFromVisibleAreaInsets;

  if (!CGSizeEqualToSize(sizeExpandedFromVisibleAreaInsets,
                         self.lastRecordedIntrinsicContentSize)) {
    [self invalidateIntrinsicContentSize];
  }
}

#pragma mark - Enabling multi-line layout

- (void)setLayoutTitleWithConstraints:(BOOL)layoutTitleWithConstraints {
  if (_layoutTitleWithConstraints == layoutTitleWithConstraints) {
    return;
  }

  _layoutTitleWithConstraints = layoutTitleWithConstraints;

  if (_layoutTitleWithConstraints) {
    self.titleTopConstraint = [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor];
    self.titleBottomConstraint =
        [self.titleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor];
    self.titleLeadingConstraint =
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
    self.titleTrailingConstraint =
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor];
    self.titleTopConstraint.active = YES;
    self.titleBottomConstraint.active = YES;
    self.titleLeadingConstraint.active = YES;
    self.titleTrailingConstraint.active = YES;

    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                       forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired
                                       forAxis:UILayoutConstraintAxisVertical];

    [self updateTitleLabelConstraint];
  } else {
    self.titleTopConstraint.active = NO;
    self.titleBottomConstraint.active = NO;
    self.titleLeadingConstraint.active = NO;
    self.titleTrailingConstraint.active = NO;
    self.titleTopConstraint = nil;
    self.titleBottomConstraint = nil;
    self.titleLeadingConstraint = nil;
    self.titleTrailingConstraint = nil;
  }
}

- (void)updateTitleLabelConstraint {
  self.titleTopConstraint.constant = self.contentEdgeInsets.top;
  self.titleBottomConstraint.constant = -self.contentEdgeInsets.bottom;
  self.titleLeadingConstraint.constant = self.contentEdgeInsets.left;
  self.titleTrailingConstraint.constant = -self.contentEdgeInsets.right;
}

- (void)setContentEdgeInsets:(UIEdgeInsets)contentEdgeInsets {
  [super setContentEdgeInsets:contentEdgeInsets];

  if (self.layoutTitleWithConstraints) {
    [self updateTitleLabelConstraint];
  }
}

#pragma mark - Performant Shadow Toggle

+ (void)setEnablePerformantShadow:(BOOL)enable {
  gEnablePerformantShadow = enable;
}

+ (BOOL)enablePerformantShadow {
  return gEnablePerformantShadow;
}

@end
