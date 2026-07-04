@echo off
REM Always run the app this way for actual auction use (not development).
REM Fixed port + release mode together fix two things at once:
REM   - "my data disappeared after restart" -> shared_preferences on web is
REM     backed by localStorage, which is scoped per port. A bare
REM     "flutter run -d chrome" picks a random port every launch, so each
REM     restart looked like a brand new, empty app. Pinning the port keeps
REM     every launch on the same origin, so saved data is always found again.
REM   - slow/laggy UI -> plain "flutter run" builds in debug mode (no
REM     tree-shaking/minification, debug assertions on). --release removes
REM     all of that.
flutter run -d chrome --release --web-port=8765
