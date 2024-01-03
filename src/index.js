// ThreeJS and Third-party deps
import * as THREE from "three"
import * as dat from 'dat.gui'
import Stats from "three/examples/jsm/libs/stats.module"
import { RoundedBoxGeometry } from "three/examples/jsm/geometries/RoundedBoxGeometry"
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls"

// Core boilerplate code deps
import { createCamera, createRenderer, runApp, updateLoadingProgressBar, getDefaultUniforms } from "./core-utils"

// Other deps
import vertexShader from "./shaders/vertex.glsl"
import fragmentShader from "./shaders/fragment.glsl"

global.THREE = THREE
// previously this feature is .legacyMode = false, see https://www.donmccurdy.com/2020/06/17/color-management-in-threejs/
// turning this on has the benefit of doing certain automatic conversions (for hexadecimal and CSS colors from sRGB to linear-sRGB)
THREE.ColorManagement.enabled = true

/**************************************************
 * 0. Tweakable parameters for the scene
 *************************************************/
const params = {
  // general scene params
}
const uniforms = {
  ...getDefaultUniforms(),
  uTexture: {
    value: null,
  },
  uIorR: {
    value: 1.15,
  },
  uIorG: {
    value: 1.18,
  },
  uIorB: {
    value: 1.22,
  },
  uRefractPower: {
    value: 0.2,
  },
  uShininess: { value: 40.0 },
  uDiffuseness: { value: 0.05 },
  uDirLight: { // reference point of the sun relative to origin in world space
    value: new THREE.Vector3(-1.0, 1.0, 1.0),
  },
}


/**************************************************
 * 1. Initialize core threejs components
 *************************************************/
// Create the scene
let scene = new THREE.Scene()

// Create the renderer via 'createRenderer',
// 1st param receives additional WebGLRenderer properties
// 2nd param receives a custom callback to further configure the renderer
let renderer = createRenderer({ antialias: true }, (_renderer) => {
  // best practice: ensure output colorspace is in sRGB, see Color Management documentation:
  // https://threejs.org/docs/#manual/en/introduction/Color-management
  _renderer.outputColorSpace = THREE.SRGBColorSpace
  // set to false because we want to have multiple renders stacked for each frame
  // if it's true, each render would wipe the previous render in the same frame
  _renderer.autoClear = false
})

// Create the camera
// Pass in fov, near, far and camera position respectively
let camera = createCamera(45, 1, 100, { x: 0, y: 0, z: 5 })

/**************************************************
 * 2. Build your scene in this threejs app
 * This app object needs to consist of at least the async initScene() function (it is async so the animate function can wait for initScene() to finish before being called)
 * initScene() is called after a basic threejs environment has been set up, you can add objects/lighting to you scene in initScene()
 * if your app needs to animate things(i.e. not static), include a updateScene(interval, elapsed) function in the app as well
 *************************************************/
let app = {
  async initScene() {
    // OrbitControls
    this.controls = new OrbitControls(camera, renderer.domElement)
    this.controls.enableDamping = true

    await updateLoadingProgressBar(0.1)

    // for rendering just the background texture
    this.envFbo = new THREE.WebGLRenderTarget(
      window.innerWidth * window.devicePixelRatio,
      window.innerHeight * window.devicePixelRatio
    )
    uniforms.uTexture.value = this.envFbo.texture

    // add ambient light
    let light = new THREE.AmbientLight(0xffffff, 50)
    scene.add(light)

    const ctx = document.createElement('canvas').getContext('2d')
    ctx.canvas.width = 2048
    ctx.canvas.height = 2048
    ctx.fillStyle = '#000'
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height)
    ctx.fillStyle = '#FFF'
    ctx.font = "bold 512px Helvetica"
    ctx.textAlign = "center"
    ctx.fillText("Release", 1024, 768, 2048)
    ctx.fillText("Your", 1024, 1248, 2048)
    ctx.fillText("Power", 1024, 1728, 2048)
    const texture = new THREE.CanvasTexture(ctx.canvas)

    const plane = new THREE.PlaneGeometry(4,4,1,1)
    const mat = new THREE.MeshBasicMaterial({
      map: texture
    })
    const bg = new THREE.Mesh(plane, mat)
    scene.add(bg)

    const geometry = new RoundedBoxGeometry( 1.5, 1.5, 1.5, 8, 0.2 )
    const material = new THREE.ShaderMaterial({
      uniforms: uniforms,
      vertexShader: vertexShader,
      fragmentShader: fragmentShader,
      vertexColors: true
    })
    this.mesh = new THREE.Mesh( geometry, material )
    this.mesh.position.set(0, 0, 1)
    scene.add( this.mesh )

    // GUI controls
    const gui = new dat.GUI()

    // Stats - show fps
    this.stats1 = new Stats()
    this.stats1.showPanel(0) // Panel 0 = fps
    this.stats1.domElement.style.cssText = "position:absolute;top:0px;left:0px;"
    // this.container is the parent DOM element of the threejs canvas element
    this.container.appendChild(this.stats1.domElement)

    await updateLoadingProgressBar(1.0, 100)
  },
  // @param {number} interval - time elapsed between 2 frames
  // @param {number} elapsed - total time elapsed since app start
  updateScene(interval, elapsed) {
    this.controls.update()
    this.stats1.update()

    renderer.clear()

    // render env to fbo
    this.mesh.visible = false
    renderer.setRenderTarget(this.envFbo)
    // clear the fbo before rendering a new frame
    renderer.clear()
    renderer.render(scene, camera)

    // render env to screen
    renderer.setRenderTarget(null)
    this.mesh.visible = true
    // rotate the mesh in different directions with a non-periodic function, reference: https://stackoverflow.com/a/60772438/17007893
    this.mesh.rotation.y = (Math.sin(2 * elapsed * 0.5) + Math.sin(Math.PI * elapsed * 0.5)) * 0.4
    this.mesh.rotation.x = (Math.sin(1.5 * elapsed * 0.5) + Math.sin(Math.PI/2 * elapsed * 0.5)) * 0.4
    this.mesh.rotation.z = (Math.sin(2 * elapsed * 0.4) + Math.sin(Math.PI/2 * elapsed * 0.4)) * 0.2
    
    renderer.render(scene, camera)
  },
  resize() {
    this.envFbo.setSize(
      window.innerWidth * window.devicePixelRatio,
      window.innerHeight * window.devicePixelRatio
    )
  }
}

/**************************************************
 * 3. Run the app
 * 'runApp' will do most of the boilerplate setup code for you:
 * e.g. HTML container, window resize listener, mouse move/touch listener for shader uniforms, THREE.Clock() for animation
 * Executing this line puts everything together and runs the app
 * ps. if you don't use custom shaders, pass undefined to the 'uniforms'(2nd-last) param
 * ps. if you don't use post-processing, pass undefined to the 'composer'(last) param
 *************************************************/
runApp(app, scene, renderer, camera, true, uniforms, undefined)
