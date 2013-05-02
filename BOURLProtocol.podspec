Pod::Spec.new do |s|
  s.name     = 'BOURLProtocol'
  s.version  = '1.0'
  s.license  = 'MIT'
  s.summary  = 'Mocking URL call made easy'
  s.homepage = 'https://github.com/bcharp/BOURLProtocol'
  s.authors  = { 'Boris Charpentier' => 'boris.charpentier@gmail.com' }
  s.source   = { :git => 'https://github.com/bcharp/BOURLProtocol.git', :tag => s.version.to_s }
  s.source_files = 'BOURLProtocol'
  s.requires_arc = true
  s.ios.deployment_target = '5.0'

end
