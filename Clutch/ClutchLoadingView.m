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

#import <Clutch/ClutchLoadingView.h>

@implementation ClutchLoadingView

#define HEIGHT 56
#define Y_OFFSET 180
#define SPINNER_WIDTH 64

- (id)init {
    if ((self = [super init])) {
		
		self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.7];
		self.layer.cornerRadius = 8;
		
		loadingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		loadingLabel.backgroundColor = [UIColor clearColor];
		loadingLabel.font = [UIFont boldSystemFontOfSize:20];
		loadingLabel.textColor = [UIColor whiteColor];
		
		[self addSubview:loadingLabel];
		
		spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		spinner.center = CGPointMake(30, HEIGHT / 2);
		spinner.alpha = 1.0;
		
		[self addSubview:spinner];
		
		[spinner startAnimating];
		
		self.hidden = YES;
    }
    return self;
}

- (void)show:(NSString *)text {
    [self show:text top:Y_OFFSET];
}

- (void)show:(NSString *)text top:(float)top {
    if(text) {
        loadingLabel.text = text;
    } else {
        loadingLabel.text = @"Loading...";
    }
    
    CGSize labelSize = [loadingLabel.text sizeWithFont:loadingLabel.font];
	loadingLabel.frame = CGRectMake(SPINNER_WIDTH, 16, labelSize.width, labelSize.height);
	
	float viewWidth = SPINNER_WIDTH + labelSize.width + 10;
	self.frame = CGRectMake((320 - viewWidth) / 2, top, viewWidth, HEIGHT);
	
	self.hidden = NO;
}

- (void)hide {
	self.hidden = YES;
}

- (void)dealloc {
	[loadingLabel release];
	[spinner release];
    [super dealloc];
}

@end
