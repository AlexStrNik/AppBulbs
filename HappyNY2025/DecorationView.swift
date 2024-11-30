//
//  DecorationView.swift
//  HappyNY2025
//
//  Created by Aleksandr Strizhnev on 30.11.2024.
//

import SwiftUI

struct Lamp: View {
    var enabled: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if enabled {
                Ellipse()
                    .fill(
                        EllipticalGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color(red: 1.0, green: 0.9, blue: 0.5),
                                Color(red: 1.0, green: 0.7, blue: 0.2),
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 8, height: 12)
                    .background {
                        Circle()
                            .fill(
                                EllipticalGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.7, blue: 0.2),
                                        Color(red: 1.0, green: 0.9, blue: 0.5)
                                    ]),
                                    center: .center
                                )
                            )
                            .frame(width: 12, height: 12)
                            .scaleEffect(3)
                            .blur(radius: 15)
                    }
                    .padding(.top, 5)
                
            } else {
                Ellipse()
                    .fill(Color(red: 0.5, green: 0.4, blue: 0.2))
                    .frame(width: 8, height: 12)
                    .padding(.top, 5)
            }
           
            RoundedRectangle(cornerSize: CGSize(width: 2, height: 2))
                .fill(.black)
                .frame(width: 6, height: 6)
        }
    }
}

struct DecorationView: View {
    @State var lampCount: Int = 0
    
    private let lampSpacing: CGFloat = 30
    
    func rotationAngle(index: Int, time: Double) -> Double {
        let minAngle = -5.0
        let maxAngle = 5.0
        let oscillations = 3.0
        let speed = 2.0
        
        let angleRange = maxAngle - minAngle
        
        return minAngle + angleRange * 0.5 * (1 + sin(Double(index) / Double(lampCount) * oscillations * .pi + time * speed))
    }
    
    func isLampEnabled(index: Int, time: Double) -> Bool {
        let interval = 1.5
        let alternatingState = Int(time / interval) % 2 == 0
        return (index % 2 == 0) == alternatingState
    }
    
    var body: some View {
        TimelineView(.animation) { time in
            HStack {
                ForEach(0...lampCount, id: \.self) { index in
                    Lamp(enabled: isLampEnabled(index: index, time: time.date.timeIntervalSince1970))
                        .rotationEffect(
                            .degrees(
                                rotationAngle(index: index, time: time.date.timeIntervalSince1970)
                            ),
                            anchor: .top
                        )
                    
                    if index < lampCount {
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onGeometryChange(for: Int.self) { proxy in
            Int(proxy.size.width / lampSpacing)
        } action: { newValue in
            lampCount = newValue
        }
    }
}

#Preview {
    DecorationView()
        .frame(width: 500, height: 500)
        .padding()
}
