//
//  Gauge.swift
//  SWGauge
//
//  Created by Petr Korolev on 02/06/15.
//  Copyright (c) 2015 Petr Korolev. All rights reserved.
//

import QuartzCore
import UIKit

let pi_2 = Double.pi / 2

public enum GaugeType: Int {
    case circle = 0
    case left
    case right
    case up
    case down
    case line
    case custom
}

@IBDesignable
open class Gauge: UIView {
    @IBInspectable open var startColor: UIColor = UIColor.green {
        didSet {
            resetLayers()
            updateLayerProperties()
        }
    }

    /// default is nil: endColor is same as startColor
    @IBInspectable open var endColor: UIColor {
        get {
            if let _endColor = _endColor {
                return _endColor
            } else {
                return UIColor.red
            }
        }
        set {
            _endColor = newValue
        }
    }
    fileprivate var _endColor: UIColor? {
        didSet {
            resetLayers()
            updateLayerProperties()
        }
    }
    @IBInspectable open var bgColor: UIColor? {
        didSet {
            updateLayerProperties()
            setNeedsLayout()
        }
    }

    internal var _bgStartColor: UIColor {
        get {
            if let bgColor = bgColor {
                return bgColor.withAlphaComponent(bgAlpha)
            } else {
                return startColor.withAlphaComponent(bgAlpha)
            }
        }
    }

    internal var _bgEndColor: UIColor {
        get {
            if let bgColor = bgColor {
                return bgColor.withAlphaComponent(bgAlpha)
            } else {
                return endColor.withAlphaComponent(bgAlpha)
            }
        }
    }
    @IBInspectable open var bgAlpha: CGFloat = 0.2 {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable open var rotate: Double = 0 {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable open var colorsArray: [UIColor] = [] {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable open var shadowRadius: CGFloat = 0 {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable open var shadowOpacity: Float = 0.5 {
        didSet {
            updateLayerProperties()
        }
    }

    @IBInspectable open var reverse: Bool = false {
        didSet {
            resetLayers()
            updateLayerProperties()
        }
    }

    /// Default is equal to #lineWidth. Set it to 0 to remove round edges
    @IBInspectable open var roundCap: Bool = true {
        didSet {
            updateLayerProperties()
        }
    }

    open var type: GaugeType = .circle {
        didSet {
            resetLayers()
            updateLayerProperties()
        }
    }

    /// Convenience property to setup type variable from IB
    @IBInspectable var gaugeTypeInt: Int {

        get {
            return type.rawValue
        }
        set(newValue) {
            if let newType = GaugeType(rawValue: newValue) {
                type = newType
            } else {
                type = .circle
            }
        }
    }

    /// This value specify rate value for 100% filled gauge. Default is 10.
    ///i.e. with rate = 10 gauge is 100% filled.
    @IBInspectable open var maxValue: CGFloat = 10 {
        didSet {
            updateLayerProperties()
        }
    }
    /// percantage of filled Gauge. 0..maxValue.
    @IBInspectable open var rate: CGFloat = 8 {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable var isCircle: Bool = false {
        didSet {
            updateLayerProperties()
        }
    }
    @IBInspectable open var lineWidth: CGFloat = 15.0 {
        didSet {
            updateLayerProperties()
        }
    }

/// Main gauge layer
    var gaugeLayer: CALayer!
/// Colored layer, depends from scale
    var ringLayer: CAShapeLayer!
/// background for ring layer
    var bgLayer: CAShapeLayer!
/// ring gradient layer
    var ringGradientLayer: CAGradientLayer!
/// background gradient
    var bgGradientLayer: CAGradientLayer!

    // Animation variables
    internal var animationTimer: Timer = Timer()
    internal var animationCompletionBlock: (Bool) -> () = {_ in }
    
    func getGauge(_ rotateAngle: Double = 0) -> CAShapeLayer {
        switch type {
        case .left, .right:
            return getVerticalHalfGauge(rotateAngle)

        case .up, .down:
            return getHorizontalHalfGauge(rotateAngle)

        case .circle:
            return getCircleGauge(rotateAngle)
            
        case .line:
            return getLineGauge(rotateAngle)
            
        default:
            return getCircleGauge(rotateAngle)
        }
    }

    func updateLayerProperties() {
        backgroundColor = UIColor.clear
        
        if (ringLayer != nil) {
            switch type {
            case .left, .right, .down, .up:
                // For Half Gauge, you have to fill 50% of circle and round it wisely
                let percentage = (rate / 2 / maxValue).truncatingRemainder(dividingBy: 0.5)
                ringLayer.strokeEnd = (rate >= maxValue ? 0.5 : percentage + ((rate != 0 && percentage == 0) ? 0.5 : 0))
            default:
                ringLayer.strokeEnd = rate / maxValue
            }

            var strokeColor = UIColor.lightGray

            if !colorsArray.isEmpty {

                let percentageInSector: CGFloat = ((rate / maxValue * CGFloat(colorsArray.count - 1) * 100.0).truncatingRemainder(dividingBy: 100.0)) / 100.0
                let currentSector: Int = Int(rate / maxValue * CGFloat(colorsArray.count - 1)) + 1

                let firstColor = colorsArray[max(0, currentSector - 1)]
                let secondColor = colorsArray[min(currentSector, colorsArray.count - 1)]

                strokeColor = blend(colors: (firstColor, secondColor), distance: percentageInSector )

                if type == .line {
                    ringLayer.strokeColor = strokeColor.cgColor
                }

                if ringGradientLayer != nil {
                    ringGradientLayer.colors = [strokeColor.cgColor, strokeColor.cgColor]
                } else {
                    ringLayer.strokeColor = strokeColor.cgColor
                }
            } else {
                ringLayer.strokeColor = startColor.cgColor
            }
        }
    }

    private func blend(colors: (UIColor, UIColor), distance: CGFloat) -> UIColor {

        let (color1, color2) = colors
        let (weight1, weight2) = (1.0 - distance, distance)

        var (red1, green1, blue1) : (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        var (red2, green2, blue2) : (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        color1.getRed(&red1, green: &green1, blue: &blue1, alpha: nil)
        color2.getRed(&red2, green: &green2, blue: &blue2, alpha: nil)

        let blendedColorComponents = zip( [red1, green1, blue1], [red2, green2, blue2] )
            .map { weight1 * $0.0 + weight2 * $0.1 }

        let (red, green, blue) = (blendedColorComponents[0], blendedColorComponents[1], blendedColorComponents[2])
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        updateLayerProperties()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        updateLayerProperties()
    }

    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        updateLayerProperties()
    }

    func reverseX(_ layer: CALayer) {
//        layer.transform = CATransform3DScale(CATransform3DMakeRotation(CGFloat(M_PI_2), 0, 0, 1), -1, 1, 1)
        layer.transform = CATransform3DScale(layer.transform, -1, 1, 1)

    }

    func reverseY(_ layer: CALayer) {
//        layer.transform = CATransform3DScale(CATransform3DMakeRotation(CGFloat(M_PI_2), 0, 0, 1), 1, -1, 1)
        layer.transform = CATransform3DScale(layer.transform, 1, -1, 1)

    }

    func resetLayers() {
        layer.sublayers = nil
        bgLayer = nil
        ringLayer = nil
        ringGradientLayer = nil
        bgGradientLayer = nil
    }

    open override func layoutSubviews() {
        resetLayers()
        gaugeLayer = getGauge(rotate / 10 * Double.pi)
        layer.addSublayer(gaugeLayer)
        updateLayerProperties()
    }
}
