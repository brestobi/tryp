import 'device_support_stub.dart'
    if (dart.library.html) 'device_support_web.dart' as implementation;

bool get isMobileWebDevice => implementation.isMobileWebDevice;
