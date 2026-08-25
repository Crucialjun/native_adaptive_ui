import 'package:flutter_test/flutter_test.dart';
import 'package:native_adaptive_ui/native_adaptive_ui.dart';

PlatformInfo _info({
  required String os,
  required int major,
  int? api,
  FormFactor formFactor = FormFactor.phone,
}) {
  return PlatformInfo(
    osName: os,
    majorVersion: major,
    minorVersion: 0,
    androidSdkInt: api,
    deviceFormFactor: formFactor,
    nativeComponents: const <String>{},
    isSimulator: false,
  );
}

void main() {
  group('era resolution', () {
    test('iOS 26 on a phone is Liquid Glass', () {
      expect(
        _info(os: 'ios', major: 26).era,
        DesignEra.iosLiquidGlass,
      );
    });

    test('iOS 26 on a tablet is the iPad Liquid Glass era', () {
      expect(
        _info(os: 'ios', major: 26, formFactor: FormFactor.tablet).era,
        DesignEra.ipadLiquidGlass,
      );
    });

    test('iOS 18 stays classic Cupertino', () {
      expect(_info(os: 'ios', major: 18).era, DesignEra.iosClassic);
    });

    test('Android API 36 is Material 3 Expressive', () {
      expect(
        _info(os: 'android', major: 16, api: 36).era,
        DesignEra.materialExpressive,
      );
    });

    test('Android API 31 is Material 3 with dynamic colour', () {
      final era = _info(os: 'android', major: 12, api: 31).era;
      expect(era, DesignEra.material3);
      expect(era.hasDynamicColor, isTrue);
    });

    test('Android API 30 loses dynamic colour', () {
      final era = _info(os: 'android', major: 11, api: 30).era;
      expect(era, DesignEra.material3Legacy);
      expect(era.hasDynamicColor, isFalse);
    });

    test('macOS 26 is Tahoe, macOS 15 is not', () {
      expect(_info(os: 'macos', major: 26).era, DesignEra.macosTahoe);
      expect(_info(os: 'macos', major: 15).era, DesignEra.macosClassic);
    });

    test('an unknown OS falls back rather than guessing', () {
      expect(_info(os: 'fuchsia', major: 1).era, DesignEra.fallback);
    });
  });

  group('era traits', () {
    test('glass eras are the three 26-generation Apple releases', () {
      final glass = DesignEra.values.where((era) => era.hasLiquidGlass).toSet();
      expect(glass, {
        DesignEra.iosLiquidGlass,
        DesignEra.ipadLiquidGlass,
        DesignEra.macosTahoe,
      });
    });

    test('every era degrades to a same-family era, never across families', () {
      for (final era in DesignEra.values) {
        final fallback = era.fallbackEra;
        expect(
          fallback.isApple,
          era.isApple,
          reason: '$era fell back to $fallback, crossing design families',
        );
      }
    });

    test('iPad and macOS prefer sidebars; phones do not', () {
      expect(DesignEra.ipadLiquidGlass.prefersSidebarNavigation, isTrue);
      expect(DesignEra.macosTahoe.prefersSidebarNavigation, isTrue);
      expect(DesignEra.iosLiquidGlass.prefersSidebarNavigation, isFalse);
      expect(DesignEra.materialExpressive.prefersSidebarNavigation, isFalse);
    });
  });

  group('version predicates', () {
    test('isAtLeast only answers for the OS actually running', () {
      final ios26 = _info(os: 'ios', major: 26);
      expect(ios26.isAtLeast(ios: 26), isTrue);
      expect(ios26.isAtLeast(ios: 27), isFalse);
      expect(ios26.isAtLeast(android: 16), isFalse);
    });

    test('Android accepts either marketing version or API level', () {
      final android = _info(os: 'android', major: 16, api: 36);
      expect(android.isAtLeast(android: 16), isTrue);
      expect(android.isAtLeast(androidApi: 36), isTrue);
      expect(android.isAtLeast(androidApi: 37), isFalse);
    });
  });

  group('tokens', () {
    test('every era has tokens', () {
      for (final era in DesignEra.values) {
        expect(AdaptiveTokens.of(era).era, era);
      }
    });

    test('only glass eras carry a blur radius', () {
      for (final era in DesignEra.values) {
        expect(AdaptiveTokens.of(era).hasGlass, era.hasLiquidGlass,
            reason: 'blur/era mismatch for $era');
      }
    });

    test('Apple eras use continuous corners, Material does not', () {
      for (final era in DesignEra.values) {
        if (era == DesignEra.fallback) continue;
        expect(AdaptiveTokens.of(era).continuousCorners, era.isApple,
            reason: 'corner style mismatch for $era');
      }
    });

    test('concentric radius never goes negative', () {
      final tokens = AdaptiveTokens.of(DesignEra.iosLiquidGlass);
      expect(tokens.concentricRadius(20, 8), 12);
      expect(tokens.concentricRadius(4, 40), 0);
    });

    test('tap targets meet each platform minimum', () {
      expect(AdaptiveTokens.of(DesignEra.iosLiquidGlass).minTapTarget, 44);
      expect(AdaptiveTokens.of(DesignEra.materialExpressive).minTapTarget, 48);
    });
  });
}
