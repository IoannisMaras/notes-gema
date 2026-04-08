// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js_util' as js_util;

Future<bool> checkWebGPUSupport() async {
  try {
    final supported = await js_util.promiseToFuture(
      js_util.callMethod(js_util.globalThis, 'isWebGPUSupported', []),
    );
    return supported == true;
  } catch (e) {
    return false;
  }
}
