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

static CGSize gs_screen_size = { 1024, 768 };
static CGFloat gs_screen_scale = 1;
static int gs_screen_orientation = 1; /* UIInterfaceOrientationPortrait */

void GSSetMainScreenInfo(CGSize size, CGFloat scale, int orientation)
{
	gs_screen_size = size;
	gs_screen_scale = scale > 0 ? scale : 1;
	gs_screen_orientation = orientation;
}

CGSize GSMainScreenSize(void)
{
	return gs_screen_size;
}

CGSize GSMainScreenPixelSize(void)
{
	return CGSizeMake(gs_screen_size.width * gs_screen_scale, gs_screen_size.height * gs_screen_scale);
}

CGFloat GSMainScreenScaleFactor(void)
{
	return gs_screen_scale;
}

int GSMainScreenOrientation(void)
{
	return gs_screen_orientation;
}

const char *GSSystemRootDirectory(void)
{
	return "/";
}
