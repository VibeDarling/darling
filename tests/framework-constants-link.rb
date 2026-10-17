# Host test: the CFString constants a framework defines are defined once.
# usage: ruby tests/framework-constants-link.rb [REPO_ROOT]
# For each framework, the single-line "const CFStringRef k... = CFSTR(...)"
# definitions are cut out of every source file in its CMake SOURCES list,
# compiled one object per file against a stand-in CFSTR, and linked into one
# shared object, as the framework build does. A symbol defined in two files
# fails the link ("multiple definition"). The constants added by the missing
# public constants change must also be declared in a public header.
require 'tmpdir'
require 'open3'
root = ARGV.fetch(0, File.expand_path('..', __dir__))
frameworks = %w[VideoToolbox CoreVideo MediaAccessibility]
ADDED = %w[kVTCompressionPropertyKey_BaseLayerFrameRateFraction kVTVideoEncoderSpecification_EnableLowLatencyRateControl
  kCVImageBufferTransferFunction_sRGB kCVBufferPropagatedAttachmentsKey kCVImageBufferContentLightLevelInfoKey
  kCVImageBufferMasteringDisplayColorVolumeKey kCVPixelBufferPoolAllocationThresholdKey kMACaptionAppearanceSettingsChangedNotification]
DEF = /^\s*(?:const\s+CFStringRef|CFStringRef\s+const)\s+(k\w+)\s*=\s*CFSTR\("[^"]*"\);/
Dir.mktmpdir('constants-link-') do |dir|
  File.write("#{dir}/cf.h", "typedef const struct __CFString *CFStringRef;\n#define CFSTR(x) ((CFStringRef) (x))\n")
  failed = false
  frameworks.each do |fw|
    base = "#{root}/src/frameworks/#{fw}"
    cmake = File.read("#{base}/CMakeLists.txt")
    list = cmake[/SOURCES(.*?)DEPENDENCIES/m, 1] or abort "#{fw}: no SOURCES"
    objs = []
    names = []
    list.scan(%r{\S+\.(?:c|m|mm)\b}).each_with_index do |src, i|
      defs = File.readlines("#{base}/#{src}").select { |l| l =~ DEF }
      next if defs.empty?
      names.concat(defs.map { |l| l[DEF, 1] })
      File.write("#{dir}/#{fw}#{i}.c", "#include \"cf.h\"\n" + defs.join)
      out, st = Open3.capture2e('clang', '-fPIC', '-c', "#{dir}/#{fw}#{i}.c", '-o', "#{dir}/#{fw}#{i}.o")
      abort out unless st.success?
      objs << "#{dir}/#{fw}#{i}.o"
    end
    out, st = Open3.capture2e('clang', '-shared', *objs, '-o', "#{dir}/#{fw}.so")
    unless st.success?
      puts "FAIL #{fw}: #{out.lines.grep(/multiple definition/).first(5).join}"
      failed = true
      next
    end
    headers = Dir.glob("#{base}/include/**/*.h").map { |h| File.read(h) }.join
    missing = (names & ADDED).reject { |n| headers =~ /extern\s+(?:const\s+CFStringRef|CFStringRef\s+const)\s+#{n}\s*;/ }
    puts "#{fw}: #{names.size} constants link once" + (missing.empty? ? '' : "; not declared in a header: #{missing.join(' ')}")
    failed = true unless missing.empty?
  end
  abort 'framework constants regression' if failed
  puts 'PASS: framework constants link once'
end
