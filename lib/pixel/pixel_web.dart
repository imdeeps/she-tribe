import 'dart:convert';
import 'dart:js_interop';

@JS('eval')
external JSAny? _eval(String code);

const _pixelId = '1140510588698412';
bool _started = false;

// Meta's standard base code, started only once someone is signed in.
const _bootstrap = '''
!function(f,b,e,v,n,t,s)
{if(f.fbq)return;n=f.fbq=function(){n.callMethod?
n.callMethod.apply(n,arguments):n.queue.push(arguments)};
if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
n.queue=[];t=b.createElement(e);t.async=!0;
t.src=v;s=b.getElementsByTagName(e)[0];
s.parentNode.insertBefore(t,s)}(window, document,'script',
'https://connect.facebook.net/en_US/fbevents.js');
fbq('init', '$_pixelId');
fbq('track', 'PageView');
''';

class Pixel {
  /// Starts the pixel (once). Call after sign-in.
  static void start() {
    if (_started) return;
    _started = true;
    try {
      _eval(_bootstrap);
    } catch (_) {}
  }

  /// Sends a standard event. [onceKey] makes it fire only once per browser.
  static void track(String event,
      {Map<String, Object?> params = const {}, String? onceKey}) {
    if (!_started) return;
    final key = onceKey == null ? 'null' : jsonEncode('st_px_$onceKey');
    final code = '(function(){try{var k=$key;'
        'if(k){if(localStorage.getItem(k))return;localStorage.setItem(k,"1");}'
        'fbq("track",${jsonEncode(event)},${jsonEncode(params)});'
        '}catch(e){}})();';
    try {
      _eval(code);
    } catch (_) {}
  }
}
