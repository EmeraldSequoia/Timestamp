//
//  ESRowView.m
//
//  Created by Steve Pucci 05 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#import "ESRowView.h"

@implementation ESUniformRowView

@synthesize spacing, edgeMargin;

#define DEFAULT_SPACING 5
#define DEFAULT_EDGE_MARGIN 5

- (id)initWithFrame:(CGRect)aRect {
    [super initWithFrame:aRect];
    // Default margins:
    spacing = DEFAULT_SPACING;
    edgeMargin = DEFAULT_EDGE_MARGIN;
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    [super initWithCoder:decoder];
    // Default margins:
    spacing = DEFAULT_SPACING;
    edgeMargin = DEFAULT_EDGE_MARGIN;
    return self;
}

- (void)layoutSubviews {
    CGRect myFrame = self.frame;
    NSArray *subviews = self.subviews;
    NSInteger subviewCount = [subviews count];
    if (subviewCount == 0) {
        return;
    }
    CGFloat leftMargin = edgeMargin;
    CGFloat rightMargin = edgeMargin;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets edgeInsets = self.safeAreaInsets;
        leftMargin += edgeInsets.left;
        rightMargin += edgeInsets.right;
    }
    CGFloat widthPerSubview = (myFrame.size.width - (leftMargin + rightMargin) - (subviewCount - 1) * spacing) / subviewCount;
    CGFloat height = myFrame.size.height;
    //printf("layoutSubviews overall width %.1f, widthPerSubview %.1f\n",
    //       myFrame.size.width, widthPerSubview);
    int i = 0;
    for (UIView *subview in subviews) {
        subview.frame = CGRectMake(leftMargin + i * (widthPerSubview + spacing), 0, widthPerSubview, height);
        //printf("Placing subview %d at %.1f\n", i, edgeMargin + i * (widthPerSubview + spacing));
        i++;
    }
}

@end
