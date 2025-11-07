import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // 🔑 IDs de AdMob - IDs reales de Google AdMob
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7212476048136650/8858589295'; // ✅ ID REAL - Apoyo ministerial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7212476048136650/8858589295'; // ✅ ID REAL - iOS
    } else {
      throw UnsupportedError('Plataforma no soportada');
    }
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ID - cambiar por tu ID real
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ID - cambiar por tu ID real
    } else {
      throw UnsupportedError('Plataforma no soportada');
    }
  }

  // Variables para anuncios
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  // 🚀 Inicializar AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    print('📱 AdMob inicializado correctamente');
  }

  // 💰 Cargar anuncio recompensado (el que genera dinero)
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('🎯 Anuncio recompensado cargado exitosamente');
          _rewardedAd = ad;
          _isRewardedAdReady = true;

          // Configurar callbacks del anuncio
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) =>
                print('📺 Anuncio mostrado en pantalla completa'),
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('❌ Anuncio cerrado');
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd(); // Cargar el siguiente anuncio
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('❌ Error mostrando anuncio: $error');
              ad.dispose();
              _isRewardedAdReady = false;
              loadRewardedAd(); // Intentar cargar otro anuncio
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Error cargando anuncio: $error');
          _isRewardedAdReady = false;
          // Reintentar después de 30 segundos
          Future.delayed(const Duration(seconds: 30), () {
            loadRewardedAd();
          });
        },
      ),
    );
  }

  // 🎬 Mostrar anuncio recompensado
  void showRewardedAd({
    required Function() onUserEarnedReward,
    required Function() onAdClosed,
    Function(String error)? onError,
  }) {
    if (_isRewardedAdReady && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print('💰 Usuario ganó recompensa: ${reward.amount} ${reward.type}');
          onUserEarnedReward();
        },
      );

      // Callback personalizado para cuando se cierra el anuncio
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print('📱 Anuncio cerrado por usuario');
          ad.dispose();
          _isRewardedAdReady = false;
          onAdClosed();
          loadRewardedAd(); // Cargar el siguiente anuncio
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('❌ Error mostrando anuncio: $error');
          ad.dispose();
          _isRewardedAdReady = false;
          onError?.call(error.message);
          loadRewardedAd();
        },
      );

      _rewardedAd = null;
      _isRewardedAdReady = false;
    } else {
      print('❌ Anuncio no está listo');
      onError?.call('Anuncio no disponible en este momento');
      // Intentar cargar un anuncio
      loadRewardedAd();
    }
  }

  // 📊 Verificar si hay anuncio disponible
  bool get isRewardedAdReady => _isRewardedAdReady;

  // 🔄 Limpiar recursos
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }
}
