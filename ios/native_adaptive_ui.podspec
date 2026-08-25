#
# CocoaPods fallback for apps that have not migrated to Swift Package Manager.
#
# The source of truth is `native_adaptive_ui/Sources/native_adaptive_ui`, shared
# with `native_adaptive_ui/Package.swift`. Both toolchains compile the same
# files — never copy the Swift sources to satisfy one of them.
#
# Run `pod lib lint native_adaptive_ui.podspec` after editing.
#
Pod::Spec.new do |s|
  s.name             = 'native_adaptive_ui'
  s.version          = '0.1.0'
  s.summary          = 'Version-aware adaptive UI for Flutter.'
  s.description      = <<-DESC
Platform, OS-version and form-factor aware Flutter widgets, with optional
native UIKit components on iOS 26 and later.
                       DESC
  s.homepage         = 'https://github.com/gauravrajkagwaniya/native_adaptive_ui'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Gaurav Raj Kagwaniya' => 'gauravrajkagwaniya@gmail.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'native_adaptive_ui/Sources/native_adaptive_ui/**/*.swift'
  s.resource_bundles = {
    'native_adaptive_ui_privacy' => [
      'native_adaptive_ui/Sources/native_adaptive_ui/Resources/PrivacyInfo.xcprivacy'
    ]
  }

  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
