//
//  TSHelpViewController.h
//  timestamp
//
//  Created by Steve Pucci on 5/3/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>


@interface TSHelpViewController : UIViewController<WKNavigationDelegate> {
    WKWebView     *webView;
    bool          fullyOnScreen;
}

@property (nonatomic, retain) IBOutlet WKWebView *webView;

@end
