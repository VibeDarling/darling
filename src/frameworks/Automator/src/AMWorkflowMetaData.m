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

#import <Automator/AMWorkflowMetaData.h>
#import "AMStubSignature.h"

@implementation AMWorkflowMetaData

@synthesize personality = _personality;
@synthesize documentSaveName = _documentSaveName;

- (void)dealloc
{
    [_personality release];
    [_documentSaveName release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    AMWorkflowMetaData *copy = [[[self class] allocWithZone: zone] init];
    [copy setPersonality: _personality];
    [copy setDocumentSaveName: _documentSaveName];
    return copy;
}

AM_STUB_FORWARDING

@end
