class RemedyService {
  static String getRemedy(String disease) {
    switch (disease) {
      case "Leaf Blight":
        return "Use copper-based fungicide. Avoid overhead watering.";
      case "Powdery Mildew":
        return "Apply sulfur spray and ensure good air circulation.";
      default:
        return "Consult agricultural expert for treatment.";
    }
  }
}