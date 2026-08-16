import 'chaturaji_engine_interface.dart';
import 'chaturaji_engine_stub.dart'
    if (dart.library.ffi) 'chaturaji_engine_ffi.dart';

export 'chaturaji_engine_interface.dart';

ChaturajiEngine getChaturajiEngine() => createEngine();
