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

#import <Automator/AMWorkflow.h>
#import <Automator/AMWorkflowMetaData.h>
#import "AMStubSignature.h"

@implementation AMWorkflow

@synthesize hasUnsavedChanges = _hasUnsavedChanges;

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _metaData = [[AMWorkflowMetaData alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_metaData release];
    [super dealloc];
}

- (AMWorkflowMetaData *)_workflowMetaData
{
    return _metaData;
}

- (void)_setWorkflowMetaData:(AMWorkflowMetaData *)metaData
{
    [metaData retain];
    [_metaData release];
    _metaData = metaData;
}

// Automator.app reads the personality back through the metadata after setting it on the workflow,
// and restores both at once from a metadata backup, so the metadata owns it.
- (id)_workflowPersonality
{
    return [_metaData personality];
}

- (void)_setWorkflowPersonality:(id)personality
{
    [_metaData setPersonality: personality];
}

AM_STUB_FORWARDING

@end
