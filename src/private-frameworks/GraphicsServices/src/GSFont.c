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

#include <GraphicsServices/GraphicsServices.h>
#include <dlfcn.h>

/* Since iOS 4 a GSFont has been a Core Text font. Core Text is looked up
   when first asked for rather than linked: it sits above this framework. */
GSFontRef GSFontCreateWithName(const char *name, GSFontSymbolicTraits traits, float size)
{
	static CFTypeRef (*create)(CFStringRef, CGFloat, const void *);
	if (create == NULL) {
		void *coreText = dlopen("/System/Library/Frameworks/CoreText.framework/CoreText", RTLD_LAZY);
		create = coreText != NULL ? dlsym(coreText, "CTFontCreateWithName") : NULL;
		if (create == NULL)
			return NULL;
	}
	CFStringRef string = CFStringCreateWithCString(NULL, name != NULL ? name : "Helvetica", kCFStringEncodingUTF8);
	GSFontRef font = (GSFontRef)create(string, size, NULL);
	CFRelease(string);
	return font;
}

bool GSFontGetUseLegacyFontMetrics(void)
{
	return false;
}
