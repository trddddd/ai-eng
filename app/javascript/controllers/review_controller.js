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
    this.readyToSubmit = false
    this.submitting = false
    this.audioBuffer = null
    this.audioContext = null
    this.audioSource = null
    this._originalPlaceholder = this.inputTarget.placeholder

    this.inputTarget.focus()
    this.resizeInput()
    this.preloadAudio()
  }

  disconnect() {
    if (!this.audioSource) return

    this.audioSource.onended = null
    this.audioSource.stop()
    this.audioSource = null
  }

  onInput() {
    const typed = this.inputTarget.value.toLowerCase()
    const expected = this.answerValue
    this.resizeInput()

    if (typed.length > 0) {
      this.inputTarget.placeholder = ""
    }

    if (typed.length === 0) {
      this.inputTarget.style.borderBottomColor = ""
    } else if (expected.startsWith(typed)) {
      this.inputTarget.style.borderBottomColor = getComputedStyle(document.documentElement).getPropertyValue('--color-tertiary').trim()
    } else {
      this.inputTarget.style.borderBottomColor = getComputedStyle(document.documentElement).getPropertyValue('--color-error').trim()
    }
  }

  trackKey(event) {
    if (event.key === "Backspace") {
      this.backspaceCount++
    }
  }

  async submit(event) {
    if (this.readyToSubmit) {
      this.readyToSubmit = false
      return
    }

    event.preventDefault()
    if (this.submitting) return

    const userAnswer = this.inputTarget.value.trim()
    const isCorrect = userAnswer.toLowerCase() === this.answerValue

    if (!this.firstAnswerRecorded) {
      this.answerTextTarget.value = userAnswer
      this.firstAnswerRecorded = true
    }

    this.attemptCount++

    if (isCorrect) {
      this.submitting = true
      this.inputTarget.disabled = true
      await this.playAudioThenSubmit()
    } else {
      this.resetUIForRetry()
    }
  }

  resetUIForRetry() {
    this.inputTarget.value = ""
    this.inputTarget.placeholder = this.answerValue
    this.inputTarget.style.borderBottomColor = getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim()
    this.inputTarget.focus()
  }

  finalSubmit() {
    this.elapsedTarget.value = Date.now() - this.startedAt
    this.attemptsTarget.value = this.attemptCount
    this.backspacesTarget.value = this.backspaceCount
    this.readyToSubmit = true
    this.element.querySelector("form").requestSubmit()
  }

  async preloadAudio() {
    if (!this.audioUrlValue) return

    try {
      this.audioContext = this.audioContext || new AudioContext()
      const response = await fetch(this.audioUrlValue)
      if (!response.ok) return

      const arrayBuffer = await response.arrayBuffer()
      this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
    } catch {
      // Audio unavailable — silent fallback
    }
  }

  async playAudioThenSubmit() {
    const playbackStarted = await this.playAudio()

    if (!playbackStarted) {
      this.finalSubmit()
    }
  }

  async playAudio() {
    if (!this.audioBuffer || !this.audioContext) return false

    try {
      if (this.audioContext.state === "suspended") {
        await this.audioContext.resume()
      }

      if (this.audioSource) {
        this.audioSource.onended = null
        this.audioSource.stop()
      }

      const source = this.audioContext.createBufferSource()
      this.audioSource = source
      source.buffer = this.audioBuffer
      source.connect(this.audioContext.destination)
      source.onended = () => {
        if (this.audioSource !== source) return

        this.audioSource = null
        this.finalSubmit()
      }
      source.start(0)

      return true
    } catch {
      this.audioSource = null
      return false
    }
  }

  async triggerAudio() {
    if (!this.audioBuffer || !this.audioContext) return

    try {
      if (this.audioContext.state === "suspended") {
        await this.audioContext.resume()
      }

      if (this.audioSource) {
        this.audioSource.onended = null
        this.audioSource.stop()
      }

      const source = this.audioContext.createBufferSource()
      this.audioSource = source
      source.buffer = this.audioBuffer
      source.connect(this.audioContext.destination)
      source.onended = () => {
        if (this.audioSource === source) this.audioSource = null
      }
      source.start(0)
    } catch {
      // Audio unavailable — silent fallback
    }
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
