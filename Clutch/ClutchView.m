//
// Copyright 2012 Twitter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Clutch/ClutchView.h>
#import "ClutchJSONKit.h"
#import "UIDevice+IdentifierAddition.h"

#define DEV_TOOLBAR_TAG 928

@implementation ClutchView

@synthesize webView = _webView;
@synthesize scrollView = _scrollView;
@synthesize slug = _slug;
@synthesize loadingView = _loadingView;
@synthesize scrollViewOriginalDelegate = _scrollViewOriginalDelegate;
@synthesize scrollDelegate = _scrollDelegate;
@synthesize delegate = _delegate;

#pragma mark - View lifecycle

- (void)setupWebView {
    self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(0,
                                                               0,
                                                               self.frame.size.width,
                                                               self.frame.size.height)];
    self.opaque = FALSE;
    self.webView.backgroundColor = [UIColor clearColor];
    
    self.webView.delegate = self;
    
    self.webView.opaque = FALSE;
    self.webView.backgroundColor = [UIColor clearColor];
    
    self.webView.dataDetectorTypes = UIDataDetectorTypeNone;
    [self.webView setScalesPageToFit:YES];
    
    // Try to find the scrollView so that we can make it feel more natural
    id sv = [[self.webView subviews] lastObject];
    if([sv respondsToSelector:@selector(setScrollEnabled:)]) {
        self.scrollView = (UIScrollView *)sv;
        self.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
        self.scrollViewOriginalDelegate = self.scrollView.delegate;
        self.scrollView.delegate = self;
    }
    // Hide all of the shadow layers
    for (UIView *shadowView in [[[self.webView subviews] objectAtIndex:0] subviews]) {
        [shadowView setHidden:YES];
    }
    // Unhide the layer that shouldn't be hidden
    [[[[[self.webView subviews] objectAtIndex:0] subviews] lastObject] setHidden:NO];
    
    [self addSubview:self.webView];
}

- (void)setupLoadingView {
    self.loadingView = [[ClutchLoadingView alloc] init];
    [self addSubview:self.loadingView];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupWebView];
        [self setupLoadingView];
        _loaded = FALSE;
        _lastBottomReached = 0;
        _methodQueue = [[[NSMutableArray alloc] init] retain];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reloadWebView)
                                                     name:@"ClutchReloadView"
                                                   object:nil];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame andSlug:(NSString *)slug {
    self = [self initWithFrame:frame];
    self.slug = slug;
    return self;
}

- (void) dealloc {
    self.webView = nil;
    self.scrollView = nil;
    self.slug = nil;
    self.loadingView = nil;
    self.scrollViewOriginalDelegate = nil;
    self.scrollDelegate = nil;
    self.delegate = nil;
    [_methodQueue release];
    _methodQueue = nil;
    [super dealloc];
}

#pragma mark - View reloading

- (void)reloadWebView {
    [self loadWebView];
}

#pragma mark - Development Toolbar

- (void)stopButtonPressed {
    [self.webView stopLoading];
}

- (void)setupToolbarWithButton:(UIBarButtonItem *)item {
    UIToolbar *toolbar = (UIToolbar *)[self viewWithTag:DEV_TOOLBAR_TAG];
    if(!toolbar) {
        return;
    }
    
    UIBarButtonItem *spacer = [[[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                target:nil
                                action:nil] autorelease];
    
    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 20)] autorelease];
    label.textAlignment = UITextAlignmentRight;
    label.text = @"Clutch Development Mode";
    label.textColor = [UIColor colorWithRed:153.0f/255.0f green:204.0f/255.0f blue:102.0f/255.0f alpha:1];
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    UIBarButtonItem *labelButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:label] autorelease];
    
    [toolbar setItems:[NSArray arrayWithObjects:item, spacer, labelButtonItem, nil]];
}

- (void)setToolbarStop {
    UIBarButtonItem *stopButton = [[[UIBarButtonItem alloc]
                                    initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                    target:self
                                    action:@selector(stopButtonPressed)] autorelease];
    [self setupToolbarWithButton:stopButton];
}

- (void)setToolbarRefresh {
    UIBarButtonItem *refreshButton = [[[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                       target:self
                                       action:@selector(reloadWebView)] autorelease];
    [self setupToolbarWithButton:refreshButton];
}

- (void)showOrHideDevToolbar {
    BOOL shouldShow = ([[[ClutchConf conf] objectForKey:@"_dev"] boolValue] &&
                       [[[ClutchConf conf] objectForKey:@"_toolbar"] boolValue]);
    if([self viewWithTag:DEV_TOOLBAR_TAG] != nil) {
        if(!shouldShow) {
            [[self viewWithTag:DEV_TOOLBAR_TAG] removeFromSuperview];
        }
        return;
    }
    if(!shouldShow) {
        return;
    }
    UIToolbar *toolbar = [[UIToolbar alloc] init];
    toolbar.tag = DEV_TOOLBAR_TAG;
    toolbar.frame = CGRectMake(self.frame.origin.x,
                               self.frame.origin.y + self.frame.size.height - 50,
                               self.frame.size.width,
                               50);
    [toolbar setBarStyle:UIBarStyleBlack];
    [toolbar setTranslucent:YES];
    [self addSubview:toolbar];
}

- (void)loadWebView {
    if(!self.webView) {
        return;
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    if([[[ClutchConf conf] objectForKey:@"_dev"] boolValue]) {
        NSLog(@"(Clutch) Loading '%@' in development mode.\n", self.slug);
        NSString *urlStr = [NSString stringWithFormat:@"%@%@/index.html", [[ClutchConf conf] objectForKey:@"_url"], self.slug];
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
    } else {
        NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        NSString *cacheDir = [NSString stringWithFormat:@"%@/Library/Caches/__clutchcache/%@/", NSHomeDirectory(), bundleVersion];
        NSString *filePath = [NSString stringWithFormat:@"%@%@/index.html", cacheDir, self.slug];
        if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            NSLog(@"(Clutch) Loading '%@' from download cache.\n", self.slug);
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            [self.webView loadRequest:[NSURLRequest requestWithURL:fileURL]];
        } else {
            NSString *bundleDir = [ClutchConf getClutchSubdir];
            if(bundleDir) {
                // TODO: Display a page if they forgot to bundle with it, or if the slug isn't found.
                NSString *bundleFilePath = [NSString stringWithFormat:@"%@/%@/index.html", bundleDir, self.slug];
                if([[NSFileManager defaultManager] fileExistsAtPath:bundleFilePath]) {
                    NSLog(@"(Clutch) Loading '%@' from bundle.\n", self.slug);
                    NSURL *bundleFileURL = [NSURL fileURLWithPath:bundleFilePath];
                    [self.webView loadRequest:[NSURLRequest requestWithURL:bundleFileURL]];
                } else {
                    NSLog(@"(Clutch) ERROR! We have nothing to display for %@.\n", self.slug);
                }
            } else {
                NSLog(@"(Clutch) ERROR! We have nothing to display for %@.\n", self.slug);
            }
        }
    }
    [self showOrHideDevToolbar];
}

#pragma mark - View appearance

- (void)viewDidAppear:(BOOL)animated {
    if(self.webView == nil) {
        [self setupWebView];
        [self loadWebView];
    }
    if(self.loadingView == nil) {
        [self setupLoadingView];
    }
    [self callMethod:@"clutch.viewDidAppear"];
    [[ClutchStats sharedClient] log:@"viewDidAppear" withData:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               self.slug, @"slug", nil]];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self callMethod:@"clutch.viewDidDisappear"];
    [[ClutchStats sharedClient] log:@"viewDidDisappear" withData:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               self.slug, @"slug", nil]];
}

#pragma mark - Method Calling

- (void)runMethodQueue {
    while([_methodQueue count]) {
        NSDictionary *obj = [_methodQueue objectAtIndex:0];
        NSString *method = [obj objectForKey:@"method"];
        NSDictionary *params = [obj objectForKey:@"params"];
        if(params) {
            [self callMethod:method withParams:params];
        } else {
            [self callMethod:method];
        }
        [_methodQueue removeObjectAtIndex:0];
    }
}

- (void)callMethod:(NSString *)method {
    if(_loaded) {
        NSString *js = [NSString stringWithFormat:@"Clutch.Core.methodCalled('%@', {})", method];
        [self.webView stringByEvaluatingJavaScriptFromString:js];
    } else {
        NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                             method, @"method",
                             nil];
        [_methodQueue addObject:obj];
    }
}

- (void)callMethod:(NSString *)method withParams:(NSDictionary *)params {
    if(_loaded) {
        NSString *js = [NSString stringWithFormat:@"Clutch.Core.methodCalled('%@', %@)", method, [ClutchJSONEncoder jsonString:params]];
        [self.webView stringByEvaluatingJavaScriptFromString:js];
    } else {
        NSDictionary *obj = [NSDictionary dictionaryWithObjectsAndKeys:
                             method, @"method",
                             params, @"params",
                             nil];
        [_methodQueue addObject:obj];
    }
}

- (void)loadingBeginMethodCalledWithParams:(NSDictionary *)params {
    NSString *text = [params objectForKey:@"text"];
    NSNumber *top = [params objectForKey:@"top"];
    if(text == nil || [text isEqual:[NSNull null]]) {
        if(top == nil || [top isEqual:[NSNull null]]) {
            [self.loadingView show:nil];
        } else {
            [self.loadingView show:nil top:[top floatValue]];
        }
    } else {
        if(top == nil || [top isEqual:[NSNull null]]) {
            [self.loadingView show:text];
        } else {
            [self.loadingView show:text top:[top floatValue]];
        }
    }
}

- (void)loadingEndMethodCalled {
    [self.loadingView hide];
}

- (void)methodCalled:(NSString *)methodName withParams:(NSDictionary *)params callbackNum:(NSString *)callbackNum {
    if([methodName isEqualToString:@"clutch.loading.begin"]) {
        [self loadingBeginMethodCalledWithParams:params];
    } else if([methodName isEqualToString:@"clutch.loading.end"]) {
        [self loadingEndMethodCalled];
    }
    if([self.delegate respondsToSelector:@selector(clutchView:methodCalled:withParams:callback:)]) {
        [self.delegate clutchView:self methodCalled:methodName withParams:params callback:[[^(id resp) {
            if(![callbackNum isEqualToString:@"0"]) {
                NSString *js = [NSString stringWithFormat:@"Clutch.Core.callCallback(%@, %@)", callbackNum, [ClutchJSONEncoder jsonString:resp]];
                [self.webView stringByEvaluatingJavaScriptFromString:js];
            }
        } copy] autorelease]];
    } else if([self.delegate respondsToSelector:@selector(clutchView:methodCalled:withParams:)]) {
        [self.delegate clutchView:self methodCalled:methodName withParams:params];
    }
}

#pragma mark - Misc

+ (NSString *)getDeviceIdentifier {
    return [[UIDevice currentDevice] uniqueGlobalDeviceIdentifier];
}

+ (void)logDeviceIdentifier {
    NSLog(@"Clutch Device Identifier: %@\n", [ClutchView getDeviceIdentifier]);
}

+ (void)prepareForAnimation:(UIViewController *)viewController success:(void(^)(void))block_ {
    [ClutchView prepareForDisplay:viewController success:block_];
}

+ (void)prepareForDisplay:(UIViewController *)viewController {
    [ClutchView prepareForDisplay:viewController success:nil];
}

+ (void)prepareForDisplay:(UIViewController *)viewController success:(void(^)(void))block_ {
    [viewController view];
    if(block_ != nil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_current_queue(), block_);
    }
}

#pragma mark - Overridden setters

- (void)setSlug:(NSString *)slug {
    _loaded = FALSE;
    [slug retain];
    [_slug release];
    _slug = slug;
    [self loadWebView];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *path = [request URL].path;
    if([path hasPrefix:@"/___mobilerpc___/"]) {
        NSArray *paths = [path componentsSeparatedByString:@"/"];
        NSString *methodName = [paths objectAtIndex:2];
        NSString *callbackNum = [paths objectAtIndex:3];
        NSDictionary *params = [NSDictionary dictionary];
        if([paths objectAtIndex:4]) {
            NSArray *subarray = [paths subarrayWithRange:NSMakeRange(4, [paths count] - 4)];
            NSString *paramsJSON = [[subarray componentsJoinedByString:@"/"]
                                    stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
            const unsigned char *utf8String = (const unsigned char *)[paramsJSON UTF8String];
            if(utf8String == NULL) {
                params = nil;
            } else {
                size_t               utf8Length = strlen((const char *)utf8String); 
                params = [[ClutchJSONDecoder decoder] objectWithUTF8String:utf8String length:utf8Length error:nil];
            }
        }
        [self methodCalled:methodName withParams:params callbackNum:callbackNum];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    _loaded = FALSE;
    [self setToolbarStop];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    _loaded = FALSE;
    NSString *errorString = [error localizedDescription];
    NSLog(@"(Clutch) ClutchView for slug %@ failed to load with error: %@\n", self.slug, errorString);
    [self setToolbarRefresh];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {    
    _loaded = TRUE;
    
    [self setToolbarRefresh];
    
    if([self.delegate respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [self.delegate webViewDidFinishLoad:webView];
    }
    
    [self runMethodQueue];
    
}

#pragma mark - Scroll view

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidScroll:scrollView];
	}
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidScroll:)]) {
        [self.scrollDelegate scrollViewDidScroll:scrollView];
	}
    
    if(self.scrollView.contentOffset.y >=  self.scrollView.contentSize.height - self.scrollView.frame.size.height) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if((now - _lastBottomReached) > 0.5) {
            [self.webView stringByEvaluatingJavaScriptFromString:@"Clutch.Core.bottomReached()"];
            _lastBottomReached = now;
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)]) {
        [self.scrollDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidEndDecelerating:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [self.scrollDelegate scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidEndScrollingAnimation:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [self.scrollDelegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidEndZooming:withView:atScale:)]) {
        [self.scrollDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
    }
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidScrollToTop:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidScrollToTop:)]) {
        [self.scrollDelegate scrollViewDidScrollToTop:scrollView];
    }
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewDidZoom:)]) {
        [self.scrollViewOriginalDelegate scrollViewDidZoom:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewDidZoom:)]) {
        [self.scrollDelegate scrollViewDidZoom:scrollView];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [self.scrollDelegate scrollViewShouldScrollToTop:scrollView];
    }
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewShouldScrollToTop:)]) {
        return [self.scrollViewOriginalDelegate scrollViewShouldScrollToTop:scrollView];
    }
    return TRUE;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [self.scrollViewOriginalDelegate scrollViewWillBeginDecelerating:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewWillBeginDecelerating:)]) {
        [self.scrollDelegate scrollViewWillBeginDecelerating:scrollView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.scrollViewOriginalDelegate scrollViewWillBeginDragging:scrollView];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewWillBeginDragging:)]) {
        [self.scrollDelegate scrollViewWillBeginDragging:scrollView];
    }
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) {
        [self.scrollViewOriginalDelegate scrollViewWillBeginZooming:scrollView withView:view];
    }
    if([self.scrollDelegate respondsToSelector:@selector(scrollViewWillBeginZooming:withView:)]) {
        [self.scrollDelegate scrollViewWillBeginZooming:scrollView withView:view];
    }
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if([self.scrollDelegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
        return [self.scrollDelegate viewForZoomingInScrollView:scrollView];
    }
    if([self.scrollViewOriginalDelegate respondsToSelector:@selector(viewForZoomingInScrollView:)]) {
        return [self.scrollViewOriginalDelegate viewForZoomingInScrollView:scrollView];
    }
    return nil;
}

@end
