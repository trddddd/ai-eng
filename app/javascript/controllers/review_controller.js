import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "answerText", "elapsed", "attempts", "backspaces", "ghost"]
  static values = {
    answer: String,
    audioUrl: { type: String, default: "" }
  }

  connect() {
    this.startedAt = Date.now()
    this.attemptCount = 0
    this.backspaceCount = 0
    this.firstAnswerRecorded = false
    this.audioBuffer = null
    this.audioContext = null

    this.inputTarget.focus()
    this.resizeInput()
    this.preloadAudio()
  }

  onInput() {
    const typed = this.inputTarget.value.toLowerCase()
    const expected = this.answerValue

    if (typed.length > 0) {
      this.ghostTarget.classList.add("hidden")
    }

    if (typed.length === 0) {
      this.inputTarget.classList.remove("border-green-500", "border-red-500", "ring-green-500", "ring-red-500")
    } else if (expected.startsWith(typed)) {
      this.inputTarget.classList.remove("border-red-500", "ring-red-500")
      this.inputTarget.classList.add("border-green-500", "ring-green-500")
    } else {
      this.inputTarget.classList.remove("border-green-500", "ring-green-500")
      this.inputTarget.classList.add("border-red-500", "ring-red-500")
    }
  }

  trackKey(event) {
    if (event.key === "Backspace") {
      this.backspaceCount++
    }
  }

  submit(event) {
    event.preventDefault()
    const userAnswer = this.inputTarget.value.trim()
    const isCorrect = userAnswer.toLowerCase() === this.answerValue

    if (!this.firstAnswerRecorded) {
      this.answerTextTarget.value = userAnswer
      this.firstAnswerRecorded = true
    }

    this.attemptCount++

    if (isCorrect) {
      this.playAudio()
      this.finalSubmit()
    } else {
      this.resetUIForRetry()
    }
  }

  resetUIForRetry() {
    this.inputTarget.value = ""
    this.ghostTarget.classList.remove("hidden")
    this.inputTarget.classList.remove("border-green-500", "ring-green-500", "border-red-500", "ring-red-500")
    this.inputTarget.classList.add("border-amber-500", "ring-amber-500")
    this.inputTarget.focus()
  }

  finalSubmit() {
    this.elapsedTarget.value = Date.now() - this.startedAt
    this.attemptsTarget.value = this.attemptCount
    this.backspacesTarget.value = this.backspaceCount
    this.element.querySelector("form").requestSubmit()
  }

  async preloadAudio() {
    if (!this.audioUrlValue) return

    try {
      this.audioContext = this.audioContext || new AudioContext()
      const response = await fetch(this.audioUrlValue)
      const arrayBuffer = await response.arrayBuffer()
      this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
    } catch {
      // Audio unavailable — silent fallback
    }
  }

  playAudio() {
    if (!this.audioBuffer || !this.audioContext) return

    const source = this.audioContext.createBufferSource()
    source.buffer = this.audioBuffer
    source.connect(this.audioContext.destination)
    source.start(0)
  }

  resizeInput() {
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    const style = getComputedStyle(this.inputTarget)
    ctx.font = style.font
    const width = ctx.measureText(this.answerValue).width
    this.inputTarget.style.width = `${Math.max(width + 48, 120)}px`
  }
}
