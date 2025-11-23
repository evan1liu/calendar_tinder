//
//  SwipeIndicators.swift
//  calendar_tinder
//
//  Visual feedback components for swipe gestures
//

import SwiftUI

// MARK: - Swipe Direction Indicator
struct SwipeIndicatorOverlay: View {
    let offset: CGFloat
    let screenWidth: CGFloat
    
    private var swipeProgress: CGFloat {
        abs(offset) / (screenWidth * 0.4)
    }
    
    private var isSwipingRight: Bool {
        offset > 0
    }
    
    var body: some View {
        ZStack {
            // Right swipe (Save) - Green
            if offset > 20 {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("SAVE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 40)
                    .opacity(min(swipeProgress, 1.0))
                    .scaleEffect(min(swipeProgress * 1.2, 1.2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.0),
                            Color.green.opacity(min(swipeProgress * 0.5, 0.5))
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            
            // Left swipe (Delete) - Red
            if offset < -20 {
                HStack {
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        Text("DELETE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 40)
                    .opacity(min(swipeProgress, 1.0))
                    .scaleEffect(min(swipeProgress * 1.2, 1.2))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(min(swipeProgress * 0.5, 0.5)),
                            Color.red.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
    }
}

// MARK: - Particle Effect
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
}

struct ParticleSystem: View {
    @State private var particles: [Particle] = []
    let isActive: Bool
    let color: Color
    let particleCount: Int = 30
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(particle.position)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    generateParticles(in: geometry.size)
                    animateParticles()
                }
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 100...300)
            
            return Particle(
                position: CGPoint(x: size.width / 2, y: size.height / 2),
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed
                ),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
        }
    }
    
    private func animateParticles() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard !particles.isEmpty else {
                timer.invalidate()
                return
            }
            
            for i in particles.indices {
                particles[i].position.x += particles[i].velocity.dx * 0.016
                particles[i].position.y += particles[i].velocity.dy * 0.016
                particles[i].velocity.dy += 500 * 0.016 // Gravity
                particles[i].opacity -= 0.016 * 2
                particles[i].scale *= 0.98
                particles[i].rotation += Double.random(in: -10...10)
            }
            
            particles.removeAll { $0.opacity <= 0 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            timer.invalidate()
            particles.removeAll()
        }
    }
}

// MARK: - Confetti Effect (for saved cards)
struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var rotation: Double
    var angularVelocity: Double
}

struct ConfettiEffect: View {
    @State private var confetti: [ConfettiPiece] = []
    let isActive: Bool
    
    let colors: [Color] = [.green, .blue, .yellow, .orange, .pink, .purple]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confetti) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 8, height: 4)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(piece.position)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    generateConfetti(in: geometry.size)
                    animateConfetti()
                }
            }
        }
    }
    
    private func generateConfetti(in size: CGSize) {
        confetti = (0..<50).map { _ in
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 200...400)
            
            return ConfettiPiece(
                position: CGPoint(x: size.width / 2, y: size.height / 2),
                velocity: CGVector(
                    dx: cos(angle) * speed,
                    dy: sin(angle) * speed - 200 // Bias upward
                ),
                color: colors.randomElement()!,
                rotation: Double.random(in: 0...360),
                angularVelocity: Double.random(in: -500...500)
            )
        }
    }
    
    private func animateConfetti() {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard !confetti.isEmpty else {
                timer.invalidate()
                return
            }
            
            for i in confetti.indices {
                confetti[i].position.x += confetti[i].velocity.dx * 0.016
                confetti[i].position.y += confetti[i].velocity.dy * 0.016
                confetti[i].velocity.dy += 800 * 0.016 // Gravity
                confetti[i].rotation += confetti[i].angularVelocity * 0.016
            }
            
            // Remove off-screen confetti
            confetti.removeAll { $0.position.y > UIScreen.main.bounds.height + 100 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            timer.invalidate()
            confetti.removeAll()
        }
    }
}

