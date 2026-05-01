#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint yandex_login_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'yandex_login_sdk'
  s.version          = '0.1.0'
  s.summary          = 'Native Yandex LoginSDK wrapper for Flutter — SSO via installed Yandex apps with browser fallback'
  s.description      = <<-DESC
A thin Flutter wrapper around the official Yandex LoginSDK for iOS and Android.
On iOS, delegates to YandexLoginSDK 3.x: tries the installed Yandex apps first
and falls back to ASWebAuthenticationSession (iOS 13+) or SFSafariViewController.
                       DESC
  s.homepage         = 'https://github.com/newbalancem5/yandex_login_sdk'
  s.license          = { :type => 'BSD-3-Clause', :file => '../LICENSE' }
  s.author           = { 'newbalancem5' => '22999662+newbalancem5@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/newbalancem5/yandex_login_sdk.git', :tag => s.version.to_s }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'YandexLoginSDK', '~> 3.1'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
