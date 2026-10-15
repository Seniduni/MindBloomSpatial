import RealityKit
import UIKit

/// Builds the 3D wellness garden from plain values. Everything is generated
/// procedurally from RealityKit primitives (boxes and spheres), so the project
/// needs no external 3D assets.
///
/// Coordinate space: the volumetric window's origin is its centre; y is up.
/// The garden bed sits near the bottom of the volume.
@MainActor
enum GardenBuilder {
    struct PlantSpec {
        let name: String
        let color: UIColor
        let growth: Double      // 0…1
        let tendedToday: Bool
    }

    struct OrbSpec {
        let id: String          // used as the entity name, so taps can be mapped back to a check-in
        let color: UIColor
        let intensity: Int      // 1…5
    }

    static let bedY: Float = -0.22
    static let bedSize: Float = 0.62

    /// Removes the old garden and builds a new one under `root`.
    static func rebuild(_ root: Entity, plants: [PlantSpec], orbs: [OrbSpec], fireflies: Int, animate: Bool) {
        root.children.removeAll()
        root.addChild(makeBed())

        // Plants on a grid inside the bed.
        let columns = max(1, Int(Double(plants.count).squareRoot().rounded(.up)))
        let spacing = bedSize / Float(columns + 1)
        for (index, plant) in plants.enumerated() {
            let row = index / columns, column = index % columns
            let x = -bedSize / 2 + spacing * Float(column + 1)
            let z = -bedSize / 2 + spacing * Float(row + 1)
            let entity = makePlant(plant)
            entity.position = [x, bedY + 0.01, z]
            root.addChild(entity)
        }

        // Mood orbs float in a gentle arc above the garden.
        for (index, orb) in orbs.enumerated() {
            let angle = Float(index) / Float(max(orbs.count, 1)) * .pi * 2
            let entity = makeOrb(orb)
            entity.position = [cos(angle) * 0.3, 0.12 + Float(index % 3) * 0.05, sin(angle) * 0.3]
            root.addChild(entity)
            if animate { addBobbing(to: entity, phase: Double(index) * 0.4) }
        }

        // Each breathing session becomes a small glowing firefly.
        for index in 0..<min(fireflies, 24) {
            let firefly = ModelEntity(mesh: .generateSphere(radius: 0.006),
                                      materials: [UnlitMaterial(color: SpatialTheme.sun.withAlphaComponent(0.9))])
            let angle = Float(index) * 2.399   // golden-angle spiral spreads them evenly
            let radius = 0.08 + Float(index) * 0.009
            firefly.position = [cos(angle) * radius, bedY + 0.18 + Float(index % 5) * 0.03, sin(angle) * radius]
            firefly.name = "firefly"
            root.addChild(firefly)
            if animate { addBobbing(to: firefly, phase: Double(index) * 0.7, height: 0.015) }
        }
    }

    // MARK: Pieces

    private static func makeBed() -> Entity {
        let bed = ModelEntity(mesh: .generateBox(width: bedSize, height: 0.03, depth: bedSize, cornerRadius: 0.012),
                              materials: [SimpleMaterial(color: SpatialTheme.soil, roughness: 0.9, isMetallic: false)])
        bed.position = [0, bedY - 0.015, 0]
        bed.name = "bed"

        let moss = ModelEntity(mesh: .generateBox(width: bedSize - 0.04, height: 0.006, depth: bedSize - 0.04, cornerRadius: 0.01),
                               materials: [SimpleMaterial(color: SpatialTheme.stem.withAlphaComponent(0.85), roughness: 1.0, isMetallic: false)])
        moss.position = [0, 0.017, 0]
        bed.addChild(moss)
        return bed
    }

    private static func makePlant(_ spec: PlantSpec) -> Entity {
        let plant = Entity()
        plant.name = "plant:\(spec.name)"

        // Stem height grows with completions (min 4 cm, max 22 cm).
        let height = Float(0.04 + 0.18 * spec.growth)
        let stem = ModelEntity(mesh: .generateBox(width: 0.008, height: height, depth: 0.008, cornerRadius: 0.003),
                               materials: [SimpleMaterial(color: SpatialTheme.stem, roughness: 0.6, isMetallic: false)])
        stem.position = [0, height / 2, 0]
        plant.addChild(stem)

        // Two leaves.
        for side: Float in [-1, 1] {
            let leaf = ModelEntity(mesh: .generateBox(width: 0.035, height: 0.004, depth: 0.016, cornerRadius: 0.002),
                                   materials: [SimpleMaterial(color: SpatialTheme.stem, roughness: 0.6, isMetallic: false)])
            leaf.position = [side * 0.018, height * 0.4, 0]
            leaf.orientation = simd_quatf(angle: side * 0.4, axis: [0, 0, 1])
            plant.addChild(leaf)
        }

        // Flower head: petals open fully when tended today, stay as a bud otherwise.
        let head = Entity()
        head.position = [0, height, 0]
        let petalCount = 6
        let openness: Float = spec.tendedToday ? 1 : 0.35
        for index in 0..<petalCount {
            let angle = Float(index) / Float(petalCount) * .pi * 2
            let petal = ModelEntity(mesh: .generateSphere(radius: 0.012),
                                    materials: [SimpleMaterial(color: spec.color, roughness: 0.35, isMetallic: false)])
            petal.scale = [1, 0.45, 1.6]
            petal.position = [cos(angle) * 0.016 * openness, 0, sin(angle) * 0.016 * openness]
            petal.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            head.addChild(petal)
        }
        let core = ModelEntity(mesh: .generateSphere(radius: 0.009),
                               materials: [SimpleMaterial(color: SpatialTheme.sun, roughness: 0.4, isMetallic: false)])
        head.addChild(core)
        plant.addChild(head)

        // Make the whole plant tappable (to show its name) with a system hover highlight.
        let hitBox = ModelEntity(mesh: .generateBox(width: 0.06, height: height + 0.04, depth: 0.06),
                                 materials: [UnlitMaterial(color: .clear)])
        hitBox.position = [0, (height + 0.04) / 2, 0]
        hitBox.name = plant.name
        hitBox.components.set(OpacityComponent(opacity: 0))
        hitBox.components.set(InputTargetComponent())
        hitBox.components.set(CollisionComponent(shapes: [.generateBox(width: 0.06, height: height + 0.04, depth: 0.06)]))
        plant.addChild(hitBox)
        return plant
    }

    private static func makeOrb(_ spec: OrbSpec) -> Entity {
        let radius = Float(0.018 + 0.005 * Double(spec.intensity))
        let glass = SimpleMaterial(color: spec.color.withAlphaComponent(0.85), roughness: 0.15, isMetallic: false)
        let orb = ModelEntity(mesh: .generateSphere(radius: radius), materials: [glass])
        orb.name = spec.id
        // Interaction targets are at least ~6 cm across: comfortable for gaze + pinch.
        orb.components.set(InputTargetComponent())
        orb.components.set(CollisionComponent(shapes: [.generateSphere(radius: max(radius, 0.03))]))
        orb.components.set(HoverEffectComponent())
        return orb
    }

    /// Slow up-and-down float, skipped entirely when Reduce Motion is on.
    private static func addBobbing(to entity: Entity, phase: Double, height: Float = 0.012) {
        var lifted = entity.transform
        lifted.translation.y += height
        let animation = FromToByAnimation<Transform>(from: entity.transform, to: lifted,
                                                     duration: 2.6, timing: .easeInOut,
                                                     bindTarget: .transform, repeatMode: .autoReverse,
                                                     delay: phase)
        if let resource = try? AnimationResource.generate(with: animation) {
            entity.playAnimation(resource)
        }
    }
}
