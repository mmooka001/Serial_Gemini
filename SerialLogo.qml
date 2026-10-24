import QtQuick
import QtQuick.Shapes

// 保留软件图标的双节点连接与星芒，用矢量线条适配明暗主题及高分屏。
Item {
    id: root
    property color strokeColor: "#ffffff"
    implicitWidth: 32
    implicitHeight: 32

    Shape {
        x: -0.5
        y: 3
        width: 32
        height: 32
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 11; startY: 20
            PathLine { x: 18; y: 20 }
        }
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 1.7
            fillColor: "transparent"
            PathAngleArc { centerX: 7; centerY: 20; radiusX: 4; radiusY: 4; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 1.7
            fillColor: "transparent"
            PathAngleArc { centerX: 22; centerY: 20; radiusX: 4; radiusY: 4; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: 25; startY: 2
            PathLine { x: 26.8; y: 5.2 }
            PathLine { x: 30; y: 7 }
            PathLine { x: 26.8; y: 8.8 }
            PathLine { x: 25; y: 12 }
            PathLine { x: 23.2; y: 8.8 }
            PathLine { x: 20; y: 7 }
            PathLine { x: 23.2; y: 5.2 }
            PathLine { x: 25; y: 2 }
        }
    }
}
