/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <SafariServices/SafariServices.h>

// There is no in-app browser, so the controller hands its URL to the system
// (UIApplication's openURL:) when it appears, then dismisses itself the way
// SFSafariViewController's Done button would.

@implementation SFSafariViewControllerConfiguration
@synthesize entersReaderIfAvailable = _entersReaderIfAvailable, barCollapsingEnabled = _barCollapsingEnabled;

- (instancetype)init
{
    if ((self = [super init]))
        _barCollapsingEnabled = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    SFSafariViewControllerConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.entersReaderIfAvailable = _entersReaderIfAvailable;
    copy.barCollapsingEnabled = _barCollapsingEnabled;
    return copy;
}
@end

@implementation SFSafariViewController {
    NSURL *_URL;
    BOOL _opened;
}
@synthesize delegate = _delegate, configuration = _configuration;
@synthesize preferredBarTintColor = _preferredBarTintColor, preferredControlTintColor = _preferredControlTintColor;
@synthesize dismissButtonStyle = _dismissButtonStyle;

- (instancetype)initWithURL:(NSURL *)URL configuration:(SFSafariViewControllerConfiguration *)configuration
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _URL = [URL copy];
        _configuration = configuration ? [configuration copy] : [[SFSafariViewControllerConfiguration alloc] init];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL
{
    return [self initWithURL:URL configuration:nil];
}

- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)entersReaderIfAvailable
{
    SFSafariViewControllerConfiguration *configuration = [[SFSafariViewControllerConfiguration alloc] init];
    configuration.entersReaderIfAvailable = entersReaderIfAvailable;
    self = [self initWithURL:URL configuration:configuration];
    [configuration release];
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_opened)
        return;
    _opened = YES;
    [[UIApplication sharedApplication] openURL:_URL options:@{} completionHandler:^(BOOL success) {
        id<SFSafariViewControllerDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(safariViewController:didCompleteInitialLoad:)])
            [delegate safariViewController:self didCompleteInitialLoad:success];
        [self.presentingViewController dismissViewControllerAnimated:animated completion:^{
            if ([delegate respondsToSelector:@selector(safariViewControllerDidFinish:)])
                [delegate safariViewControllerDidFinish:self];
        }];
    }];
}

- (void)dealloc
{
    [_URL release];
    [_configuration release];
    [_preferredBarTintColor release];
    [_preferredControlTintColor release];
    [super dealloc];
}

@end
