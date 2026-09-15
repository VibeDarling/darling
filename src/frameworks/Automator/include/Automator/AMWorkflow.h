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

#include <Foundation/Foundation.h>

@class AMWorkflowMetaData;

@interface AMWorkflow : NSObject
{
    AMWorkflowMetaData *_metaData;
    NSURL *_fileURL;
    BOOL _hasUnsavedChanges;
}

@property BOOL hasUnsavedChanges;
@property (copy) NSURL *fileURL;

- (instancetype)initWithContentsOfURL:(NSURL *)fileURL error:(NSError **)outError;
- (instancetype)initWithFileWrapper:(NSFileWrapper *)fileWrapper error:(NSError **)outError;
- (BOOL)writeToURL:(NSURL *)fileURL error:(NSError **)outError;
- (NSFileWrapper *)fileWrapperForWritingReturningSavedPropertyList:(id *)propertyList documentType:(NSString *)documentType originalContentsFileWrapper:(NSFileWrapper *)original error:(NSError **)outError;

- (AMWorkflowMetaData *)_workflowMetaData;
- (void)_setWorkflowMetaData:(AMWorkflowMetaData *)metaData;
- (id)_workflowPersonality;
- (void)_setWorkflowPersonality:(id)personality;

@end
