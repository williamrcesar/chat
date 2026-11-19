import test from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"

const source = (await readFile(new URL("../../app/javascript/controllers/voice_recorder_controller.js", import.meta.url), "utf8"))
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
const { default: VoiceRecorder } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)

function recorder() {
  const controller = new VoiceRecorder()
  controller._savedBlob = new Blob(["recording"], { type: "audio/webm" })
  controller._savedExt = "webm"
  controller._state = "review"
  controller._stopPreview = () => {}
  controller._hideAll = () => {}
  controller._syncButtons = () => {}
  controller._enterReview = () => {}
  return controller
}

test("keeps the recording available when upload fails", async t => {
  t.mock.method(console, "error", () => {})
  const controller = recorder()
  const blob = controller._savedBlob
  let notified = false
  globalThis.window = { alert: () => { notified = true } }
  controller._sendAudioBlob = async () => { throw new Error("offline") }
  await controller.sendLocked()
  assert.equal(controller._savedBlob, blob)
  assert.equal(controller._state, "review")
  assert.equal(controller._sending, false)
  assert.equal(notified, true)
})

test("clears the recording only after successful upload", async () => {
  const controller = recorder()
  controller._sendAudioBlob = async () => {}
  await controller.sendLocked()
  assert.equal(controller._savedBlob, null)
  assert.equal(controller._state, "idle")
})

test("ignores duplicate send clicks while upload is pending", async () => {
  const controller = recorder()
  let finish
  let sends = 0
  controller._sendAudioBlob = () => { sends++; return new Promise(resolve => { finish = resolve }) }
  const pending = controller.sendLocked()
  await controller.sendLocked()
  assert.equal(sends, 1)
  finish()
  await pending
})

test("stops a microphone stream that arrives after the controller disconnects", async () => {
  const controller = recorder()
  let grant, stopped = false
  Object.defineProperty(globalThis, "navigator", { configurable: true, value: {
    mediaDevices: { getUserMedia: () => new Promise(resolve => { grant = resolve }) }
  } })
  globalThis.document = { removeEventListener() {} }
  controller._stopTimers = () => {}
  controller._stopStream = () => {}
  const pending = controller._beginRecording()
  controller._abort()
  grant({ getTracks: () => [{ stop: () => { stopped = true } }] })
  await pending
  assert.equal(stopped, true)
  assert.equal(controller._state, "idle")
})
