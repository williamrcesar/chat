import test from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"

const source = (await readFile(new URL("../../app/javascript/controllers/composer_emoji_controller.js", import.meta.url), "utf8"))
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
const { default: ComposerEmoji } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)

test("inserts a multi-codepoint emoji at the cursor and emits an input event", () => {
  const controller = new ComposerEmoji()
  let caret, event, favorite
  controller.inputTarget = {
    value: "Olá mundo", selectionStart: 4, selectionEnd: 9,
    setSelectionRange: (start, end) => { caret = [start, end] },
    dispatchEvent: e => { event = e }, focus: () => {}
  }
  controller.addFavorite = emoji => { favorite = emoji }
  controller.close = () => {}
  controller.pick({ preventDefault() {}, stopPropagation() {}, currentTarget: { dataset: { emoji: "👋🏽" } } })
  assert.equal(controller.inputTarget.value, "Olá 👋🏽")
  assert.deepEqual(caret, [8, 8])
  assert.equal(event.type, "input")
  assert.equal(event.bubbles, true)
  assert.equal(favorite, "👋🏽")
})
