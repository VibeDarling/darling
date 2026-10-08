# CGImage-backed UIImage value regression

This component implements immutable CGImage ownership, size, scale, orientation
and copies. It does not load files, arbitrary data, assets or Core Image objects,
and it does not draw images or provide application lifecycle APIs.

Clean-room rung 3 specifications:

- [UIImage](https://developer.apple.com/documentation/uikit/uiimage): immutable values.
- [CGImage initializer](https://developer.apple.com/documentation/uikit/uiimage/init(cgimage:)-14qlb).
- [Scale and orientation initializer](https://developer.apple.com/documentation/uikit/uiimage/init(cgimage:scale:orientation:)-2ouhh).
- [Size](https://developer.apple.com/documentation/uikit/uiimage/size): logical points account for orientation.
- [Scale](https://developer.apple.com/documentation/uikit/uiimage/scale).
- [Orientation](https://developer.apple.com/documentation/uikit/uiimage/orientation).
- [PNG representation](https://developer.apple.com/documentation/uikit/uiimage/pngdata()?language=objc): returns nil on generation failure or unsupported bitmap formats.

Licensed Chameleon UIImage.h/.m and UIImageRep.m at
84605ede274bd82b330d72dd6ac41e64eb925fd7 supply the public enumeration,
factories, CGImage retain/release and ImageIO destination wrapper portions;
complete BSD notices are retained. Private categories/representation selection,
pattern/image loading and the old orientation omission are not adopted.
Rung 2: tracked CoreGraphics CGImage.h and ImageIO CGImageDestination.h/.m;
Onyx2D O2Encoder_PNG.m establishes the encoding support. The PNG UTI public.png
is declared by tracked CoreServices LaunchServices/constants.c.

The existing PNG encoder writes source bytes without unpremultiplying alpha.
This bounded wrapper supports up-oriented, RGB, 8-bit/component, 32-bit/pixel,
straight-alpha-last, 32Big RGBA images. Other layouts and orientation processing
return nil. No new pixel conversion or rendering path is invented. Allocation,
destination creation, finalize, backend exceptions and empty output fail with nil.
Finite positive scale, known orientation and bare-init rejection are conservative
local rung 6 policies without an Apple observation; null CGImage returns nil.

Compile image-values.m with tests/build-layout-values.py --test-source, under the
shared heavy-build flock, using independent pinned headers and the immutable
runtime with ImageIO linked. Run the identical executable against a prior UIKit
artifact (missing UIImage/PNG export, expected exit 1), then the new artifact
(expected exit 0), supplying a third argument for an own scratch fixture.png.

The fixture creates authored straight RGBA pixels before checking missing APIs.
It tests CGImage caller-release and pool-drain ownership, default scale/orientation,
all eight orientation sizes at scale 2, immutable copies and explicit nil results
for unsupported inputs. Its PNG must decode to 4x2 and all 32 original RGBA bytes,
including fractional and zero alpha. Decode only this authored output, for example
with ImageMagick read-only `magick fixture.png -depth 8 rgba:-`; compare every byte
with the pixels array in image-values.m. A nonempty NSData alone is insufficient.
No user data or arbitrary imported images are used.
