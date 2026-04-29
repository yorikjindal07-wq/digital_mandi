class RemedyService {
  static String getRemedy(String disease) {
    switch (disease) {
      case 'healthy':
        return 'No disease detected. Continue regular monitoring and good field hygiene.';
      case 'apple_scab':
      case 'black_rot':
      case 'cedar_apple_rust':
      case 'cercospora_leaf_spot':
      case 'common_rust':
      case 'early_blight':
      case 'grape_esca':
      case 'grape_leaf_blight':
      case 'late_blight':
      case 'leaf_mold':
      case 'leaf_scorch':
      case 'powdery_mildew':
      case 'septoria_leaf_spot':
      case 'target_spot':
        return 'Remove infected leaves, avoid overhead watering, and apply a crop-appropriate fungicide promptly.';
      case 'bacterial_spot':
        return 'Use copper-based protection, avoid handling wet plants, and keep foliage as dry as possible.';
      case 'citrus_greening':
      case 'mosaic_virus':
      case 'yellow_leaf_curl_virus':
        return 'There is no direct cure. Remove severely infected plants and control insect vectors to limit spread.';
      case 'spider_mites':
        return 'Spray the underside of leaves with a recommended miticide or neem-based treatment and reduce plant stress.';
      default:
        return 'Consult a local agricultural expert for crop-specific treatment guidance.';
    }
  }
}
