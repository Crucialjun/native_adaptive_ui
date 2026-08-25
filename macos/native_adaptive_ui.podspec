#
# CocoaPods fallback for apps that have not migrated to Swift Package Manager.
# See the iOS podspec for the shared-source rule; it applies here too.
#
Pod::Spec.new do |s|
  s.name             = 'native_adaptive_ui'
  s.version          = '0.1.0'
  s.summary          = 'Version-aware adaptive UI for Flutter.'
  s.description      = <<-DESC
Platform, OS-version and form-factor aware Flutter widgets, with macOS Tahoe
Liquid Glass awareness.
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

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.swift_version = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
