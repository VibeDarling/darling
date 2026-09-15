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

#import <Automator/AMWorkflowController.h>
#import <Automator/AMWorkflow.h>
#import <Automator/AMWorkflowView.h>
#import "AMStubSignature.h"

@implementation AMWorkflowController

@synthesize workflow = _workflow;
@synthesize delegate = _delegate;

- (void)dealloc
{
    [_workflow release];
    [self setWorkflowView: nil];
    [super dealloc];
}

- (AMWorkflowView *)workflowView
{
    return _workflowView;
}

- (void)setWorkflowView:(AMWorkflowView *)view
{
    if (view == _workflowView)
        return;
    if ([_workflowView workflowController] == self)
        [_workflowView setWorkflowController: nil];
    [_workflowView release];
    _workflowView = [view retain];
    [_workflowView setWorkflowController: self];
}

// There is no workflow engine, so a workflow never runs.
- (BOOL)canRun
{
    return NO;
}

- (BOOL)isRunning
{
    return NO;
}

- (BOOL)isPaused
{
    return NO;
}

AM_STUB_FORWARDING

@end
