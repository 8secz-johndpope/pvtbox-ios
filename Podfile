# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

target 'Pvtbox' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  pod 'HS-Google-Material-Design-Icons'
  pod 'BugfenderSDK'
  pod 'MaterialComponents'
  pod 'DLRadioButton'
  pod 'IQKeyboardManagerSwift'
  pod 'RealmSwift'
  pod 'JASON'
  pod 'Alamofire'
  pod 'Starscream', '3.1.1'
  pod 'NicoProgress'
  pod 'ColorAssetCatalog'
  pod 'Toast-Swift'
  pod 'TTGSnackbar'
  pod 'NVActivityIndicatorView'
  pod 'SwiftProtobuf'
  pod 'BTree'
  pod 'Nuke', '< 8'
  pod 'ImageScrollView'
  pod 'AppLocker'
  pod 'SwiftKeychainWrapper'
  pod 'GoogleWebRTC', '1.1.27828'
  pod 'MarqueeLabel'


  # Pods for Pvtbox

  post_install do |installer|
      puts 'Patching Starscream'
      system("patch --forward Pods/Starscream/Sources/Starscream/WebSocket.swift < Starscream.patch")
      puts 'Patching TTGSnackbar'
      system("patch --forward Pods/TTGSnackbar/TTGSnackbar/TTGSnackbar.swift < TTGSnackbar.patch")
      puts 'Patching NicoProgress'
      system("patch --forward Pods/NicoProgress/NicoProgress/Classes/NicoProgressBar.swift < NicoProgress.patch")
      puts 'Patching AppLocker'
      system("patch --forward -p0 < AppLocker.patch")
      puts 'Creating pb.swift'
      system("cd Pvtbox/Services/Network && protoc --swift_out=. proto.proto && cd -")
  end
  
end
