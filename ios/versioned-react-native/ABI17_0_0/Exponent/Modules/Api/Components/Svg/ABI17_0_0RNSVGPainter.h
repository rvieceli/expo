/**
 * Copyright (c) 2015-present, Horcrux.
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI17_0_0RCTConvert+RNSVG.h"
#import "ABI17_0_0RNSVGBrushType.h"
#import "ABI17_0_0RNSVGUnits.h"

@interface ABI17_0_0RNSVGPainter : NSObject

- (instancetype)initWithPointsArray:(NSArray<NSString *> *)pointsArray NS_DESIGNATED_INITIALIZER;

- (void)paint:(CGContextRef)context;

- (void)setUnits:(ABI17_0_0RNSVGUnits)unit;

- (void)setUserSpaceBoundingBox:(CGRect)userSpaceBoundingBox;

- (void)setTransform:(CGAffineTransform)transform;

- (void)setLinearGradientColors:(NSArray<NSNumber *> *)colors;

- (void)setRadialGradientColors:(NSArray<NSNumber *> *)colors;

@end
