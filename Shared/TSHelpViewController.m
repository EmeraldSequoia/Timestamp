//
//  TSHelpViewController.m
//  timestamp
//
//  Created by Steve Pucci on 5/3/10.
//  Copyright 2010 Emerald Sequoia LLC. All rights reserved.
//

#import "TSHelpViewController.h"
#import "TSRootViewController.h"
#import "TSSharedAppDelegate.h"

@implementation TSHelpViewController

@synthesize webView;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    assert(webView);
    webView.navigationDelegate = self;
    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Help/Help.html"]]]];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size 
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    printf("viewWillTransitionToSize %g %g\n", size.width, size.height);
    // Figure out effective orientation here.
}

// - (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
//     //printf("help view did rotate\n");
//     [TSSharedAppDelegate setNewOrientation:self.interfaceOrientation];
// }

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURLRequest *request = navigationAction.request;
    NSURL *url = [request URL];
    if ([url isFileURL]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:NULL];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *title = [[[[webView.URL relativeString] lastPathComponent] stringByReplacingOccurrencesOfString:@".html" withString:@""] stringByReplacingOccurrencesOfString:@"%20" withString:@" "];
    NSRange tagRange = [title rangeOfString:@"#"];
    if (tagRange.location != NSNotFound) {
	title = [title substringToIndex:tagRange.location];
    }
    if ([title caseInsensitiveCompare:@"ReleaseNotesGen"] == NSOrderedSame) {
	title = @"Release Notes";
    }
    self.title = title;
}

- (void)dealloc {
    [webView release];
    webView = nil;
    [super dealloc];
}

@end
