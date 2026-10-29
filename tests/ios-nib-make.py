#!/usr/bin/env python3
# Writes NibTest.app's interface files for ios-nib.m: compiled nibs in
# ibtool's NIBArchive format (as Xcode builds them for iOS 6 and later),
# a compiled storyboard, an image and the Info.plist.
#
#   ios-nib-make.py OUTPUT.app
import os, plistlib, struct, sys, zlib


class Obj:
    def __init__(self, cls, *values):
        self.cls = cls
        self.values = list(values)


class Geometry:
    """Points, sizes, rects: data, a type byte (7, double), the numbers."""
    def __init__(self, *numbers):
        self.numbers = numbers


class Double:
    def __init__(self, value):
        self.value = value


def string(text):
    return Obj('NSString', ('NS.bytes', text.encode()))


def array(*items, cls='NSArray'):
    return Obj(cls, ('NSInlinedValue', True), *[('UINibEncoderEmptyKey', item) for item in items])


def dictionary(pairs, cls='NSDictionary'):
    values = [('NSInlinedValue', True)]
    for key, value in pairs:
        values += [('UINibEncoderEmptyKey', key), ('UINibEncoderEmptyKey', value)]
    return Obj(cls, *values)


def number(value):
    return Obj('NSNumber', ('NS.intval', value))


def proxy(identifier):
    return Obj('UIProxyObject', ('UIProxiedObjectIdentifier', string(identifier)))


def swapper(class_name, original, *values):
    return Obj('UIClassSwapper', ('UIClassName', string(class_name)), ('UIOriginalClassName', string(original)), *values)


def outlet(source, label, destination):
    return Obj('UIRuntimeOutletConnection', ('UILabel', string(label)), ('UISource', source), ('UIDestination', destination))


def action(source, label, destination, mask=None):
    values = [('UILabel', string(label)), ('UISource', source), ('UIDestination', destination)]
    if mask is not None:
        values.append(('UIEventMask', mask))
    return Obj('UIRuntimeEventConnection', *values)


def frame(x, y, width, height):
    return [('UIBounds', Geometry(0, 0, width, height)), ('UICenter', Geometry(x + width / 2, y + height / 2))]


def color(red, green, blue, alpha=1.0):
    return Obj('UIColor', ('UIColorComponentCount', 4), ('UIRed', red), ('UIGreen', green), ('UIBlue', blue), ('UIAlpha', alpha))


def system_color(name, white):
    return Obj('UIColor', ('UISystemColorName', string(name)), ('UIColorComponentCount', 2), ('UIWhite', white), ('UIAlpha', 1.0))


def system_font(size, bold=False):
    return Obj('UIFont', ('UIFontName', string('.SFUI-Regular')), ('UIFontPointSize', Double(size)),
               ('UIFontTraits', 2 if bold else 0), ('UISystemFont', True))


def varint(value):
    out = bytearray()
    while True:
        byte = value & 0x7f
        value >>= 7
        if value == 0:
            out.append(byte | 0x80)
            return bytes(out)
        out.append(byte)


def nib(top_level, connections, objects=None):
    """The archive's bytes: the root object holds the top-level objects, all
    objects and the connections, as ibtool writes them."""
    root = Obj('NSObject',
               ('UINibTopLevelObjectsKey', array(*top_level)),
               ('UINibObjectsKey', array(*(objects if objects is not None else top_level))),
               ('UINibConnectionsKey', array(*connections)),
               ('UINibVisibleWindowsKey', array()),
               ('UINibAccessibilityConfigurationsKey', array()),
               ('UINibTraitStorageListsKey', array()),
               ('UINibKeyValuePairsKey', array()))
    order, index = [], {}

    def visit(obj):
        if id(obj) in index:
            return
        index[id(obj)] = len(order)
        order.append(obj)
        for _, value in obj.values:
            if isinstance(value, Obj):
                visit(value)
    visit(root)

    keys, key_index, classes, class_index = [], {}, [], {}
    values = bytearray()
    value_count = 0
    object_table = bytearray()
    for obj in order:
        if obj.cls not in class_index:
            class_index[obj.cls] = len(classes)
            classes.append(obj.cls)
        first = value_count
        for key, value in obj.values:
            if key not in key_index:
                key_index[key] = len(keys)
                keys.append(key)
            values += varint(key_index[key])
            if isinstance(value, bool):
                values.append(5 if value else 4)
            elif isinstance(value, int):
                if -128 <= value < 128:
                    values += bytes([0]) + struct.pack('<b', value)
                elif -32768 <= value < 32768:
                    values += bytes([1]) + struct.pack('<h', value)
                else:
                    values += bytes([2]) + struct.pack('<i', value)
            elif isinstance(value, float):
                values += bytes([6]) + struct.pack('<f', value)
            elif isinstance(value, Double):
                values += bytes([7]) + struct.pack('<d', value.value)
            elif isinstance(value, Geometry):
                data = bytes([7]) + b''.join(struct.pack('<d', n) for n in value.numbers)
                values += bytes([8]) + varint(len(data)) + data
            elif isinstance(value, bytes):
                values += bytes([8]) + varint(len(value)) + value
            elif value is None:
                values.append(9)
            elif isinstance(value, Obj):
                values += bytes([10]) + struct.pack('<I', index[id(value)])
            else:
                raise TypeError(value)
            value_count += 1
        object_table += varint(class_index[obj.cls]) + varint(first) + varint(len(obj.values))

    key_table = b''.join(varint(len(k.encode())) + k.encode() for k in keys)
    class_table = b''.join(varint(len(c) + 1) + varint(0) + c.encode() + b'\0' for c in classes)
    header_size = 10 + 40
    offsets = [header_size]
    offsets.append(offsets[0] + len(object_table))
    offsets.append(offsets[1] + len(key_table))
    offsets.append(offsets[2] + len(values))
    header = b'NIBArchive' + struct.pack('<10I', 1, 10, len(order), offsets[0], len(keys), offsets[1],
                                         value_count, offsets[2], len(classes), offsets[3])
    return header + bytes(object_table) + key_table + bytes(values) + class_table


def png(width, height, rgba):
    rows = b''.join(b'\0' + bytes(rgba) * width for _ in range(height))

    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))


def panel():
    """A view controller's view: File's Owner (NibController) gets outlets to
    each control and the button's action."""
    owner, first = proxy('IBFilesOwner'), proxy('IBFirstResponder')
    label = Obj('UILabel', *frame(5, 40, 200, 30), ('UIText', string('Hello nib')), ('UIFont', system_font(20, bold=True)),
                ('UITextColor', color(1.0, 0.0, 0.0)), ('UITextAlignment', 1), ('UINumberOfLines', 2), ('UITag', 1),
                ('UIViewDoesNotTranslateAutoresizingMaskIntoConstraints', True))
    title = Obj('UIButtonContent', ('UITitle', string('Press')), ('UITitleColor', color(0.0, 0.0, 1.0)))
    button = Obj('UIButton', *frame(20, 100, 120, 44), ('UIButtonType', 1),
                 ('UIButtonStatefulContent', dictionary([(number(0), title)], cls='NSMutableDictionary')), ('UITag', 2))
    field = Obj('UITextField', *frame(20, 160, 200, 30), ('UIPlaceholder', string('Type here')), ('UIBorderStyle', 3),
                ('UIFont', system_font(14)))
    toggle = Obj('UISwitch', *frame(20, 200, 51, 31), ('UISwitchOn', True))
    image = Obj('UIImageView', *frame(100, 200, 16, 16), ('UIImage', Obj('UIImageNibPlaceholder', ('UIResourceName', string('dot')))))
    custom = swapper('NibCustomView', 'UIView', *frame(0, 250, 320, 50), ('UIBackgroundColor', color(0.0, 1.0, 0.0)))
    flexible = Obj('UIBarButtonItem', ('UIEnabled', True), ('UIIsSystemItem', True), ('UISystemItem', 5))
    item = Obj('UIBarButtonItem', ('UIEnabled', True), ('UITitle', string('Tool')), ('UIStyle', 1))
    toolbar = Obj('UIToolbar', *frame(0, 436, 320, 44), ('UIItems', array(flexible, item)))
    constraint = Obj('NSLayoutConstraint', ('NSFirstItem', label), ('NSFirstAttribute', 1), ('NSSecondAttribute', 1),
                     ('NSConstant', Double(20.0)), ('NSShouldBeArchived', True))
    view = Obj('UIView', *frame(0, 0, 320, 480),
               ('UISubviews', array(label, button, field, toggle, image, custom, toolbar, cls='NSMutableArray')),
               ('UIBackgroundColor', system_color('systemBackgroundColor', 1.0)), ('UIAutoresizingMask', 18),
               ('UIAutoresizeSubviews', True), ('UIViewAutolayoutConstraints', array(constraint, cls='NSMutableArray')))
    constraint.values.insert(1, ('NSSecondItem', view))
    connections = [outlet(owner, 'view', view), outlet(owner, 'label', label), outlet(owner, 'button', button),
                   outlet(owner, 'field', field), outlet(owner, 'toggle', toggle), outlet(owner, 'image', image),
                   outlet(owner, 'custom', custom), outlet(custom, 'owner', owner), outlet(owner, 'toolItem', item),
                   action(button, 'pressed:', owner, 64), action(item, 'toolPressed:', owner),
                   action(toggle, 'toggled:', first, 4096)]
    return nib([owner, first, view], connections,
               [owner, first, view, label, button, field, toggle, image, custom, toolbar, flexible, item])


def auto():
    """Found by name: NibAutoController's view comes from NibAuto.nib."""
    owner = proxy('IBFilesOwner')
    view = Obj('UIView', *frame(0, 0, 320, 480), ('UITag', 77))
    return nib([owner, proxy('IBFirstResponder'), view], [outlet(owner, 'view', view)])


def cell():
    owner = proxy('IBFilesOwner')
    label = Obj('UILabel', *frame(15, 0, 200, 44), ('UIText', string('Cell label')), ('UITag', 5))
    content = Obj('UITableViewCellContentView', *frame(0, 0, 320, 44), ('UISubviews', array(label, cls='NSMutableArray')))
    view = swapper('NibCell', 'UITableViewCell', *frame(0, 0, 320, 44), ('UISubviews', array(content, cls='NSMutableArray')),
                   ('UIContentView', content), ('UIReuseIdentifier', string('Cell')))
    return nib([owner, proxy('IBFirstResponder'), view], [outlet(view, 'nameLabel', label)])


def storyboard(path):
    """Main.storyboardc: First (the entry point) shows Second through a
    segue its button performs."""
    os.makedirs(path, exist_ok=True)
    storyboard_placeholder = proxy('UIStoryboardPlaceholder')

    # Scene First: the view controller, its segue template, its view's nib.
    scene_owner = proxy('IBFilesOwner')
    segue = Obj('UIStoryboardPresentationSegueTemplate', ('UIIdentifier', string('next')),
                ('UIDestinationViewControllerIdentifier', string('Second')))
    first = swapper('NibFirstController', 'UIViewController', ('UINibName', string('First-view')), ('UITitle', string('First')),
                    ('UIStoryboardSegueTemplates', array(segue)),
                    ('UIExternalObjectsTableForViewLoading', dictionary([(string('segue-next'), segue)])))
    segue.values.append(('UIViewController', first))
    with open(os.path.join(path, 'First.nib'), 'wb') as f:
        f.write(nib([scene_owner, proxy('IBFirstResponder'), storyboard_placeholder, first],
                    [outlet(first, 'storyboard', storyboard_placeholder), outlet(scene_owner, 'sceneViewController', first)]))

    owner, segue_proxy = proxy('IBFilesOwner'), proxy('segue-next')
    go = Obj('UIButton', *frame(20, 100, 120, 44), ('UIButtonType', 1),
             ('UIButtonStatefulContent', dictionary([(number(0), Obj('UIButtonContent', ('UITitle', string('Next'))))])))
    view = Obj('UIView', *frame(0, 0, 320, 480), ('UISubviews', array(go, cls='NSMutableArray')), ('UITag', 10))
    with open(os.path.join(path, 'First-view.nib'), 'wb') as f:
        f.write(nib([owner, proxy('IBFirstResponder'), segue_proxy, view],
                    [outlet(owner, 'view', view), outlet(owner, 'nextButton', go), action(go, 'perform:', segue_proxy, 64)]))

    # Scene Second: a view archived with the controller.
    scene_owner = proxy('IBFilesOwner')
    view = Obj('UIView', *frame(0, 0, 320, 480), ('UITag', 20))
    second = swapper('NibSecondController', 'UIViewController', ('UITitle', string('Second')), ('UIView', view),
                     ('UIStoryboardIdentifier', string('Second')))
    with open(os.path.join(path, 'Second.nib'), 'wb') as f:
        f.write(nib([scene_owner, proxy('IBFirstResponder'), storyboard_placeholder, second],
                    [outlet(second, 'storyboard', storyboard_placeholder), outlet(scene_owner, 'sceneViewController', second)]))

    with open(os.path.join(path, 'Info.plist'), 'wb') as f:
        plistlib.dump({'UIStoryboardDesignatedEntryPointIdentifier': 'First',
                       'UIViewControllerIdentifiersToNibNames': {'First': 'First', 'Second': 'Second'},
                       'UIStoryboardVersion': 1}, f)


def main():
    app = sys.argv[1]
    os.makedirs(app, exist_ok=True)
    for name, data in (('Panel.nib', panel()), ('NibAuto.nib', auto()), ('Cell.nib', cell())):
        with open(os.path.join(app, name), 'wb') as f:
            f.write(data)
    storyboard(os.path.join(app, 'Main.storyboardc'))
    with open(os.path.join(app, 'dot.png'), 'wb') as f:
        f.write(png(16, 16, (255, 0, 0, 255)))
    with open(os.path.join(app, 'Info.plist'), 'wb') as f:
        plistlib.dump({'CFBundleExecutable': 'NibTest', 'CFBundleIdentifier': 'org.darlinghq.nibtest',
                       'CFBundleName': 'NibTest', 'CFBundlePackageType': 'APPL', 'MinimumOSVersion': '14.0',
                       'UIMainStoryboardFile': 'Main'}, f)


if __name__ == '__main__':
    main()
