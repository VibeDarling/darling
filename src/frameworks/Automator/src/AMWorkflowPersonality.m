/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <Automator/AMWorkflowPersonality.h>
#import <Automator/AMGeneralWorkflowPersonality.h>
#import <Automator/AMApplicationWorkflowPersonality.h>
#import <Automator/Automator.h>
#import "AMStubSignature.h"
#include <dispatch/dispatch.h>

@implementation AMWorkflowPersonality

// Automator asks for its document personalities at launch: the general (plain workflow) and
// application personalities exist; every other type identifier maps to the general one.
+ (id)generalWorkflowPersonality
{
    static id general;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        general = [[AMGeneralWorkflowPersonality alloc] init];
    });
    return general;
}

+ (id)applicationWorkflowPersonality
{
    static id application;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        application = [[AMApplicationWorkflowPersonality alloc] init];
    });
    return application;
}

+ (NSArray *)workflowPersonalities
{
    return @[ [self generalWorkflowPersonality], [self applicationWorkflowPersonality] ];
}

+ (id)workflowPersonalityForTypeIdentifier:(NSString *)typeIdentifier
{
    if ([typeIdentifier isEqualToString: AMWorkflowTypeIdentifierApplication])
        return [self applicationWorkflowPersonality];
    return [self generalWorkflowPersonality];
}

// Automator.app adds a displayLabel titlebar label only when this is YES; none is shown.
- (BOOL)showInTitlebar
{
    return NO;
}

- (BOOL)canSaveWorkflow:(id)workflow atURL:(NSURL *)url forInstallation:(BOOL)install error:(NSError **)error
{
    if (error != NULL)
        *error = AMWorkflowFormatUnsupportedError();
    return NO;
}

AM_STUB_FORWARDING

@end
