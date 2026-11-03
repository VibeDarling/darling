#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

root = File.expand_path('..', __dir__)
cf_url_src = File.join(root, 'src/external/corefoundation/CFURLEnumerator.c')
abort("Source file not found at #{cf_url_src}") unless File.exist?(cf_url_src)

content = File.read(cf_url_src)
abort('FAIL: CFURLEnumerator must track pushedLastItem for skipDescendents') unless content.include?('pushedLastItem')
abort('FAIL: CFURLEnumerator must release temporary item when url is NULL') unless content.include?('CFRelease(item);')

has_darling = system('darling shell true >/dev/null 2>&1')

test_src1 = File.join(root, 'src/external/corefoundation/Tests/CFURLEnumeratorRecursion.m')
test_src2 = File.join(root, 'src/external/corefoundation/Tests/CFErrorUnderlyingError.m')

[[test_src1, '/tmp/test_cfurl_enum'], [test_src2, '/tmp/test_cferror']].each do |test_src, bin_name|
  src_path = has_darling ? "/Volumes/SystemRoot#{test_src}" : test_src
  compile_cmd = ['clang', '-framework', 'Foundation', '-framework', 'CoreFoundation', src_path, '-o', bin_name]
  compile_cmd = ['darling', 'shell'] + compile_cmd if has_darling

  begin
    out, err, status = Open3.capture3(*compile_cmd)
    abort("Compilation failed for #{test_src}:\n#{err}\n#{out}") unless status.success?

    run_cmd = has_darling ? ['darling', 'shell', bin_name] : [bin_name]
    out, err, status = Open3.capture3(*run_cmd)
    abort("Execution failed for #{bin_name} (code #{status.exitstatus}):\n#{err}\n#{out}") unless status.success?
    abort("Test #{bin_name} reported failures:\n#{out}") unless out.include?('failures=0')
  ensure
    cleanup_cmd = has_darling ? ['darling', 'shell', 'rm', '-f', bin_name] : ['rm', '-f', bin_name]
    Open3.capture3(*cleanup_cmd)
  end
end

puts 'PASS: CFURLEnumerator recursion, NULL item safety, and error handling verified'
