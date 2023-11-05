//
//  ESRowView.h
//
//  Created by Steve Pucci 05 Feb 2012
//  Copyright Emerald Sequoia LLC 2012. All rights reserved.
//

#ifndef _ESROWVIEW_H_
#define _ESROWVIEW_H_

/*! This class lays out all of its widgets in a row, giving equal space to each one */
@interface ESUniformRowView : UIView {
    CGFloat spacing;
    CGFloat edgeMargin;
}

@property(nonatomic) CGFloat spacing;
@property(nonatomic) CGFloat edgeMargin;

@end

#endif  // _ESROWVIEW_H_
