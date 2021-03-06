//
//  ViewController.swift
//  AR Basketball
//
//  Created by Илья Карась on 29/05/2019.
//  Copyright © 2019 Ilia Karas. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var pointsLabel: UILabel!
    
    var planeCounter = 0
    
    var isHoopPlaced = false
    
    var nodesContactedWithTopChecker = [SCNNode]()
    
    var pointsCount = 0
    var ballsThrown = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Set the contact's delegate
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Allow vertical plane detection
        configuration.planeDetection = [.vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}

// MARK: - Custom Methods
extension ViewController {
    /// Places hoop at hit test point
    ///
    /// - Parameter result: ARHitTestResult
    func addHoop(at result: ARHitTestResult) {
        let hoopScene = SCNScene(named: "art.scnassets/Hoop.scn")
        
        guard let hoopNode = hoopScene?.rootNode.childNode(withName: "Hoop", recursively: false) else { return }
        
        backboardTexture: if let backboardImage = UIImage(named: "art.scnassets/backboard.jpg") {
            guard let backboardNode = hoopNode.childNode(withName: "board", recursively: false) else {
                break backboardTexture
            }
            guard let backboard = backboardNode.geometry as? SCNBox else { break backboardTexture }
            
            backboard.firstMaterial?.diffuse.contents = backboardImage
        }
        
        // Place the hoop in correct position
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hoopNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        // Remove the wall
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Wall" {
                node.removeFromParentNode()
            }
        }
        
        // Add top contact checker
        guard let topNode = hoopScene?.rootNode.childNode(withName: "topContactChecker", recursively: false) else { return }
        topNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: topNode))
        topNode.name = "topContactChecker"
        topNode.physicsBody?.categoryBitMask = 0b0010
        topNode.physicsBody?.collisionBitMask = 0b0000
        hoopNode.addChildNode(topNode)
        
        // Add bottom contact checker
        guard let bottomNode = hoopScene?.rootNode.childNode(withName: "bottomContactChecker", recursively: false) else { return }
        bottomNode.name = "bottomContactChecker"
        bottomNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: bottomNode))
        bottomNode.physicsBody?.categoryBitMask = 0b0010
        bottomNode.physicsBody?.collisionBitMask = 0b0000
        hoopNode.addChildNode(bottomNode)
        
        // Add the hoop to the scene
        sceneView.scene.rootNode.addChildNode(hoopNode)
        isHoopPlaced = true
    }
    
    func createBasketball() {
        guard let frame = sceneView.session.currentFrame else { return }
        
        let ball = SCNNode(geometry: SCNSphere(radius: 0.1213))
        ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "basketball")
        
        let cameraTransform = frame.camera.transform
        ball.simdTransform = cameraTransform
        
        ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody?.categoryBitMask = 0b0001
        ball.physicsBody?.contactTestBitMask = 0b0010
        ball.name = "Ball"
        
        let power = Float(7)
        let vector = cameraTransform.columns.2
        let x = -vector.x * power
        let y = -vector.y * power
        let z = -vector.z * power
        let force = SCNVector3(x, y, z)
        ball.physicsBody?.applyForce(force, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ball)
        
        ballsThrown += 1
        updInfo()
    }

    func updInfo() {
        DispatchQueue.main.async {
            self.pointsLabel.text = String(self.pointsCount) + " / " + String(self.ballsThrown)
        }
    }
}

// MARK: - IB Actions
extension ViewController {
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        if isHoopPlaced {
            createBasketball()
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            addHoop(at: result)
        }
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        guard !isHoopPlaced else { return }
        
        let extent = anchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.name = "Wall"
        planeNode.opacity = 0.1
        
        node.addChildNode(planeNode)
        planeCounter += 1
    }
    
    // TODO: implement function for deleting basketballs
//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        <#code#>
//    }
}

// MARK: - SCNPhysicsContactDelegate
extension ViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB

        if nodeA.name == "topContactChecker" {
            nodesContactedWithTopChecker.append(nodeB)
        } else if nodeA.name == "bottomContactChecker" && nodeB.name == "Ball" {
            nodeB.name = "ballAfterContact"
            
            if nodesContactedWithTopChecker.contains(nodeB) {
                pointsCount += 1
                updInfo()
            }
        }
    }
}
