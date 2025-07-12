import SwiftUI

struct CloudIcon: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 100, color: Color = .blue) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Main cloud shape
            CloudShape()
                .fill(color)
                .frame(width: size, height: size * 0.7)
            
            // Air quality indicator dots
            HStack(spacing: size * 0.1) {
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.15, height: size * 0.15)
                
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.12, height: size * 0.12)
                
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.15, height: size * 0.15)
            }
            .offset(y: -size * 0.05)
        }
    }
}

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Create a cloud-like shape using multiple circles
        let centerX = width / 2
        let centerY = height / 2
        
        // Main cloud body
        path.addEllipse(in: CGRect(x: centerX - width * 0.4, y: centerY - height * 0.3, width: width * 0.8, height: height * 0.6))
        
        // Top cloud puff
        path.addEllipse(in: CGRect(x: centerX - width * 0.25, y: centerY - height * 0.4, width: width * 0.5, height: height * 0.4))
        
        // Left cloud puff
        path.addEllipse(in: CGRect(x: centerX - width * 0.45, y: centerY - height * 0.2, width: width * 0.4, height: height * 0.4))
        
        // Right cloud puff
        path.addEllipse(in: CGRect(x: centerX + width * 0.05, y: centerY - height * 0.2, width: width * 0.4, height: height * 0.4))
        
        return path
    }
}

struct AirQualityIcon: View {
    let size: CGFloat
    let quality: String
    
    var qualityColor: Color {
        switch quality.lowercased() {
        case "good":
            return .green
        case "moderate":
            return .yellow
        case "unhealthy for sensitive groups":
            return .orange
        case "unhealthy":
            return .red
        case "very unhealthy":
            return .purple
        case "hazardous":
            return Color(red: 0.5, green: 0, blue: 0)
        default:
            return .blue
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(qualityColor)
                .frame(width: size, height: size)
            
            // Cloud icon
            CloudIcon(size: size * 0.6, color: .white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudIcon(size: 100, color: .blue)
        AirQualityIcon(size: 80, quality: "Good")
        AirQualityIcon(size: 80, quality: "Moderate")
        AirQualityIcon(size: 80, quality: "Unhealthy")
    }
    .padding()
} 