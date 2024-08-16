//
//  ContentView.swift
//  MacOSVisualization
//
//  Created by Peterson Bem on 29/03/24.
//

import Foundation
import SwiftUI
import Charts

struct SimulationData: Identifiable {
    var theta: Int
    var point: [Vector]
    var id = UUID()
}

struct Vector: Identifiable {
    var x: Double
    var y: Double
    var p: Double
    var id = UUID()
}

enum Status {
    case LOADING, READY
    case FAILURE(String)
}

//struct ChartContentForProjectile: View {
//    let data: [SimulationData]
//    
//    var body: some View {
//        LineMark(x: .value("x", 10), y: .value("y", 20))
//        LineMark(x: .value("x", 30), y: .value("y", 40))
//        LineMark(x: .value("x", 50), y: .value("y", 60))
//        LineMark(x: .value("x", 70), y: .value("y", 80))
//    }
//}

struct ContentView: View {
    @State private var status: Status = .LOADING
    @State private var densityCorrectedData: [SimulationData] = []
    @State private var densityNotCorrectedData: [SimulationData] = []

    var body: some View {
        switch status {
        case .LOADING:
            VStack {
                Spacer()
                
                Image(systemName: "arrow.circlepath")
                    .padding(.bottom)
                Text("Loading")
            }
            .padding()
            .task { await fetchData() }
        case .READY:
            VStack {
                Text("Projectille Trajectory")
                    .font(.title)
                
                Chart {
//                    ChartContentForProjectile(data: densityCorrectedData)
                    
                    ForEach(densityCorrectedData) { d in
                        let annotationInterval = d.point.count / 3
                        let topMeasure = d.point.count / 2
//                        let lastMeasure = d.point.count - 1

                        ForEach(Array(zip(d.point.indices, d.point)), id: \.0) { i, p in
                            LineMark(
                                x: .value("x", p.x), y: .value("y", p.y),
                                series: .value("Angle", "D\(d.theta)º")
                            )
                            .foregroundStyle(by: .value("Fluid density", "Corrected Density"))

                            if i % annotationInterval == 0 {
                                PointMark(x: .value("x", p.x), y: .value("y", p.y))
                                    .opacity(0)
                                    .annotation(position: .topTrailing) {
                                        Text("p=\(p.p)")
                                            .font(.footnote)
                                    }
                            }

                            if i == topMeasure {
                                PointMark(x: .value("x", p.x), y: .value("y", p.y))
                                    .opacity(0)
                                    .annotation {
                                        Text("\(d.theta)º")
                                            .fontWeight(.bold)
                                    }
                            }
                        }
                    }

                    ForEach(densityNotCorrectedData) { d in
                        ForEach(d.point) { p in
                            LineMark(
                                x: .value("x", p.x), y: .value("y", p.y),
                                series: .value("Angle", "ND\(d.theta)º")
                            )
                            .foregroundStyle(by: .value("Fluid density", "NOT Corrected Density"))
                            .lineStyle(.init(dash: [5, 5]))

                            if p.x == d.point[d.point.count / 2 - 1].x {
                                PointMark(x: .value("x", p.x), y: .value("y", p.y))
                                    .opacity(0)
                                    .annotation {
                                        Text("\(d.theta)º")
                                            .fontWeight(.bold)
                                    }
                            }
                        }
                    }
                }
                .chartXAxisLabel("x (km)")
                .chartYAxisLabel("y (km)")
            }
            .padding()
        case let .FAILURE(msg):
            Text("There were errors: \(msg)")
                .padding()
                .foregroundStyle(.red)
                .font(.title)
        }
    }
    
    private func fetchData() async {
        densityCorrectedData.removeAll()
        async let correctedData = doFetch(angles: [36, 46, 55], namespace: "density_corrected")
        
        densityNotCorrectedData.removeAll()
        async let notCorrectedData = doFetch(angles: [38, 45, 55], namespace: "no_density_correction")
        
        var fetchErrors: [String] = []
        var tmpFetchErrors: [String]
        (densityCorrectedData, tmpFetchErrors) = await correctedData
        fetchErrors.insert(contentsOf: tmpFetchErrors, at: 0)
        (densityNotCorrectedData, tmpFetchErrors) = await notCorrectedData
        fetchErrors.insert(contentsOf: tmpFetchErrors, at: 0)

        status = if !fetchErrors.isEmpty {
            .FAILURE(fetchErrors.joined(separator: "; "))
        } else {
            .READY
        }
    }
    
    private func doFetch(angles: [Int], namespace: String) async -> ([SimulationData], [String]) {
        var data: [SimulationData] = []
        var errors: [String] = []
        
        angles.forEach { angle in
            let dataName = "\(namespace)/\(angle)projectille"
            
            if let rawData = NSDataAsset(name: dataName) {
                let text = String(bytes: rawData.data, encoding: .utf8)

                var point: [Vector] = []
                for line in text?.split(whereSeparator: { $0.isNewline }) ?? [] {
                    let values = line.split(whereSeparator: { $0.isWhitespace })

                    point.append(Vector(
                        x: (Double(values[1]) ?? 0)/1000,
                        y: (Double(values[2]) ?? 0)/1000,
                        p: (Double(values[3]) ?? 0)
                    ))
                }

                data.append(SimulationData(theta: angle, point: point))
            } else {
                errors.append("could not fetch data for \(namespace) at \(angle)!")
            }
        }
        
        return (data, errors)
    }
}

#Preview {
    ContentView()
}
