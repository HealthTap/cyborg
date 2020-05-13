Pod::Spec.new do |s|
  s.name         = 'Cyborg'
  s.version      = '0.6'
  s.license      = { :type => 'Apache License, Version 2.0', :file => 'LICENSE.txt' }
  s.summary      = 'Cyborg is a partial port of Android's VectorDrawable to iOS.'
  s.homepage     = 'https://github.com/HealthTap/cyborg'
  s.author       = { 'Bofei Zhu' => 'bofei.zhu@healthtap.com' }
  s.source       = { :git => 'https://github.com/HealthTap/cyborg.git', :tag => s.version }
  s.source_files = 'Cyborg/*.swift'
  s.library      = 'xml2'
  s.xcconfig     = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}

  s.ios.deployment_target = '11.0'
end
